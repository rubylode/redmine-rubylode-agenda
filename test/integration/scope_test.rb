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

require_relative "../support/sidebar_helpers"

class RubylodeAgendaScopeTest < RubylodeAgendaSidebarTest
  NOW = Time.utc(2026, 11, 21, 12, 0)

  def setup
    super
    @meeting = create_meeting(held_on: Date.new(2026, 11, 21), period_start: Date.new(2026, 11, 14), period_end: Date.new(2026, 11, 21))
  end

  def build_saved_query(name, filters, visibility: IssueQuery::VISIBILITY_PUBLIC, user_id: 2, project: nil)
    query = IssueQuery.new(name: name, visibility: visibility, project: project)
    query.user_id = user_id
    query.filters = filters
    query.save!
    query
  end

  test "the closed list holds a ticket closed inside the period and excludes the other cases" do
    travel_to NOW do
      inside = build_ticket(subject: "Closed inside", closed: true, closed_on: Time.utc(2026, 11, 18, 10))
      build_ticket(subject: "Closed before", closed: true, closed_on: Time.utc(2026, 11, 13, 23, 59, 59))
      build_ticket(subject: "Closed then reopened", closed: false, closed_on: Time.utc(2026, 11, 18, 10))
      build_ticket(subject: "Closed after", closed: true, closed_on: Time.utc(2026, 11, 22, 0, 0, 1))
      build_ticket(subject: "Other project", project: Project.find(2), closed: true, closed_on: Time.utc(2026, 11, 18, 10))
      get agenda_path
      assert_response :success
      assert_equal [inside.id], closed_issue_ids_in_sidebar
    end
  end

  test "both edges of the period are inside" do
    travel_to NOW do
      first = build_ticket(subject: "First instant", closed: true, closed_on: Time.utc(2026, 11, 14, 0, 0, 0))
      last = build_ticket(subject: "Last instant", closed: true, closed_on: Time.utc(2026, 11, 21, 23, 59, 59))
      get agenda_path
      assert_equal [last.id, first.id], closed_issue_ids_in_sidebar
    end
  end

  test "a ticket of a visible subproject is listed" do
    travel_to NOW do
      subproject = Project.find(3)
      subproject.enable_module!(:issue_tracking)
      ticket = build_ticket(project: subproject, subject: "In the subproject", closed: true, closed_on: Time.utc(2026, 11, 18, 10))
      get agenda_path
      assert_equal [ticket.id], closed_issue_ids_in_sidebar
    end
  end

  test "a private ticket the viewer may not see is not listed and not counted" do
    travel_to NOW do
      visible = build_ticket(subject: "Public", closed: true, closed_on: Time.utc(2026, 11, 18, 10))
      build_ticket(subject: "Secret", closed: true, closed_on: Time.utc(2026, 11, 18, 10), is_private: true)
      log_in_as_reader
      get agenda_path
      assert_equal [visible.id], closed_issue_ids_in_sidebar
      assert_equal "1", sidebar_number("closed")
    end
  end

  test "the saved query narrows the counts and the list" do
    travel_to NOW do
      mine = build_ticket(subject: "Assigned to the developer", closed: true, closed_on: Time.utc(2026, 11, 18, 10), assigned_to_id: 3)
      build_ticket(subject: "Assigned to someone else", closed: true, closed_on: Time.utc(2026, 11, 18, 10), assigned_to_id: 2)
      query = build_saved_query("Developer work", { "assigned_to_id" => { operator: "=", values: ["3"] } })
      patch agenda_path("/settings"), params: { query_id: query.id }
      assert_response :redirect
      get agenda_path
      assert_equal [mine.id], closed_issue_ids_in_sidebar
      assert_equal "1", sidebar_number("closed")
    end
  end

  test "the status filter of the saved query is left out, so closed tickets still count" do
    travel_to NOW do
      closed = build_ticket(subject: "Closed inside", closed: true, closed_on: Time.utc(2026, 11, 18, 10), assigned_to_id: 3)
      build_ticket(subject: "Open", assigned_to_id: 3)
      build_ticket(subject: "Open, someone else", assigned_to_id: 2)
      query = build_saved_query("Open developer work", { "status_id" => { operator: "o", values: [""] },
                                                         "assigned_to_id" => { operator: "=", values: ["3"] } })
      patch agenda_path("/settings"), params: { query_id: query.id }
      get agenda_path
      assert_equal [closed.id], closed_issue_ids_in_sidebar
      assert_equal "1", sidebar_number("closed")
      assert_equal "1", sidebar_number("still_open")
    end
  end

  test "a query the viewer may not see is ignored" do
    travel_to NOW do
      first = build_ticket(subject: "One", closed: true, closed_on: Time.utc(2026, 11, 18, 10), assigned_to_id: 3)
      second = build_ticket(subject: "Two", closed: true, closed_on: Time.utc(2026, 11, 17, 10), assigned_to_id: 2)
      query = build_saved_query("Private to the developer", { "assigned_to_id" => { operator: "=", values: ["3"] } },
                                visibility: IssueQuery::VISIBILITY_PRIVATE, user_id: 3)
      RubylodeAgenda::ProjectSetting.for(@project).update!(query_id: query.id)
      get agenda_path
      assert_equal [first.id, second.id], closed_issue_ids_in_sidebar
    end
  end

  test "a deleted query is ignored" do
    travel_to NOW do
      first = build_ticket(subject: "One", closed: true, closed_on: Time.utc(2026, 11, 18, 10), assigned_to_id: 3)
      second = build_ticket(subject: "Two", closed: true, closed_on: Time.utc(2026, 11, 17, 10), assigned_to_id: 2)
      query = build_saved_query("Developer work", { "assigned_to_id" => { operator: "=", values: ["3"] } })
      RubylodeAgenda::ProjectSetting.for(@project).update!(query_id: query.id)
      query.destroy
      get agenda_path
      assert_response :success
      assert_equal [first.id, second.id], closed_issue_ids_in_sidebar
    end
  end

  test "a query of another project is ignored" do
    travel_to NOW do
      first = build_ticket(subject: "One", closed: true, closed_on: Time.utc(2026, 11, 18, 10), assigned_to_id: 3)
      second = build_ticket(subject: "Two", closed: true, closed_on: Time.utc(2026, 11, 17, 10), assigned_to_id: 2)
      query = build_saved_query("Other project", { "assigned_to_id" => { operator: "=", values: ["3"] } }, project: Project.find(2))
      RubylodeAgenda::ProjectSetting.for(@project).update!(query_id: query.id)
      get agenda_path
      assert_equal [first.id, second.id], closed_issue_ids_in_sidebar
    end
  end

  test "the settings page offers the project's and the global queries and a blank Everything choice" do
    build_saved_query("Global one", { "assigned_to_id" => { operator: "=", values: ["3"] } })
    build_saved_query("Project one", { "assigned_to_id" => { operator: "=", values: ["3"] } }, project: @project)
    build_saved_query("Elsewhere", { "assigned_to_id" => { operator: "=", values: ["3"] } }, project: Project.find(2))
    build_saved_query("Hidden", { "assigned_to_id" => { operator: "=", values: ["3"] } }, visibility: IssueQuery::VISIBILITY_PRIVATE, user_id: 3)
    get agenda_path("/settings")
    assert_response :success
    assert_select "select[name=query_id] option[value='']", text: "Everything"
    assert_select "select[name=query_id] option", text: "Global one"
    assert_select "select[name=query_id] option", text: "Project one"
    assert_select "select[name=query_id] option", text: "Elsewhere", count: 0
    assert_select "select[name=query_id] option", text: "Hidden", count: 0
  end

  test "choosing Everything clears the query and a query the viewer cannot see is refused" do
    query = build_saved_query("Developer work", { "assigned_to_id" => { operator: "=", values: ["3"] } })
    patch agenda_path("/settings"), params: { query_id: query.id }
    assert_equal query.id, RubylodeAgenda::ProjectSetting.find_by!(project_id: 1).query_id
    patch agenda_path("/settings"), params: { query_id: "" }
    assert_nil RubylodeAgenda::ProjectSetting.find_by!(project_id: 1).query_id
    hidden = build_saved_query("Hidden", { "assigned_to_id" => { operator: "=", values: ["3"] } }, visibility: IssueQuery::VISIBILITY_PRIVATE, user_id: 3)
    patch agenda_path("/settings"), params: { query_id: hidden.id }
    assert_response :unprocessable_entity
    assert_nil RubylodeAgenda::ProjectSetting.find_by!(project_id: 1).query_id
  end

  test "the settings page says the query's status filter is not used" do
    get agenda_path("/settings")
    assert_select ".rubylode-agenda-hint", text: /status filter is not used/
  end
end
