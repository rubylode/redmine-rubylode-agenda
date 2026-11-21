# Rubylode Agenda: dated meeting agendas with progress change and closed tickets for Redmine
# Copyright (C) 2026  Nick Gorbikoff
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software

require_relative "../test_helper"

class RubylodeAgendaLinesTest < RubylodeAgendaIntegrationTest
  def setup
    super
    @meeting = start_meeting
    @topic = add_topic(@meeting, "Release")
  end

  test "creating a line answers the envelope with the rendered row" do
    post agenda_path("/topics/#{@topic["id"]}/lines"), params: { text: "Write the changelog" }
    assert_response :success
    body = json_response
    assert_equal 2, body["revision"]
    assert_equal [], body["topics"]
    record = body["lines"].first
    assert_equal @topic["id"], record["topic_id"]
    assert_equal 1, record["position"]
    assert_equal false, record["deleted"]
    assert_equal false, record["parked"]
    assert_includes record["html"], "Write the changelog"
    stored = RubylodeAgenda::Line.find(record["id"])
    assert_equal @meeting.id, stored.meeting_id
    assert_equal 2, stored.revision
    assert_not stored.done
    assert_equal 0, stored.carried_count
  end

  test "new lines go to the end" do
    first = add_line(@topic, "First")
    second = add_line(@topic, "Second")
    assert_equal [1, 2], [first["position"], second["position"]]
  end

  test "a blank line is refused" do
    post agenda_path("/topics/#{@topic["id"]}/lines"), params: { text: "" }
    assert_response :unprocessable_entity
    assert_equal 0, RubylodeAgenda::Line.count
  end

  test "updating the text sets the edited time" do
    line = add_line(@topic, "First")
    travel_to Time.zone.local(2026, 11, 22, 9, 15) do
      patch agenda_path("/lines/#{line["id"]}"), params: { text: "First, reworded", lock_version: line["lock_version"] }
    end
    assert_response :success
    stored = RubylodeAgenda::Line.find(line["id"])
    assert_equal "First, reworded", stored.text
    assert_equal Time.zone.local(2026, 11, 22, 9, 15), stored.edited_at
  end

  test "ticking done leaves the edited time empty" do
    line = add_line(@topic, "First")
    patch agenda_path("/lines/#{line["id"]}"), params: { done: "1", lock_version: line["lock_version"] }
    assert_response :success
    stored = RubylodeAgenda::Line.find(line["id"])
    assert stored.done
    assert_nil stored.edited_at
    assert_includes json_response["lines"].first["html"], "rubylode-agenda-line-done"
  end

  test "the revision rises by one per write and the changed lines carry it" do
    one = add_line(@topic, "One")
    two = add_line(@topic, "Two")
    patch agenda_path("/lines/#{one["id"]}"), params: { text: "One!", lock_version: one["lock_version"] }
    assert_equal 4, json_response["revision"]
    delete agenda_path("/lines/#{two["id"]}")
    assert_equal 5, json_response["revision"]
    assert_equal [4, 5], [one, two].map { |record| RubylodeAgenda::Line.find(record["id"]).revision }
    assert_equal 5, @meeting.reload.revision
  end

  test "a second save of the same line must carry the lock version the first save answered with" do
    line = add_line(@topic, "Original")
    assert_equal 0, line["lock_version"]
    patch agenda_path("/lines/#{line["id"]}"), params: { text: "Reworded", lock_version: 0 }
    assert_response :success
    assert_equal 1, json_response["lines"].first["lock_version"]
    patch agenda_path("/lines/#{line["id"]}"), params: { done: "1", lock_version: 0 }
    assert_response :conflict
    patch agenda_path("/lines/#{line["id"]}"), params: { done: "1", lock_version: 1 }
    assert_response :success
    assert_equal 2, json_response["lines"].first["lock_version"]
    assert RubylodeAgenda::Line.find(line["id"]).done
  end

  test "a stale line update answers 409 with the current line and keeps the text" do
    line = add_line(@topic, "Original")
    patch agenda_path("/lines/#{line["id"]}"), params: { text: "Mine", lock_version: line["lock_version"] }
    patch agenda_path("/lines/#{line["id"]}"), params: { text: "Late", lock_version: line["lock_version"] }
    assert_response :conflict
    body = json_response
    assert_equal 3, body["revision"]
    assert_equal [], body["topics"]
    assert_equal 1, body["lines"].first["lock_version"]
    assert_includes body["lines"].first["html"], "Mine"
    assert_equal "Mine", RubylodeAgenda::Line.find(line["id"]).text
    assert_equal 3, @meeting.reload.revision
  end

  test "deleting a line only marks it" do
    line = add_line(@topic, "Gone soon")
    delete agenda_path("/lines/#{line["id"]}")
    assert_response :success
    assert_equal true, json_response["lines"].first["deleted"]
    assert_not_nil RubylodeAgenda::Line.find(line["id"]).deleted_at
    get agenda_path
    assert_select "input[value='Gone soon']", count: 0
  end

  test "reordering lines within a topic" do
    one = add_line(@topic, "One")
    two = add_line(@topic, "Two")
    three = add_line(@topic, "Three")
    post agenda_path("/topics/#{@topic["id"]}/lines/reorder"), params: { ids: [two["id"], three["id"], one["id"]] }
    assert_response :success
    positions = json_response["lines"].to_h { |record| [record["id"], record["position"]] }
    assert_equal({ two["id"] => 1, three["id"] => 2, one["id"] => 3 }, positions)
    get agenda_path
    assert_equal %w[Two Three One], css_select("input[data-field=line-text]").map { |input| input["value"] }
  end

  test "a line dragged into another topic moves there" do
    other = add_topic(@meeting, "Budget")
    one = add_line(@topic, "One")
    two = add_line(@topic, "Two")
    existing = add_line(other, "Existing")
    post agenda_path("/topics/#{other["id"]}/lines/reorder"), params: { ids: [existing["id"], one["id"]] }
    assert_response :success
    body = json_response
    moved = body["lines"].find { |record| record["id"] == one["id"] }
    assert_equal other["id"], moved["topic_id"]
    assert_equal 2, moved["position"]
    assert_equal other["id"], RubylodeAgenda::Line.find(one["id"]).topic_id
    assert_equal @topic["id"], RubylodeAgenda::Line.find(two["id"]).topic_id
  end

  test "a line cannot be moved into a topic of another meeting" do
    line = add_line(@topic, "One")
    post agenda_path("/meetings")
    next_meeting = RubylodeAgenda::Meeting.order(:id).last
    other_topic = add_topic(next_meeting, "Elsewhere")
    post agenda_path("/topics/#{other_topic["id"]}/lines/reorder"), params: { ids: [line["id"]] }
    assert_equal @topic["id"], RubylodeAgenda::Line.find(line["id"]).topic_id
  end

  test "a reader cannot write lines" do
    line = add_line(@topic, "One")
    log_in_as_reader
    post agenda_path("/topics/#{@topic["id"]}/lines"), params: { text: "Nope" }
    assert_response :forbidden
    patch agenda_path("/lines/#{line["id"]}"), params: { text: "Nope" }
    assert_response :forbidden
    delete agenda_path("/lines/#{line["id"]}")
    assert_response :forbidden
    post agenda_path("/topics/#{@topic["id"]}/lines/reorder"), params: { ids: [line["id"]] }
    assert_response :forbidden
    assert_equal "One", RubylodeAgenda::Line.find(line["id"]).text
  end

  test "text is still editable after closing" do
    line = add_line(@topic, "One")
    post agenda_path("/meetings/#{@meeting.id}/close")
    assert_not_nil @meeting.reload.closed_at
    patch agenda_path("/lines/#{line["id"]}"), params: { text: "Corrected", lock_version: line["lock_version"] }
    assert_response :success
    assert_equal "Corrected", RubylodeAgenda::Line.find(line["id"]).text
  end

  test "the page shows lines with a checkbox and an empty line to type in" do
    add_line(@topic, "One")
    get agenda_path
    assert_select "ol.rubylode-agenda-lines > li.rubylode-agenda-line", count: 1
    assert_select "li.rubylode-agenda-line input[type=checkbox][data-field=line-done]"
    assert_select "input[data-field=line-new]", count: 1
  end
end
