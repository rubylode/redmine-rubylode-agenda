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

class RubylodeAgendaLineIssuesTest < RubylodeAgendaIntegrationTest
  fixtures :trackers, :projects_trackers, :issue_statuses, :issues, :enumerations, :custom_fields, :custom_values,
           :custom_fields_trackers, :workflows, :versions, :journals, :journal_details, :time_entries

  def setup
    super
    @meeting = start_meeting
    @topic = add_topic(@meeting, "Release")
    @line = add_line(@topic, "Write the changelog")
    @open_issue = Issue.generate!(project_id: 1, subject: "Open ticket")
    @closed_issue = Issue.generate!(project_id: 1, subject: "Closed ticket")
    @closed_issue.update_column(:status_id, 5)
    @hidden_issue = Issue.generate!(project_id: 1, subject: "Secret plan", is_private: true, author: User.find(3))
    Role.find(1).update!(issues_visibility: "default")
  end

  def row_of(record)
    Nokogiri::HTML5.fragment(record["html"])
  end

  def add_journal(issue, user_id, notes, private_notes: false)
    Journal.create!(journalized: issue, user_id: user_id, notes: notes, private_notes: private_notes)
  end

  def link_line(issue_id, line: @line)
    patch agenda_path("/lines/#{line["id"]}"), params: { issue_id: issue_id, lock_version: line["lock_version"] }
  end

  test "a line links to a ticket by number and shows its number and status" do
    link_line(@open_issue.id.to_s)
    assert_response :success
    assert_equal @open_issue.id, RubylodeAgenda::Line.find(@line["id"]).issue_id
    row = row_of(json_response["lines"].first)
    assert_equal "##{@open_issue.id}", row.at_css("a.rubylode-agenda-ticket-number").text
    assert_equal "/issues/#{@open_issue.id}", row.at_css("a.rubylode-agenda-ticket-number")["href"]
    assert_equal "New", row.at_css(".rubylode-agenda-ticket-status").text
    assert_nil row.at_css(".rubylode-agenda-line-closed")
    assert_equal "Write the changelog", row.at_css("input[data-field=line-text]")["value"]
  end

  test "a line links to a ticket by a hash number and blank unlinks it" do
    link_line("##{@open_issue.id}")
    assert_equal @open_issue.id, RubylodeAgenda::Line.find(@line["id"]).issue_id
    link_line("", line: json_response["lines"].first)
    assert_response :success
    assert_nil RubylodeAgenda::Line.find(@line["id"]).issue_id
    assert_nil row_of(json_response["lines"].first).at_css("a.rubylode-agenda-ticket-number")
  end

  test "a ticket that is closed shows struck through" do
    link_line(@closed_issue.id.to_s)
    row = row_of(json_response["lines"].first)
    assert_not_nil row.at_css("li.rubylode-agenda-line-closed")
    assert_equal "Closed", row.at_css(".rubylode-agenda-ticket-status").text
  end

  test "a ticket the user cannot see cannot be linked and is not revealed" do
    link_line(@hidden_issue.id.to_s)
    assert_response :unprocessable_entity
    assert_not_includes response.body, "Secret plan"
    assert_nil RubylodeAgenda::Line.find(@line["id"]).issue_id
  end

  test "a number that is no ticket is refused" do
    link_line("99999")
    assert_response :unprocessable_entity
    link_line("abc")
    assert_response :unprocessable_entity
  end

  test "typing a ticket number alone as a new line links it and takes its subject" do
    post agenda_path("/topics/#{@topic["id"]}/lines"), params: { text: "##{@open_issue.id}" }
    assert_response :success
    stored = RubylodeAgenda::Line.find(json_response["lines"].first["id"])
    assert_equal @open_issue.id, stored.issue_id
    assert_equal "Open ticket", stored.text
  end

  test "typing a ticket number alone over a line's text links it too" do
    patch agenda_path("/lines/#{@line["id"]}"), params: { text: "##{@closed_issue.id}", lock_version: @line["lock_version"] }
    assert_response :success
    stored = RubylodeAgenda::Line.find(@line["id"])
    assert_equal [@closed_issue.id, "Closed ticket"], [stored.issue_id, stored.text]
  end

  test "typing the number of a hidden ticket is refused" do
    post agenda_path("/topics/#{@topic["id"]}/lines"), params: { text: "##{@hidden_issue.id}" }
    assert_response :unprocessable_entity
    assert_equal 1, RubylodeAgenda::Line.count
  end

  test "a line whose ticket became invisible shows its text only" do
    link_line(@open_issue.id.to_s)
    @open_issue.update_columns(is_private: true, author_id: 3)
    get agenda_path
    assert_select "input[value='Write the changelog']", count: 1
    assert_select "a.rubylode-agenda-ticket-number", count: 0
    assert_select ".rubylode-agenda-ticket-status", count: 0
    assert_select "a[href='/issues/#{@open_issue.id}']", count: 0
    assert_select "li[data-ticket-path]", count: 0
  end

  test "a topic links to a ticket and its header shows the number" do
    patch agenda_path("/topics/#{@topic["id"]}"), params: { issue_id: @open_issue.id, lock_version: @topic["lock_version"] }
    assert_response :success
    assert_equal @open_issue.id, RubylodeAgenda::Topic.find(@topic["id"]).issue_id
    header = row_of(json_response["topics"].first).at_css(".rubylode-agenda-topic-header")
    assert_equal "##{@open_issue.id}", header.at_css("a.rubylode-agenda-ticket-number").text
    assert_equal "New", header.at_css(".rubylode-agenda-ticket-status").text
  end

  test "a topic cannot link to a hidden ticket, and does not show one that became hidden" do
    patch agenda_path("/topics/#{@topic["id"]}"), params: { issue_id: @hidden_issue.id, lock_version: @topic["lock_version"] }
    assert_response :unprocessable_entity
    RubylodeAgenda::Topic.find(@topic["id"]).update_column(:issue_id, @hidden_issue.id)
    get agenda_path
    assert_select ".rubylode-agenda-topic-header a.rubylode-agenda-ticket-number", count: 0
  end

  test "the ticket fragment shows the latest note, visible subtasks and a link" do
    link_line(@open_issue.id.to_s)
    add_journal(@open_issue, 2, "First note")
    add_journal(@open_issue, 3, "Latest note")
    Issue.generate!(project_id: 1, subject: "Visible subtask", parent_issue_id: @open_issue.id)
    Issue.generate!(project_id: 1, subject: "Hidden subtask", parent_issue_id: @open_issue.id, is_private: true,
                    author: User.find(3))
    get agenda_path("/lines/#{@line["id"]}/issue")
    assert_response :success
    assert_select ".rubylode-agenda-ticket-note", text: /Latest note/
    assert_select ".rubylode-agenda-ticket-note", text: /First note/, count: 0
    assert_select ".rubylode-agenda-ticket-subtask", count: 1
    assert_select ".rubylode-agenda-ticket-subtask", text: /Visible subtask/
    assert_select "a[href='/issues/#{@open_issue.id}']"
  end

  test "the fragment hides private notes from someone who may not see them" do
    link_line(@open_issue.id.to_s)
    add_journal(@open_issue, 2, "Public note")
    add_journal(@open_issue, 3, "Private note", private_notes: true)
    Role.find(1).remove_permission!(:view_private_notes)
    get agenda_path("/lines/#{@line["id"]}/issue")
    assert_select ".rubylode-agenda-ticket-note", text: /Public note/
    assert_select ".rubylode-agenda-ticket-note", text: /Private note/, count: 0
    Role.find(1).add_permission!(:view_private_notes)
    get agenda_path("/lines/#{@line["id"]}/issue")
    assert_select ".rubylode-agenda-ticket-note", text: /Private note/
  end

  test "the fragment shows time logged only with the permission to view it" do
    link_line(@open_issue.id.to_s)
    TimeEntry.create!(project_id: 1, issue_id: @open_issue.id, user_id: 3, hours: 2.5, spent_on: Date.current,
                      activity: TimeEntryActivity.first)
    Role.find(1).add_permission!(:view_time_entries)
    get agenda_path("/lines/#{@line["id"]}/issue")
    assert_select ".rubylode-agenda-ticket-time", text: /2:30/
    Role.find(1).remove_permission!(:view_time_entries)
    get agenda_path("/lines/#{@line["id"]}/issue")
    assert_select ".rubylode-agenda-ticket-time", count: 0
  end

  test "the fragment offers the note form only to someone who may add notes" do
    link_line(@open_issue.id.to_s)
    Role.find(1).add_permission!(:add_issue_notes)
    get agenda_path("/lines/#{@line["id"]}/issue")
    assert_select "form.rubylode-agenda-ticket-note-form textarea[name=notes]", count: 1
    Role.find(1).remove_permission!(:add_issue_notes)
    get agenda_path("/lines/#{@line["id"]}/issue")
    assert_select "form.rubylode-agenda-ticket-note-form", count: 0
  end

  test "the fragment of a line without a visible ticket is not found" do
    get agenda_path("/lines/#{@line["id"]}/issue")
    assert_response :not_found
    link_line(@open_issue.id.to_s)
    @open_issue.update_columns(is_private: true, author_id: 3)
    get agenda_path("/lines/#{@line["id"]}/issue")
    assert_response :not_found
  end

  test "a reader may open the fragment but not add a note" do
    link_line(@open_issue.id.to_s)
    log_in_as_reader
    get agenda_path("/lines/#{@line["id"]}/issue")
    assert_response :success
    post agenda_path("/lines/#{@line["id"]}/notes"), params: { notes: "Nope" }
    assert_response :forbidden
  end

  test "adding a note writes a journal as the current user" do
    link_line(@open_issue.id.to_s)
    Role.find(1).add_permission!(:add_issue_notes)
    assert_difference "Journal.count", 1 do
      post agenda_path("/lines/#{@line["id"]}/notes"), params: { notes: "Discussed, moving on" }
    end
    assert_response :success
    journal = @open_issue.reload.journals.last
    assert_equal ["Discussed, moving on", 2], [journal.notes, journal.user_id]
    assert_not journal.private_notes
    assert_includes response.body, "Discussed, moving on"
  end

  test "adding a note without the permission is forbidden" do
    link_line(@open_issue.id.to_s)
    Role.find(1).remove_permission!(:add_issue_notes)
    assert_no_difference "Journal.count" do
      post agenda_path("/lines/#{@line["id"]}/notes"), params: { notes: "Not allowed" }
    end
    assert_response :forbidden
  end

  test "an empty note is refused" do
    link_line(@open_issue.id.to_s)
    Role.find(1).add_permission!(:add_issue_notes)
    assert_no_difference "Journal.count" do
      post agenda_path("/lines/#{@line["id"]}/notes"), params: { notes: "  " }
    end
    assert_response :unprocessable_entity
  end

  test "creating a ticket takes parent, version and assignee from the topic" do
    parent = Issue.generate!(project_id: 1, subject: "Release epic", fixed_version_id: 3)
    owned_topic = add_topic(@meeting, "Owned", owner_id: 3)
    patch agenda_path("/topics/#{owned_topic["id"]}"),
          params: { issue_id: parent.id, lock_version: owned_topic["lock_version"] }
    owned_line = add_line(owned_topic, "Ship the build")
    assert_difference "Issue.count", 1 do
      post agenda_path("/lines/#{owned_line["id"]}/issue")
    end
    assert_response :success
    created = Issue.order(:id).last
    assert_equal "Ship the build", created.subject
    assert_equal [parent.id, 3, 3, 2, 1], [created.parent_id, created.fixed_version_id, created.assigned_to_id,
                                          created.author_id, created.project_id]
    assert_equal 1, created.tracker_id
    stored = RubylodeAgenda::Line.find(owned_line["id"])
    assert_equal created.id, stored.issue_id
    row = row_of(json_response["lines"].first)
    assert_equal "##{created.id}", row.at_css("a.rubylode-agenda-ticket-number").text
  end

  test "creating a ticket from a line raises the revision and stamps the line" do
    post agenda_path("/lines/#{@line["id"]}/issue")
    assert_response :success
    assert_equal 3, json_response["revision"]
    assert_equal 3, RubylodeAgenda::Line.find(@line["id"]).revision
    assert_equal 3, @meeting.reload.revision
  end

  test "creating a ticket uses the form values over the defaults" do
    owned_topic = add_topic(@meeting, "Owned", owner_id: 3)
    owned_line = add_line(owned_topic, "Ship the build")
    post agenda_path("/lines/#{owned_line["id"]}/issue"),
         params: { subject: "A better subject", tracker_id: "2", assigned_to_id: "", fixed_version_id: "7" }
    assert_response :success
    created = Issue.order(:id).last
    assert_equal ["A better subject", 2, nil, 7], [created.subject, created.tracker_id, created.assigned_to_id,
                                                   created.fixed_version_id]
  end

  test "creating a ticket needs the add issues permission" do
    Role.find(1).remove_permission!(:add_issues)
    assert_no_difference "Issue.count" do
      post agenda_path("/lines/#{@line["id"]}/issue")
    end
    assert_response :forbidden
    assert_nil RubylodeAgenda::Line.find(@line["id"]).issue_id
  end

  test "a reader cannot create a ticket or see the form" do
    log_in_as_reader
    post agenda_path("/lines/#{@line["id"]}/issue")
    assert_response :forbidden
    get agenda_path("/lines/#{@line["id"]}/issue/new")
    assert_response :forbidden
  end

  test "a ticket that fails validation answers 422 and leaves the line alone" do
    stranger = User.generate!
    assert_no_difference "Issue.count" do
      post agenda_path("/lines/#{@line["id"]}/issue"), params: { assigned_to_id: stranger.id }
    end
    assert_response :unprocessable_entity
    assert_includes json_response["errors"].join, "Assignee"
    assert_nil RubylodeAgenda::Line.find(@line["id"]).issue_id
  end

  test "a tracker the project does not offer is refused" do
    post agenda_path("/lines/#{@line["id"]}/issue"), params: { tracker_id: "99" }
    assert_response :unprocessable_entity
    assert_nil RubylodeAgenda::Line.find(@line["id"]).issue_id
  end

  test "a line that already has a ticket does not make another" do
    link_line(@open_issue.id.to_s)
    assert_no_difference "Issue.count" do
      post agenda_path("/lines/#{@line["id"]}/issue")
    end
    assert_response :unprocessable_entity
  end

  test "the form fragment is prefilled from the line and the topic" do
    parent = Issue.generate!(project_id: 1, subject: "Release epic", fixed_version_id: 3)
    owned_topic = add_topic(@meeting, "Owned", owner_id: 3)
    patch agenda_path("/topics/#{owned_topic["id"]}"),
          params: { issue_id: parent.id, lock_version: owned_topic["lock_version"] }
    owned_line = add_line(owned_topic, "Ship the build")
    get agenda_path("/lines/#{owned_line["id"]}/issue/new")
    assert_response :success
    assert_select "form[action='#{agenda_path("/lines/#{owned_line["id"]}/issue")}']"
    assert_select "input[name=subject][value='Ship the build']"
    assert_select "input[name=parent_issue_id][value='#{parent.id}']"
    assert_select "select[name=tracker_id] option", minimum: 2
    assert_select "select[name=assigned_to_id] option[selected][value='3']"
    assert_select "select[name=fixed_version_id] option[selected][value='3']"
  end

  test "the page gives the line row the paths the script needs" do
    get agenda_path
    assert_select "li[data-line-id='#{@line["id"]}'][data-new-ticket-path='#{agenda_path("/lines/#{@line["id"]}/issue/new")}']"
    link_line(@open_issue.id.to_s)
    get agenda_path
    assert_select "li[data-ticket-path='#{agenda_path("/lines/#{@line["id"]}/issue")}']"
    assert_select "li[data-new-ticket-path]", count: 0
  end
end
