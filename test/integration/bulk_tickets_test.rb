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

# Several tickets at once: the review of the selected lines with their defaults, and one request that makes them all,
# parents first, or none.
class RubylodeAgendaBulkTicketsTest < RubylodeAgendaIntegrationTest
  fixtures :trackers, :projects_trackers, :issue_statuses, :issues, :enumerations, :custom_fields, :custom_values,
           :custom_fields_trackers, :workflows, :versions

  def setup
    super
    Role.find(1).update!(issues_visibility: "default")
    Role.find(1).add_permission!(:add_issues, :manage_subtasks, :edit_issues)
    @agenda = start_agenda
    @topic = add_topic(@agenda, "Release", owner_id: 3)
    @parent = add_line(@topic, "Ship the release\nWith notes")
    @child = sub_point(@topic, "Check the build", 1)
    @other_topic = add_topic(@agenda, "Budget")
    @plain = add_line(@other_topic, "Count the costs")
  end

  def sub_point(topic, text, depth)
    record = add_line(topic, text)
    patch agenda_path("/lines/#{record["id"]}"), params: { depth: depth, lock_version: record["lock_version"] }
    json_response["lines"].first
  end

  def review(*records)
    get agendas_path("/#{@agenda.id}/tickets/review"), params: { line_ids: records.map { |record| record["id"] } }
  end

  def row(record)
    css_select("tr[data-review-line-id='#{record["id"]}']").first
  end

  def lock_of(record)
    RubylodeAgenda::Line.find(record["id"]).lock_version
  end

  def create_rows(rows)
    post agendas_path("/#{@agenda.id}/tickets"), params: { rows: rows }, as: :json
  end

  def row_params(record, **values)
    { line_id: record["id"], lock_version: lock_of(record), subject: RubylodeAgenda::Line.find(record["id"]).ticket_subject,
      description: "", project_id: 1, tracker_id: 1, assigned_to_id: "", fixed_version_id: "", parent: "" }.merge(values)
  end

  def other_allowed_project
    Issue.allowed_target_projects(User.find(2)).where.not(id: 1).order(:id).first
  end

  # ---- the review

  test "the review lists the selected lines in agenda order with the subject and the rest as description" do
    review(@plain, @child, @parent)
    assert_response :success
    assert_equal [@parent, @child, @plain].map { |record| record["id"].to_s },
                 css_select("tr[data-review-line-id]").map { |element| element["data-review-line-id"] }
    assert_equal "Ship the release", row(@parent).at_css("input[name='rows[][subject]']")["value"]
    assert_equal "With notes", row(@parent).at_css("[name='rows[][description]']").text.strip
    assert_includes row(@child)["class"], "rubylode-agenda-review-depth-1"
    assert_select ".rubylode-agenda-review-summary", text: /3 tickets will be created/
  end

  test "a sub-point whose parent line is selected gets the ticket made from that line as parent" do
    review(@parent, @child)
    assert_equal "line 1.a", row(@child).at_css("input[name='rows[][parent]']")["value"]
    assert_equal "", row(@parent).at_css("input[name='rows[][parent]']")["value"].to_s
  end

  test "a sub-point whose parent line has a ticket gets that ticket, else the topic's" do
    topic_ticket = Issue.generate!(project_id: 1, subject: "Topic epic")
    patch agenda_path("/topics/#{@topic["id"]}"), params: { issue_id: topic_ticket.id, lock_version: @topic["lock_version"] }
    review(@parent, @child)
    assert_equal "##{topic_ticket.id}", row(@parent).at_css("input[name='rows[][parent]']")["value"]
    line_ticket = Issue.generate!(project_id: 1, subject: "Line story")
    patch agenda_path("/lines/#{@parent["id"]}"), params: { issue_id: line_ticket.id, lock_version: lock_of(@parent) }
    review(@child)
    assert_equal "##{line_ticket.id}", row(@child).at_css("input[name='rows[][parent]']")["value"]
  end

  test "the assignee is the topic's owner, the project the agenda's, the tracker the first allowed" do
    review(@parent, @plain)
    assert_equal "3", row(@parent).at_css("select[name='rows[][assigned_to_id]'] option[selected]")["value"]
    assert_nil row(@plain).at_css("select[name='rows[][assigned_to_id]'] option[selected]")&.[]("value").presence
    assert_equal "1", row(@parent).at_css("select[name='rows[][project_id]'] option[selected]")["value"]
    assert_equal "1", row(@parent).at_css("select[name='rows[][project_id]'] option")["value"]
    assert_equal "1", row(@parent).at_css("select[name='rows[][tracker_id]'] option[selected]")["value"]
    assert_select ".rubylode-agenda-review-all select[name=all_project_id]"
    assert_select ".rubylode-agenda-review-all select[name=all_tracker_id]"
    assert_select ".rubylode-agenda-review-all select[name=all_assigned_to_id]"
  end

  test "the project choices are the projects where the user may add tickets" do
    review(@plain)
    offered = row(@plain).css("select[name='rows[][project_id]'] option").map { |option| option["value"].to_i }
    assert_equal Issue.allowed_target_projects(User.find(2)).pluck(:id).sort, offered.sort
  end

  test "the choices of another project come back for one row" do
    project = other_allowed_project
    get agendas_path("/#{@agenda.id}/tickets/choices"), params: { target_project_id: project.id, line_id: @plain["id"] }
    assert_response :success
    trackers = Issue.new(project: project, author: User.find(2)).allowed_target_trackers(User.find(2))
    assert_equal trackers.map(&:id), json_response["trackers"].map(&:first)
    assert_equal trackers.first.id, json_response["tracker_id"]
    assert json_response.key?("assignees")
    assert json_response.key?("versions")
  end

  test "more than 50 lines are refused" do
    get agendas_path("/#{@agenda.id}/tickets/review"), params: { line_ids: (1..51).to_a }
    assert_response :unprocessable_entity
    assert_includes json_response["errors"].join, "50"
  end

  # ---- creating

  test "a mixed batch is made parents first, in the right projects, and the lines are linked" do
    project = other_allowed_project
    rows = [row_params(@parent, description: "With notes", assigned_to_id: 3),
            row_params(@child, parent: "line 1.a"),
            row_params(@plain, project_id: project.id,
                               tracker_id: Issue.new(project: project).allowed_target_trackers(User.find(2)).first.id)]
    assert_difference "Issue.count", 3 do
      create_rows(rows)
    end
    assert_response :success
    parent_ticket = Issue.find(RubylodeAgenda::Line.find(@parent["id"]).issue_id)
    child_ticket = Issue.find(RubylodeAgenda::Line.find(@child["id"]).issue_id)
    plain_ticket = Issue.find(RubylodeAgenda::Line.find(@plain["id"]).issue_id)
    assert_equal ["Ship the release", "With notes", 3, 1], [parent_ticket.subject, parent_ticket.description, parent_ticket.assigned_to_id, parent_ticket.project_id]
    assert_equal [parent_ticket.id, "Check the build"], [child_ticket.parent_id, child_ticket.subject]
    assert_equal project.id, plain_ticket.project_id
    assert_equal 3, json_response["created"].size
    assert_equal "3 tickets created", json_response["notice"]
    assert_equal [@parent["id"], @child["id"], @plain["id"]].sort, json_response["lines"].map { |record| record["id"] }.sort
  end

  test "an existing ticket can be the parent" do
    ticket = Issue.generate!(project_id: 1, subject: "Epic")
    create_rows([row_params(@plain, parent: "##{ticket.id}")])
    assert_response :success
    assert_equal ticket.id, Issue.find(RubylodeAgenda::Line.find(@plain["id"]).issue_id).parent_id
  end

  test "one invalid row makes nothing and the review comes back with that row marked and the values kept" do
    rows = [row_params(@parent, subject: "Kept subject"), row_params(@plain, subject: "")]
    assert_no_difference "Issue.count" do
      create_rows(rows)
    end
    assert_response :unprocessable_entity
    review_html = Nokogiri::HTML5.fragment(json_response["review_html"])
    failing = review_html.at_css("tr[data-review-line-id='#{@plain["id"]}']")
    assert_includes failing["class"], "rubylode-agenda-review-failed"
    assert_includes failing.next_element.text, "Subject"
    assert_equal "Kept subject", review_html.at_css("tr[data-review-line-id='#{@parent["id"]}'] input[name='rows[][subject]']")["value"]
    assert_nil RubylodeAgenda::Line.find(@parent["id"]).issue_id
  end

  test "a project the user may not add tickets to is refused and nothing is made" do
    forbidden = Project.where.not(id: Issue.allowed_target_projects(User.find(2)).select(:id)).order(:id).first
    assert_no_difference "Issue.count" do
      create_rows([row_params(@parent), row_params(@plain, project_id: forbidden.id)])
    end
    assert_response :unprocessable_entity
    review_html = Nokogiri::HTML5.fragment(json_response["review_html"])
    assert_includes review_html.at_css("tr[data-review-line-id='#{@plain["id"]}']")["class"], "rubylode-agenda-review-failed"
  end

  test "a line that got a ticket in the meantime is refused on its row" do
    ticket = Issue.generate!(project_id: 1, subject: "Made elsewhere")
    stale = row_params(@plain)
    RubylodeAgenda::Line.find(@plain["id"]).update!(issue_id: ticket.id)
    assert_no_difference "Issue.count" do
      create_rows([row_params(@parent), stale])
    end
    assert_response :unprocessable_entity
    review_html = Nokogiri::HTML5.fragment(json_response["review_html"])
    failing = review_html.at_css("tr[data-review-line-id='#{@plain["id"]}']")
    assert_includes failing.next_element.text, "already has a ticket"
    assert_equal ticket.id, RubylodeAgenda::Line.find(@plain["id"]).issue_id
  end

  test "a parent line that is not in the batch above the row is refused" do
    assert_no_difference "Issue.count" do
      create_rows([row_params(@child, parent: "line 1.a")])
    end
    assert_response :unprocessable_entity
  end

  test "more than 50 rows are refused" do
    rows = Array.new(51) { row_params(@plain) }
    assert_no_difference "Issue.count" do
      create_rows(rows)
    end
    assert_response :unprocessable_entity
  end

  test "a reader and a user without add issues are refused" do
    Role.find(1).remove_permission!(:add_issues)
    Role.find(2).remove_permission!(:add_issues)
    Role.non_member.remove_permission!(:add_issues)
    Role.anonymous.remove_permission!(:add_issues)
    Member.where(user_id: 2).where.not(project_id: 1).destroy_all
    review(@plain)
    assert_response :forbidden
    assert_no_difference "Issue.count" do
      create_rows([row_params(@plain)])
    end
    assert_response :forbidden
    Role.find(1).add_permission!(:add_issues)
    log_in_as_reader
    review(@plain)
    assert_response :forbidden
    create_rows([row_params(@plain)])
    assert_response :forbidden
    get agendas_path("/#{@agenda.id}/tickets/choices"), params: { target_project_id: 1 }
    assert_response :forbidden
  end

  # ---- the page

  test "the header offers Make tickets to someone who may edit and add tickets" do
    get agenda_path
    assert_select ".rubylode-agenda-actions button[data-action~='click->rubylode-agenda#startSelecting']"
    assert_select "[data-rubylode-agenda-target=selectionBar][hidden]"
    assert_select "dialog.rubylode-agenda-review-dialog"
    assert_select "li[data-line-id='#{@plain["id"]}'][data-selectable=true]"
    log_in_as_reader
    get agenda_path
    assert_select "button[data-action~='click->rubylode-agenda#startSelecting']", count: 0
  end

  test "the menus offer selecting for tickets" do
    get agenda_path
    actions = css_select(".rubylode-agenda-menu [role=menuitem]").map { |entry| entry["data-menu-action"] }
    assert_includes actions, "select-for-tickets"
    assert_includes actions, "topic-tickets"
  end
end
