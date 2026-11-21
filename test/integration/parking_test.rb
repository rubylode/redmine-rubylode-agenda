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

class RubylodeAgendaParkingTest < RubylodeAgendaIntegrationTest
  fixtures :trackers, :projects_trackers, :issue_statuses, :issues, :enumerations, :custom_fields, :custom_values,
           :custom_fields_trackers, :workflows

  def setup
    super
    @meeting = start_meeting
    @topic = add_topic(@meeting, "Release", owner_id: 3)
    @line = add_line(@topic, "Write the changelog")
  end

  def park(line = @line)
    post agenda_path("/lines/#{line["id"]}/park")
  end

  def unpark(line = @line)
    post agenda_path("/lines/#{line["id"]}/unpark")
  end

  test "parking a line stamps it, bumps the revision and says parked" do
    park
    assert_response :success
    body = json_response
    assert_equal 3, body["revision"]
    record = body["lines"].first
    assert_equal [@line["id"], true, false], [record["id"], record["parked"], record["deleted"]]
    stored = RubylodeAgenda::Line.find(@line["id"])
    assert_not_nil stored.parked_at
    assert_equal 3, stored.revision
    assert_equal 3, @meeting.reload.revision
  end

  test "a parked line is not shown in the agenda" do
    add_line(@topic, "Stays")
    park
    get agenda_path
    assert_select "ol.rubylode-agenda-lines textarea[data-field=line-text]", count: 1
    assert_select "ol.rubylode-agenda-lines textarea[data-field=line-text]", text: "Stays", count: 1
    assert_select "ol.rubylode-agenda-lines textarea[data-field=line-text]", text: "Write the changelog", count: 0
  end

  test "the parked list shows the line, the topic it left, the date and a button to bring it back" do
    travel_to Time.zone.local(2026, 11, 22, 10, 0) do
      park
    end
    get agenda_path
    assert_select "details.rubylode-agenda-parked li.rubylode-agenda-parked-line", count: 1
    assert_select "details.rubylode-agenda-parked li", text: /Write the changelog/
    assert_select "details.rubylode-agenda-parked .rubylode-agenda-parked-topic", text: "Release"
    assert_select "details.rubylode-agenda-parked .rubylode-agenda-parked-date", text: "11/22/2026"
    assert_select "details.rubylode-agenda-parked button[data-unpark-path='#{agenda_path("/lines/#{@line["id"]}/unpark")}']",
                  text: "Bring back"
    assert_select "details.rubylode-agenda-parked[open]", count: 0
  end

  test "the answer to parking carries the refreshed parked list" do
    park
    assert_includes json_response["parked_html"], "Write the changelog"
    unpark
    assert_not_includes json_response["parked_html"], "Write the changelog"
  end

  test "a deleted parked line is not listed" do
    park
    delete agenda_path("/lines/#{@line["id"]}")
    get agenda_path
    assert_select "li.rubylode-agenda-parked-line", count: 0
  end

  test "the parked list is read-only for a reader" do
    park
    log_in_as_reader
    get agenda_path
    assert_select "li.rubylode-agenda-parked-line", count: 1
    assert_select "li.rubylode-agenda-parked-line button", count: 0
  end

  test "the parked list keeps lines of earlier meetings" do
    park
    post agenda_path("/meetings")
    get agenda_path
    assert_select "li.rubylode-agenda-parked-line", text: /Write the changelog/, count: 1
  end

  test "bringing a line back puts it at the end of the topic with the same title in the open meeting" do
    other = add_line(@topic, "Other line")
    park
    post agenda_path("/meetings")
    open_meeting = RubylodeAgenda::Meeting.order(:id).last
    existing = open_meeting.topics.first
    assert_equal "Release", existing.title
    assert_equal ["Other line"], existing.lines.map(&:text)
    unpark
    assert_response :success
    body = json_response
    assert_equal [], body["topics"]
    record = body["lines"].first
    assert_equal [existing.id, 2, false], [record["topic_id"], record["position"], record["parked"]]
    stored = RubylodeAgenda::Line.find(@line["id"])
    assert_equal [open_meeting.id, existing.id], [stored.meeting_id, stored.topic_id]
    assert_nil stored.parked_at
    assert_equal open_meeting.reload.revision, body["revision"]
    assert_equal ["Other line", "Write the changelog"], existing.lines.shown.in_order.map(&:text)
    assert_not_nil other
  end

  test "bringing a line back answers with the open meeting's id and path, not the one it was parked in" do
    park
    assert_equal @meeting.id, json_response["meeting_id"]
    post agenda_path("/meetings")
    open_meeting = RubylodeAgenda::Meeting.order(:id).last
    unpark
    assert_equal open_meeting.id, json_response["meeting_id"]
    assert_equal agenda_path("/meetings/#{open_meeting.id}"), json_response["meeting_path"]
  end

  test "every write answer and the polling answer name their meeting" do
    patch agenda_path("/lines/#{@line["id"]}"), params: { done: "1", lock_version: 0 }
    assert_equal @meeting.id, json_response["meeting_id"]
    get agenda_path("/meetings/#{@meeting.id}/changes"), params: { since: 0 }
    assert_equal @meeting.id, json_response["meeting_id"]
  end

  test "bringing a line back raises the open meeting's revision and stamps the line and the topic it made" do
    park
    post agenda_path("/meetings")
    open_meeting = RubylodeAgenda::Meeting.order(:id).last
    unpark
    assert_response :success
    assert_equal 2, json_response["revision"]
    assert_equal 2, open_meeting.reload.revision
    assert_equal 2, RubylodeAgenda::Line.find(@line["id"]).revision
    assert_equal 1, open_meeting.topics.first.revision
    assert_equal 3, @meeting.reload.revision
  end

  test "bringing a line back makes the topic at the end when the open meeting has none like it" do
    park
    post agenda_path("/meetings")
    open_meeting = RubylodeAgenda::Meeting.order(:id).last
    assert_equal [], open_meeting.topics.to_a
    add_topic(open_meeting, "Budget")
    unpark
    assert_response :success
    body = json_response
    made = open_meeting.topics.active.order(:position).last
    assert_equal ["Budget", "Release"], open_meeting.topics.active.order(:position).map(&:title)
    assert_equal [made.id], body["topics"].map { |record| record["id"] }
    assert_equal 3, made.owner_id
    assert_equal made.id, body["lines"].first["topic_id"]
    assert_includes body["topics"].first["html"], "Write the changelog"
  end

  test "bringing a line back in the meeting it was parked in puts it under its own topic again" do
    add_line(@topic, "Other line")
    park
    unpark
    assert_response :success
    stored = RubylodeAgenda::Line.find(@line["id"])
    assert_equal [@topic["id"], @meeting.id, 3], [stored.topic_id, stored.meeting_id, stored.position]
  end

  test "bringing a line back is refused when the project has no open meeting" do
    park
    post agenda_path("/meetings/#{@meeting.id}/close")
    unpark
    assert_response :unprocessable_entity
    assert_includes json_response["errors"].first, "open meeting"
    stored = RubylodeAgenda::Line.find(@line["id"])
    assert_not_nil stored.parked_at
    assert_equal @meeting.id, stored.meeting_id
  end

  test "a stale park is refused with the current line" do
    patch agenda_path("/lines/#{@line["id"]}"), params: { text: "Reworded", lock_version: @line["lock_version"] }
    post agenda_path("/lines/#{@line["id"]}/park"), params: { lock_version: @line["lock_version"] }
    assert_response :conflict
    assert_nil RubylodeAgenda::Line.find(@line["id"]).parked_at
  end

  test "a reader cannot park or bring back" do
    park
    log_in_as_reader
    unpark
    assert_response :forbidden
    assert_not_nil RubylodeAgenda::Line.find(@line["id"]).parked_at
    other = add_line_as_manager
    post agenda_path("/lines/#{other}/park")
    assert_response :forbidden
  end

  private

  def add_line_as_manager
    RubylodeAgenda::Line.create!(topic_id: @topic["id"], meeting_id: @meeting.id, text: "Another").id
  end
end
