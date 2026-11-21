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

# A second project with the module on and the same person as manager there. Everything is addressed through the first
# project's path with a record of the second one, and must answer not found and change nothing.
class RubylodeAgendaOtherProjectTest < RubylodeAgendaIntegrationTest
  fixtures :trackers, :projects_trackers, :issue_statuses, :issues, :enumerations, :custom_fields, :custom_values,
           :custom_fields_trackers, :workflows

  def setup
    super
    @first_project = @project
    @other_project = Project.find(3)
    @other_project.enable_module!(:rubylode_agenda)
    Member.where(project_id: 3, user_id: 2).first_or_create!(role_ids: [1])
    @other_ticket = Issue.generate!(project_id: 3, subject: "Other project ticket")

    @project = @other_project
    @other_meeting = start_meeting
    @other_topic = add_topic(@other_meeting, "Elsewhere")
    @other_line = add_line(@other_topic, "##{@other_ticket.id}")
    @other_parked_line = add_line(@other_topic, "Parked elsewhere")
    post agenda_path("/lines/#{@other_parked_line["id"]}/park")
    @project = @first_project
    @meeting = start_meeting
    @topic = add_topic(@meeting, "Here")
    @line = add_line(@topic, "Here too")
    @before = stored_state
  end

  def stored_state
    [RubylodeAgenda::Meeting.order(:id).pluck(:id, :revision, :closed_at),
     RubylodeAgenda::Topic.order(:id).pluck(:id, :title, :position, :lock_version, :revision, :deleted_at),
     RubylodeAgenda::Line.order(:id).pluck(:id, :text, :topic_id, :position, :done, :lock_version, :revision,
                                           :deleted_at, :parked_at, :issue_id)]
  end

  def assert_refused_and_unchanged
    assert_response :not_found
    assert_equal @before, stored_state
  end

  test "updating a line of another project" do
    patch agenda_path("/lines/#{@other_line["id"]}"), params: { text: "Hijacked", lock_version: 0 }
    assert_refused_and_unchanged
  end

  test "deleting a line of another project" do
    delete agenda_path("/lines/#{@other_line["id"]}")
    assert_refused_and_unchanged
  end

  test "reordering with the lines of another project" do
    post agenda_path("/topics/#{@other_topic["id"]}/lines/reorder"), params: { ids: [@other_line["id"]] }
    assert_refused_and_unchanged
    post agenda_path("/topics/#{@topic["id"]}/lines/reorder"), params: { ids: [@other_line["id"], @line["id"]] }
    assert_response :success
    assert_equal @before, stored_state
  end

  test "updating, deleting and reordering a topic of another project" do
    patch agenda_path("/topics/#{@other_topic["id"]}"), params: { title: "Hijacked", lock_version: 0 }
    assert_refused_and_unchanged
    delete agenda_path("/topics/#{@other_topic["id"]}")
    assert_refused_and_unchanged
    post agenda_path("/meetings/#{@other_meeting.id}/topics/reorder"), params: { ids: [@other_topic["id"]] }
    assert_refused_and_unchanged
    post agenda_path("/meetings/#{@other_meeting.id}/topics"), params: { title: "Planted" }
    assert_refused_and_unchanged
  end

  test "creating a line in a topic of another project" do
    post agenda_path("/topics/#{@other_topic["id"]}/lines"), params: { text: "Planted" }
    assert_refused_and_unchanged
  end

  test "parking a line of another project" do
    post agenda_path("/lines/#{@other_line["id"]}/park")
    assert_refused_and_unchanged
  end

  test "bringing back a parked line of another project" do
    post agenda_path("/lines/#{@other_parked_line["id"]}/unpark")
    assert_refused_and_unchanged
  end

  test "the ticket fragment, the form and the notes of a line of another project" do
    get agenda_path("/lines/#{@other_line["id"]}/issue", project: @other_project)
    assert_response :success
    get agenda_path("/lines/#{@other_line["id"]}/issue")
    assert_refused_and_unchanged
    get agenda_path("/lines/#{@other_line["id"]}/issue/new")
    assert_refused_and_unchanged
    post agenda_path("/lines/#{@other_line["id"]}/issue")
    assert_refused_and_unchanged
    post agenda_path("/lines/#{@other_line["id"]}/notes"), params: { notes: "Planted" }
    assert_refused_and_unchanged
    assert_equal 0, Journal.where(journalized_id: @other_ticket.id, notes: "Planted").count
  end

  test "polling a meeting of another project" do
    get agenda_path("/meetings/#{@other_meeting.id}/changes?since=0")
    assert_refused_and_unchanged
  end

  test "closing and changing a meeting of another project" do
    post agenda_path("/meetings/#{@other_meeting.id}/close")
    assert_refused_and_unchanged
    patch agenda_path("/meetings/#{@other_meeting.id}"), params: { held_on: "2026-12-01" }
    assert_refused_and_unchanged
  end
end
