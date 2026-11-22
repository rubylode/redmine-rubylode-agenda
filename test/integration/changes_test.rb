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

class RubylodeAgendaChangesTest < RubylodeAgendaIntegrationTest
  def setup
    super
    @agenda = start_agenda
    @topic = add_topic(@agenda, "Release")
    @first = add_line(@topic, "First")
    @second = add_line(@topic, "Second")
  end

  def changes_path(since)
    agendas_path("/#{@agenda.id}/changes?since=#{since}")
  end

  test "changes after a revision list only the newer topics and lines" do
    get changes_path(2)
    assert_response :success
    body = json_response
    assert_equal 3, body["revision"]
    assert_equal [], body["topics"]
    assert_equal [@second["id"]], body["lines"].map { |record| record["id"] }
    assert_equal false, body["agenda_closed"]
    assert_includes body["lines"].first["html"], "Second"
    assert_equal @topic["id"], body["lines"].first["topic_id"]
  end

  test "a reader's polled rows are read-only and hold no member list" do
    log_in_as_reader
    get changes_path(0)
    assert_response :success
    rows = (json_response["topics"] + json_response["lines"]).map { |record| record["html"] }.join
    assert_includes rows, "First"
    assert_not_includes rows, "data-update-path"
    assert_not_includes rows, "<select"
  end

  test "since from zero lists everything" do
    get changes_path(0)
    body = json_response
    assert_equal [@topic["id"]], body["topics"].map { |record| record["id"] }
    assert_equal [@first["id"], @second["id"]].sort, body["lines"].map { |record| record["id"] }.sort
  end

  test "with since equal to the current revision both lists are empty" do
    get changes_path(3)
    assert_equal({ "agenda_id" => @agenda.id, "revision" => 3, "topics" => [], "lines" => [], "agenda_closed" => false }, json_response)
  end

  test "a missing or non-numeric since counts as zero" do
    get agendas_path("/#{@agenda.id}/changes")
    assert_equal 2, json_response["lines"].size
    get changes_path("soon")
    assert_equal 2, json_response["lines"].size
  end

  test "deleted records are listed as deleted" do
    delete agenda_path("/lines/#{@first["id"]}")
    get changes_path(3)
    record = json_response["lines"].first
    assert_equal @first["id"], record["id"]
    assert_equal true, record["deleted"]
    assert_nil record["html"]
  end

  test "a closed agenda says so" do
    post agendas_path("/#{@agenda.id}/close")
    get changes_path(3)
    assert_equal true, json_response["agenda_closed"]
  end

  test "a reader may fetch changes" do
    log_in_as_reader
    get changes_path(0)
    assert_response :success
  end

  test "an unknown agenda is not found" do
    get agendas_path("/999999/changes?since=0")
    assert_response :not_found
  end

  test "without the permission the request is refused" do
    Role.find(1).remove_permission!(:view_rubylode_agenda)
    get changes_path(0)
    assert_response :forbidden
  end

  test "the second of two writers on one line gets 409, the first text stays, and the next poll shows it" do
    patch agenda_path("/lines/#{@first["id"]}"), params: { text: "Writer A", lock_version: 0 }
    assert_response :success
    patch agenda_path("/lines/#{@first["id"]}"), params: { text: "Writer B", lock_version: 0 }
    assert_response :conflict
    conflict = json_response["lines"].first
    assert_equal 1, conflict["lock_version"]
    assert_includes conflict["html"], "Writer A"
    assert_equal "Writer A", RubylodeAgenda::Line.find(@first["id"]).text
    get changes_path(3)
    assert_includes json_response["lines"].first["html"], "Writer A"
  end

  test "two writers on different lines both succeed" do
    patch agenda_path("/lines/#{@first["id"]}"), params: { text: "Writer A", lock_version: 0 }
    assert_response :success
    patch agenda_path("/lines/#{@second["id"]}"), params: { text: "Writer B", lock_version: 0 }
    assert_response :success
    assert_equal ["Writer A", "Writer B"], RubylodeAgenda::Line.where(id: [@first["id"], @second["id"]]).order(:id).pluck(:text)
  end
end
