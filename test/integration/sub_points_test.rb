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

# Sub-points: a line's depth (0, 1 or 2) in the topic's flat order. A line may sit at most one level below the line above
# it; the first line of a topic is always at depth 0.
class RubylodeAgendaSubPointsTest < RubylodeAgendaIntegrationTest
  def setup
    super
    @agenda = start_agenda
    @topic = add_topic(@agenda, "Release")
  end

  def set_depth(record, depth)
    patch agenda_path("/lines/#{record["id"]}"), params: { depth: depth, lock_version: record["lock_version"] }
    json_response["lines"]&.first
  end

  def stored_depth(record)
    RubylodeAgenda::Line.find(record["id"]).depth
  end

  def row_of(record)
    Nokogiri::HTML5.fragment(record["html"]).at_css("li")
  end

  def page_depths
    css_select("ol.rubylode-agenda-lines > li.rubylode-agenda-line").map do |row|
      field = row.at_css("[data-field=line-text]")
      [field.text.presence || field["value"], row["class"][/rubylode-agenda-depth-(\d)/, 1].to_i]
    end
  end

  test "a new line sits at depth 0 and its record says so" do
    record = add_line(@topic, "First")
    assert_equal 0, record["depth"]
    assert_equal 0, stored_depth(record)
    assert_includes row_of(record)["class"], "rubylode-agenda-depth-0"
    assert_equal "0", row_of(record)["data-depth"]
  end

  test "indenting a line writes its depth like any other field" do
    add_line(@topic, "Parent")
    child = add_line(@topic, "Child")
    record = set_depth(child, 1)
    assert_response :success
    assert_equal [1, 1], [record["depth"], record["lock_version"]]
    assert_equal 4, json_response["revision"]
    assert_equal 1, stored_depth(child)
    assert_includes row_of(record)["class"], "rubylode-agenda-depth-1"
  end

  test "the first line of a topic stays at depth 0" do
    first = add_line(@topic, "First")
    record = set_depth(first, 1)
    assert_response :success
    assert_equal 0, record["depth"]
    assert_equal 0, stored_depth(first)
  end

  test "a line goes at most one level below the line above it" do
    add_line(@topic, "Parent")
    child = add_line(@topic, "Child")
    set_depth(child, 2)
    assert_response :success
    assert_equal 1, stored_depth(child)
    grandchild = add_line(@topic, "Grandchild")
    set_depth(grandchild, 2)
    assert_equal 2, stored_depth(grandchild)
  end

  test "a depth outside 0 to 2 is refused" do
    add_line(@topic, "Parent")
    child = add_line(@topic, "Child")
    ["3", "-1", "deep"].each do |depth|
      patch agenda_path("/lines/#{child["id"]}"), params: { depth: depth, lock_version: child["lock_version"] }
      assert_response :unprocessable_entity
    end
    assert_equal 0, stored_depth(child)
  end

  test "a stale depth save answers 409 and changes nothing" do
    add_line(@topic, "Parent")
    child = add_line(@topic, "Child")
    patch agenda_path("/lines/#{child["id"]}"), params: { text: "Child, reworded", lock_version: child["lock_version"] }
    set_depth(child, 1)
    assert_response :conflict
    assert_equal 1, json_response["lines"].first["lock_version"]
    assert_equal 0, stored_depth(child)
  end

  test "depth and text can be saved together" do
    add_line(@topic, "Parent")
    child = add_line(@topic, "Child")
    patch agenda_path("/lines/#{child["id"]}"), params: { text: "Child, typed", depth: 1, lock_version: child["lock_version"] }
    assert_response :success
    stored = RubylodeAgenda::Line.find(child["id"])
    assert_equal ["Child, typed", 1], [stored.text, stored.depth]
  end

  test "indenting never makes a ticket" do
    add_line(@topic, "Parent")
    child = add_line(@topic, "Child")
    assert_no_difference "Issue.count" do
      set_depth(child, 1)
    end
  end

  test "a reader cannot change a depth" do
    add_line(@topic, "Parent")
    child = add_line(@topic, "Child")
    log_in_as_reader
    patch agenda_path("/lines/#{child["id"]}"), params: { depth: 1 }
    assert_response :forbidden
    assert_equal 0, stored_depth(child)
  end

  test "the page shows a child deeper than its new neighbour allows one level lower, without writing" do
    add_line(@topic, "Parent")
    middle = add_line(@topic, "Middle")
    set_depth(middle, 1)
    deepest = add_line(@topic, "Deepest")
    set_depth(deepest, 2)
    delete agenda_path("/lines/#{middle["id"]}")
    revision = @agenda.reload.revision
    get agenda_path
    assert_equal [["Parent", 0], ["Deepest", 1]], page_depths
    assert_select "li[data-line-id='#{deepest["id"]}'][data-depth='2']"
    assert_equal 2, stored_depth(deepest)
    assert_equal revision, @agenda.reload.revision
  end

  test "a line made after another goes right below it at the depth asked, and the lines after it move down" do
    first = add_line(@topic, "First")
    second = add_line(@topic, "Second")
    third = add_line(@topic, "Third")
    post agenda_path("/topics/#{@topic["id"]}/lines"), params: { text: "Under first", after_id: first["id"], depth: 1 }
    assert_response :success
    body = json_response
    made = body["lines"].find { |record| record["html"].include?("Under first") }
    assert_equal [2, 1], [made["position"], made["depth"]]
    moved = body["lines"].reject { |record| record["id"] == made["id"] }.to_h { |record| [record["id"], record["position"]] }
    assert_equal({ second["id"] => 3, third["id"] => 4 }, moved)
    assert_equal 7, body["revision"]
    get agenda_path
    assert_equal [["First", 0], ["Under first", 1], ["Second", 0], ["Third", 0]], page_depths
  end

  test "a new line asked deeper than allowed is made at the deepest allowed" do
    post agenda_path("/topics/#{@topic["id"]}/lines"), params: { text: "Alone", depth: 2 }
    assert_response :success
    assert_equal 0, json_response["lines"].first["depth"]
    parent = add_line(@topic, "Parent")
    post agenda_path("/topics/#{@topic["id"]}/lines"), params: { text: "Below", after_id: parent["id"], depth: 2 }
    assert_equal 1, json_response["lines"].first["depth"]
  end

  test "a line dragged keeps its depth only as far as its new place allows" do
    add_line(@topic, "Parent")
    child = add_line(@topic, "Child")
    set_depth(child, 1)
    parent_id = RubylodeAgenda::Line.find_by(text: "Parent").id
    post agenda_path("/topics/#{@topic["id"]}/lines/reorder"), params: { ids: [child["id"], parent_id] }
    assert_response :success
    assert_equal 0, stored_depth(child)
    assert_equal 0, json_response["lines"].find { |record| record["id"] == child["id"] }["depth"]
  end

  test "a line dragged to a place that allows its depth keeps it" do
    add_line(@topic, "Parent")
    child = add_line(@topic, "Child")
    set_depth(child, 1)
    other = add_topic(@agenda, "Budget")
    target = add_line(other, "Target")
    post agenda_path("/topics/#{other["id"]}/lines/reorder"), params: { ids: [target["id"], child["id"]] }
    assert_response :success
    assert_equal 1, stored_depth(child)
  end

  test "carrying over copies the depth and quiet lines keep it inside the fold" do
    add_line(@topic, "Parent")
    child = add_line(@topic, "Child")
    set_depth(child, 1)
    post agendas_path("")
    carried = RubylodeAgenda::Agenda.order(:id).last.lines.in_order.to_a
    assert_equal [0, 1], carried.map(&:depth)
    get agenda_path
    assert_select "li.rubylode-agenda-quiet li.rubylode-agenda-line.rubylode-agenda-depth-1", count: 1
    assert_select "li.rubylode-agenda-quiet li.rubylode-agenda-line.rubylode-agenda-depth-0", count: 1
  end

  test "a parked line comes back at depth 0" do
    add_line(@topic, "Parent")
    child = add_line(@topic, "Child")
    set_depth(child, 1)
    post agenda_path("/lines/#{child["id"]}/park")
    post agenda_path("/lines/#{child["id"]}/unpark")
    assert_response :success
    assert_equal 0, stored_depth(child)
  end

  test "a reader sees the sub-points too" do
    add_line(@topic, "Parent")
    child = add_line(@topic, "Child")
    set_depth(child, 1)
    log_in_as_reader
    get agenda_path
    assert_select "li.rubylode-agenda-line.rubylode-agenda-depth-1 .rubylode-agenda-line-text", text: "Child"
  end
end
