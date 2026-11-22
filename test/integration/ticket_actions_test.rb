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

# The ticket actions of a line's menu: change the ticket, tie tickets together as parent and child, link and unlink.
# Redmine's own rules decide every one of them.
class RubylodeAgendaTicketActionsTest < RubylodeAgendaIntegrationTest
  fixtures :trackers, :projects_trackers, :issue_statuses, :issues, :enumerations, :custom_fields, :custom_values,
           :custom_fields_trackers, :workflows, :versions, :journals, :journal_details

  NOT_FOUND = "No ticket with that number was found.".freeze

  def setup
    super
    Role.find(1).update!(issues_visibility: "default")
    Role.find(1).add_permission!(:edit_issues, :add_issue_notes, :manage_subtasks, :add_issues)
    @agenda = start_agenda
    @topic = add_topic(@agenda, "Release")
    @ticket = Issue.generate!(project_id: 1, tracker_id: 1, subject: "Linked story")
    @other = Issue.generate!(project_id: 1, tracker_id: 1, subject: "Other story")
    @hidden = Issue.generate!(project_id: 1, tracker_id: 1, subject: "Secret plan", is_private: true, author: User.find(3))
    @line = add_line(@topic, "##{@ticket.id}")
    @plain = add_line(@topic, "A plain note")
  end

  def row_of(record)
    Nokogiri::HTML5.fragment(record["html"]).at_css("li")
  end

  def errors
    json_response["errors"]
  end

  # ---- the change form

  test "the change form offers only the statuses the workflow allows from the current one" do
    WorkflowTransition.where(tracker_id: 1, role_id: 1).delete_all
    WorkflowTransition.create!(tracker_id: 1, role_id: 1, old_status_id: 1, new_status_id: 2)
    get agenda_path("/lines/#{@line["id"]}/issue/edit")
    assert_response :success
    assert_equal %w[1 2], css_select("select[name=status_id] option").map { |option| option["value"] }
    assert_select "select[name=status_id] option[selected][value='1']"
    assert_select "select[name=assigned_to_id]"
    assert_select "select[name=priority_id]"
    assert_select "select[name=fixed_version_id]"
    assert_select "input[name=due_date][type=date]"
    assert_select "textarea[name=notes]"
    assert_select "form[data-request-method=PATCH][action='#{agenda_path("/lines/#{@line["id"]}/issue")}']"
  end

  test "percent done is offered only when it is typed by hand" do
    with_settings issue_done_ratio: "issue_field" do
      get agenda_path("/lines/#{@line["id"]}/issue/edit")
      assert_select "select[name=done_ratio]"
    end
    with_settings issue_done_ratio: "issue_status" do
      get agenda_path("/lines/#{@line["id"]}/issue/edit")
      assert_select "select[name=done_ratio]", count: 0
    end
  end

  test "a field made read-only by the workflow is left out of the form" do
    WorkflowPermission.create!(tracker_id: 1, role_id: 1, old_status_id: 1, field_name: "due_date", rule: "readonly")
    get agenda_path("/lines/#{@line["id"]}/issue/edit")
    assert_select "input[name=due_date]", count: 0
  end

  test "a change is journaled and the answer carries the line drawn again" do
    revision = @agenda.reload.revision
    assert_difference "Journal.count", 1 do
      patch agenda_path("/lines/#{@line["id"]}/issue"), params: { status_id: 5, notes: "Done in the meeting" }
    end
    assert_response :success
    @ticket.reload
    assert_equal 5, @ticket.status_id
    journal = @ticket.journals.last
    assert_equal ["Done in the meeting", 2], [journal.notes, journal.user_id]
    assert_equal ["status_id"], journal.details.map(&:prop_key)
    record = json_response["lines"].first
    assert_equal @line["id"], record["id"]
    assert_equal revision + 1, json_response["revision"]
    assert_equal revision + 1, record["revision"]
    assert_equal "Closed", row_of(record).at_css(".rubylode-agenda-ticket-status").text
    assert_includes row_of(record)["class"], "rubylode-agenda-line-closed"
    assert_equal @line["lock_version"], record["lock_version"]
    get agendas_path("/#{@agenda.id}/changes"), params: { since: revision }
    assert_equal [@line["id"]], json_response["lines"].map { |entry| entry["id"] }
  end

  test "every line of the agenda showing the changed ticket is drawn again" do
    second = add_line(@topic, "##{@ticket.id}")
    patch agenda_path("/lines/#{@line["id"]}/issue"), params: { status_id: 5 }
    assert_response :success
    assert_equal [@line["id"], second["id"]].sort, json_response["lines"].map { |record| record["id"] }.sort
  end

  test "a change Redmine refuses answers its message and stores nothing" do
    stranger = User.generate!
    patch agenda_path("/lines/#{@line["id"]}/issue"), params: { assigned_to_id: stranger.id }
    assert_response :unprocessable_entity
    assert_includes errors.join, "Assignee"
    assert_nil @ticket.reload.assigned_to_id
  end

  test "someone who may not edit the ticket gets 403 and the ticket is untouched" do
    Role.find(1).remove_permission!(:edit_issues, :edit_own_issues, :add_issue_notes)
    get agenda_path("/lines/#{@line["id"]}/issue/edit")
    assert_response :forbidden
    patch agenda_path("/lines/#{@line["id"]}/issue"), params: { status_id: 5, notes: "Nope" }
    assert_response :forbidden
    assert_equal [1, 0], [@ticket.reload.status_id, @ticket.journals.count]
  end

  test "a line whose ticket is hidden cannot be changed" do
    RubylodeAgenda::Line.find(@plain["id"]).update_column(:issue_id, @hidden.id)
    get agenda_path("/lines/#{@plain["id"]}/issue/edit")
    assert_response :not_found
    patch agenda_path("/lines/#{@plain["id"]}/issue"), params: { status_id: 5 }
    assert_response :not_found
    assert_equal 1, @hidden.reload.status_id
  end

  # ---- the picker

  test "the picker lists the visible tickets linked on this agenda, not the line's own" do
    topic_ticket = Issue.generate!(project_id: 1, subject: "Topic epic")
    patch agenda_path("/topics/#{@topic["id"]}"), params: { issue_id: topic_ticket.id, lock_version: @topic["lock_version"] }
    add_line(@topic, "##{@other.id}")
    RubylodeAgenda::Line.find(@plain["id"]).update_column(:issue_id, @hidden.id)
    get agenda_path("/lines/#{@line["id"]}/picker"), params: { purpose: "child" }
    assert_response :success
    ids = css_select("[data-picker-ticket]").map { |option| option["data-picker-ticket"].to_i }
    assert_equal [@other.id, topic_ticket.id].sort, ids.sort
    assert_select "[data-picker-ticket='#{@other.id}']", text: /Other story/
    assert_select "form[action='#{agenda_path("/lines/#{@line["id"]}/issue/parent")}'] input[name=ticket]"
  end

  test "the picker for making a child preselects the parent line's ticket" do
    parent_line = add_line(@topic, "##{@other.id}")
    child = add_line(@topic, "Child")
    ticket = Issue.generate!(project_id: 1, subject: "Child story")
    patch agenda_path("/lines/#{child["id"]}"), params: { issue_id: ticket.id, depth: 1, lock_version: child["lock_version"] }
    assert_response :success
    get agenda_path("/lines/#{child["id"]}/picker"), params: { purpose: "child" }
    assert_select "input[name=ticket][value='##{@other.id}']"
    assert_not_nil parent_line
  end

  test "a hidden or missing ticket in a picker request is not found, in the same words" do
    post agenda_path("/lines/#{@plain["id"]}/link"), params: { ticket: "##{@hidden.id}" }
    assert_response :unprocessable_entity
    assert_equal [NOT_FOUND], errors
    post agenda_path("/lines/#{@plain["id"]}/link"), params: { ticket: "999999" }
    assert_equal [NOT_FOUND], errors
    post agenda_path("/lines/#{@line["id"]}/issue/parent"), params: { ticket: @hidden.id }
    assert_equal [NOT_FOUND], errors
    assert_nil @ticket.reload.parent_id
    assert_nil RubylodeAgenda::Line.find(@plain["id"]).issue_id
  end

  test "linking a ticket from the picker links it and keeps the line's text" do
    post agenda_path("/lines/#{@plain["id"]}/link"), params: { ticket: "##{@other.id}" }
    assert_response :success
    stored = RubylodeAgenda::Line.find(@plain["id"])
    assert_equal [@other.id, "A plain note"], [stored.issue_id, stored.text]
    assert_equal "##{@other.id}", row_of(json_response["lines"].first).at_css("a.rubylode-agenda-ticket-number").text
  end

  # ---- parent and child

  test "making the line's ticket a child of another sets its parent" do
    post agenda_path("/lines/#{@line["id"]}/issue/parent"), params: { ticket: "##{@other.id}" }
    assert_response :success
    assert_equal @other.id, @ticket.reload.parent_id
    assert_equal @line["id"], json_response["lines"].first["id"]
  end

  test "making the line's ticket the parent of another sets the other's parent" do
    post agenda_path("/lines/#{@line["id"]}/issue/children"), params: { ticket: @other.id }
    assert_response :success
    assert_equal @ticket.id, @other.reload.parent_id
  end

  test "a loop is refused with Redmine's own message" do
    @ticket.update!(parent_issue_id: @other.id)
    post agenda_path("/lines/#{@line["id"]}/issue/children"), params: { ticket: @other.id }
    assert_response :unprocessable_entity
    assert_includes errors.join, "Parent task"
    assert_nil @other.reload.parent_id
  end

  test "the parent can be removed" do
    @ticket.update!(parent_issue_id: @other.id)
    delete agenda_path("/lines/#{@line["id"]}/issue/parent")
    assert_response :success
    assert_nil @ticket.reload.parent_id
  end

  test "without the subtask permission parent changes are refused" do
    Role.find(1).remove_permission!(:manage_subtasks)
    post agenda_path("/lines/#{@line["id"]}/issue/parent"), params: { ticket: @other.id }
    assert_response :forbidden
    post agenda_path("/lines/#{@line["id"]}/issue/children"), params: { ticket: @other.id }
    assert_response :forbidden
    assert_equal [nil, nil], [@ticket.reload.parent_id, @other.reload.parent_id]
  end

  test "the parent of a ticket the user may not edit is not changed" do
    Role.find(1).remove_permission!(:edit_issues)
    @other.update_column(:author_id, 3)
    post agenda_path("/lines/#{@line["id"]}/issue/children"), params: { ticket: @other.id }
    assert_response :forbidden
    assert_nil @other.reload.parent_id
  end

  # ---- unlink

  test "unlinking keeps the text and leaves the ticket untouched" do
    updated_on = @ticket.reload.updated_on
    patch agenda_path("/lines/#{@line["id"]}"), params: { issue_id: "", lock_version: @line["lock_version"] }
    assert_response :success
    stored = RubylodeAgenda::Line.find(@line["id"])
    assert_equal [nil, "Linked story"], [stored.issue_id, stored.text]
    assert_equal [updated_on, 0, nil], [@ticket.reload.updated_on, @ticket.journals.count, @ticket.parent_id]
  end

  # ---- what the page needs

  test "the rows carry the paths of the ticket actions the user may use" do
    get agenda_path
    linked = css_select("li[data-line-id='#{@line["id"]}']").first
    assert_equal agenda_path("/lines/#{@line["id"]}/issue/edit"), linked["data-change-path"]
    assert_equal agenda_path("/lines/#{@line["id"]}/picker"), linked["data-picker-path"]
    assert_equal "true", linked["data-may-manage-subtasks"]
    assert_nil linked["data-has-parent"]
    plain = css_select("li[data-line-id='#{@plain["id"]}']").first
    assert_equal agenda_path("/lines/#{@plain["id"]}/picker"), plain["data-picker-path"]
    assert_nil plain["data-change-path"]
    Role.find(1).remove_permission!(:edit_issues, :edit_own_issues, :add_issue_notes, :manage_subtasks)
    get agenda_path
    linked = css_select("li[data-line-id='#{@line["id"]}']").first
    assert_nil linked["data-change-path"]
    assert_nil linked["data-may-manage-subtasks"]
  end

  test "a line whose ticket has a parent says so" do
    @ticket.update!(parent_issue_id: @other.id)
    get agenda_path
    assert_select "li[data-line-id='#{@line["id"]}'][data-has-parent='true']"
  end

  test "the menu has the ticket action entries" do
    get agenda_path
    actions = css_select(".rubylode-agenda-menu [role=menuitem]").map { |entry| entry["data-menu-action"] }
    %w[make-child-ticket link-ticket change-ticket make-child-of make-parent-of remove-parent unlink-ticket].each do |action|
      assert_includes actions, action
    end
  end

  test "a reader gets no menu and every ticket action route refuses them" do
    log_in_as_reader
    get agenda_path
    assert_select ".rubylode-agenda-menu", count: 0
    get agenda_path("/lines/#{@line["id"]}/issue/edit")
    assert_response :forbidden
    patch agenda_path("/lines/#{@line["id"]}/issue"), params: { status_id: 5 }
    assert_response :forbidden
    get agenda_path("/lines/#{@line["id"]}/picker"), params: { purpose: "child" }
    assert_response :forbidden
    post agenda_path("/lines/#{@plain["id"]}/link"), params: { ticket: @other.id }
    assert_response :forbidden
    post agenda_path("/lines/#{@line["id"]}/issue/parent"), params: { ticket: @other.id }
    assert_response :forbidden
    delete agenda_path("/lines/#{@line["id"]}/issue/parent")
    assert_response :forbidden
    post agenda_path("/lines/#{@line["id"]}/issue/children"), params: { ticket: @other.id }
    assert_response :forbidden
    assert_equal [1, nil, nil], [@ticket.reload.status_id, @ticket.parent_id, @other.reload.parent_id]
    assert_nil RubylodeAgenda::Line.find(@plain["id"]).issue_id
  end
end
