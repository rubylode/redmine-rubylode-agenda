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

class RubylodeAgendaMeetingsTest < RubylodeAgendaIntegrationTest
  fixtures :trackers, :projects_trackers, :issue_statuses, :issues, :enumerations, :custom_fields, :custom_values,
           :custom_fields_trackers, :workflows

  test "with the module off the page is refused" do
    @project.disable_module!(:rubylode_agenda)
    get agenda_path
    assert_response :forbidden
  end

  test "the project menu has an Agenda tab after the roadmap" do
    get "/projects/ecookbook"
    assert_select "#main-menu a.rubylode-agenda", text: "Agenda"
  end

  test "a reader can see the page but cannot write" do
    log_in_as_reader
    get agenda_path
    assert_response :success
    post agenda_path("/meetings")
    assert_response :forbidden
    assert_equal 0, RubylodeAgenda::Meeting.count
  end

  test "a project without meetings offers to start the first one" do
    get agenda_path
    assert_response :success
    assert_select "input[type=submit][value=?]", "Start the first meeting"
  end

  test "a reader of an empty agenda is not offered the start button" do
    log_in_as_reader
    get agenda_path
    assert_select "input[type=submit]", count: 0
  end

  test "starting the first meeting holds it today with a period of seven days" do
    travel_to Time.zone.local(2026, 11, 21, 10, 0) do
      post agenda_path("/meetings")
      assert_response :redirect
      meeting = RubylodeAgenda::Meeting.last
      assert_equal Date.new(2026, 11, 21), meeting.held_on
      assert_equal Date.new(2026, 11, 14), meeting.period_start
      assert_equal Date.new(2026, 11, 21), meeting.period_end
      assert_nil meeting.closed_at
      assert_equal 1, meeting.project_id
    end
  end

  test "starting the next meeting closes the open one and starts the period at its date" do
    travel_to(Time.zone.local(2026, 11, 21, 10, 0)) { post agenda_path("/meetings") }
    travel_to Time.zone.local(2026, 11, 28, 9, 0) do
      post agenda_path("/meetings")
      first, second = RubylodeAgenda::Meeting.order(:id).to_a
      assert_equal Time.zone.local(2026, 11, 28, 9, 0), first.closed_at
      assert_equal 2, first.closed_by_id
      assert_equal Date.new(2026, 11, 21), second.period_start
      assert_equal Date.new(2026, 11, 28), second.period_end
      assert_nil second.closed_at
    end
  end

  test "a missed week makes a two week period" do
    travel_to(Time.zone.local(2026, 11, 21, 10, 0)) { post agenda_path("/meetings") }
    travel_to Time.zone.local(2026, 12, 5, 9, 0) do
      post agenda_path("/meetings")
      assert_equal Date.new(2026, 11, 21), RubylodeAgenda::Meeting.order(:id).last.period_start
    end
  end

  test "the page shows the open meeting with its period and the dated switcher" do
    travel_to(Time.zone.local(2026, 11, 21, 10, 0)) { post agenda_path("/meetings") }
    travel_to(Time.zone.local(2026, 11, 28, 10, 0)) { post agenda_path("/meetings") }
    get agenda_path
    assert_response :success
    assert_select "select.rubylode-agenda-switcher option", count: 2
    assert_select "select.rubylode-agenda-switcher option[selected]", text: /11\/28\/2026/
    assert_select ".rubylode-agenda-period", text: /11\/21\/2026.*11\/28\/2026/m
    assert_select "aside.rubylode-agenda-sidebar"
  end

  test "an older meeting can be opened by its id and another project's cannot" do
    first = nil
    travel_to(Time.zone.local(2026, 11, 21, 10, 0)) { first = start_meeting }
    travel_to(Time.zone.local(2026, 11, 28, 10, 0)) { post agenda_path("/meetings") }
    get agenda_path("/meetings/#{first.id}")
    assert_response :success
    assert_select "select.rubylode-agenda-switcher option[selected]", text: /11\/21\/2026/
    get agenda_path("/meetings/#{first.id}", project: Project.find(3))
    assert_response :forbidden
    @project = Project.find(3)
    @project.enable_module!(:rubylode_agenda)
    Role.find(1).add_permission!(:view_rubylode_agenda)
    Member.where(project_id: 3, user_id: 2).first_or_create!(role_ids: [1])
    get agenda_path("/meetings/#{first.id}", project: Project.find(3))
    assert_response :not_found
  end

  test "the date and the period of an open meeting can be changed" do
    meeting = start_meeting
    patch agenda_path("/meetings/#{meeting.id}"),
          params: { held_on: "2026-12-01", period_start: "2026-11-20", period_end: "2026-12-01" }
    assert_response :redirect
    meeting.reload
    assert_equal Date.new(2026, 12, 1), meeting.held_on
    assert_equal Date.new(2026, 11, 20), meeting.period_start
    assert_equal Date.new(2026, 12, 1), meeting.period_end
  end

  test "a period that ends before it starts is refused" do
    meeting = start_meeting
    before = [meeting.period_start, meeting.period_end]
    patch agenda_path("/meetings/#{meeting.id}"), params: { period_start: "2026-12-05", period_end: "2026-12-01" }
    assert_equal before, meeting.reload.then { |stored| [stored.period_start, stored.period_end] }
    assert_response :redirect
    follow_redirect!
    assert_select "#flash_error"
  end

  test "the date of a closed meeting can change" do
    meeting = nil
    travel_to(Time.zone.local(2026, 11, 21, 10, 0)) { meeting = start_meeting }
    post agenda_path("/meetings/#{meeting.id}/close")
    patch agenda_path("/meetings/#{meeting.id}"), params: { held_on: "2026-11-22" }
    meeting.reload
    assert_equal Date.new(2026, 11, 22), meeting.held_on
    assert_equal Date.new(2026, 11, 14), meeting.period_start
    assert_equal Date.new(2026, 11, 21), meeting.period_end
  end

  test "a request to change the period of a closed meeting is refused and stores nothing" do
    meeting = nil
    travel_to(Time.zone.local(2026, 11, 21, 10, 0)) { meeting = start_meeting }
    post agenda_path("/meetings/#{meeting.id}/close")
    patch agenda_path("/meetings/#{meeting.id}"),
          params: { held_on: "2026-11-22", period_start: "2026-01-01", period_end: "2026-01-02" }
    assert_response :redirect
    follow_redirect!
    assert_select "#flash_error", text: /period of a closed meeting cannot be changed/
    meeting.reload
    assert_equal Date.new(2026, 11, 21), meeting.held_on
    assert_equal Date.new(2026, 11, 14), meeting.period_start
    assert_equal Date.new(2026, 11, 21), meeting.period_end
  end

  test "closing a meeting stamps the time and the person" do
    meeting = start_meeting
    travel_to Time.zone.local(2026, 11, 22, 18, 30) do
      post agenda_path("/meetings/#{meeting.id}/close")
    end
    assert_response :redirect
    meeting.reload
    assert_equal Time.zone.local(2026, 11, 22, 18, 30), meeting.closed_at
    assert_equal 2, meeting.closed_by_id
  end

  test "a reader cannot close or change a meeting" do
    meeting = start_meeting
    log_in_as_reader
    post agenda_path("/meetings/#{meeting.id}/close")
    assert_response :forbidden
    patch agenda_path("/meetings/#{meeting.id}"), params: { held_on: "2026-12-01" }
    assert_response :forbidden
    assert_nil meeting.reload.closed_at
  end

  test "starting the next meeting carries unfinished notes and skips finished topics" do
    meeting = start_meeting
    open_topic = add_topic(meeting, "Release", owner_id: 3)
    add_line(open_topic, "Write the changelog")
    finished_line = add_line(open_topic, "Tag the build")
    removed_line = add_line(open_topic, "Cancelled idea")
    finished_topic = add_topic(meeting, "Hiring")
    only_done = add_line(finished_topic, "Post the job")
    patch agenda_path("/lines/#{finished_line["id"]}"), params: { done: "1", lock_version: finished_line["lock_version"] }
    patch agenda_path("/lines/#{only_done["id"]}"), params: { done: "1", lock_version: only_done["lock_version"] }
    delete agenda_path("/lines/#{removed_line["id"]}")
    removed_topic = add_topic(meeting, "Dropped")
    add_line(removed_topic, "Never mind")
    delete agenda_path("/topics/#{removed_topic["id"]}")

    post agenda_path("/meetings")
    next_meeting = RubylodeAgenda::Meeting.order(:id).last
    topics = next_meeting.topics.order(:position).to_a
    assert_equal ["Release"], topics.map(&:title)
    assert_equal 3, topics.first.owner_id
    lines = topics.first.lines.order(:position).to_a
    assert_equal ["Write the changelog"], lines.map(&:text)
    assert_equal 1, lines.first.carried_count
    assert_equal open_topic["id"], lines.first.carried_from.topic_id
    assert_not lines.first.done
  end

  test "a line carried twice counts two" do
    meeting = start_meeting
    add_line(add_topic(meeting, "Release"), "Write the changelog")
    post agenda_path("/meetings")
    post agenda_path("/meetings")
    line = RubylodeAgenda::Line.joins(:meeting).where(rubylode_agenda_meetings: { project_id: 1 }).order(:id).last
    assert_equal "Write the changelog", line.text
    assert_equal 2, line.carried_count
    assert_equal 3, RubylodeAgenda::Meeting.count
  end

  test "the carried copy shows on the page" do
    meeting = start_meeting
    add_line(add_topic(meeting, "Release"), "Write the changelog")
    post agenda_path("/meetings")
    get agenda_path
    assert_select "li.rubylode-agenda-topic", count: 1
    assert_select "textarea[data-field=line-text]", text: "Write the changelog", count: 1
  end

  test "a line whose ticket is open is carried with its ticket, a line whose ticket is closed is not" do
    open_issue = Issue.generate!(project_id: 1, subject: "Still open")
    closed_issue = Issue.generate!(project_id: 1, subject: "Finished")
    closed_issue.update_column(:status_id, 5)
    meeting = start_meeting
    topic = add_topic(meeting, "Release")
    open_line = add_line(topic, "##{open_issue.id}")
    add_line(topic, "##{closed_issue.id}")
    add_line(topic, "A plain note")
    patch agenda_path("/lines/#{open_line["id"]}"), params: { done: "1", lock_version: open_line["lock_version"] }
    assert_response :success

    post agenda_path("/meetings")
    carried = RubylodeAgenda::Meeting.order(:id).last.lines.order(:position).to_a
    assert_equal ["Still open", "A plain note"], carried.map(&:text)
    assert_equal [open_issue.id, nil], carried.map(&:issue_id)
    assert_equal [1, 1], carried.map(&:carried_count)
  end

  test "a parked line is not carried" do
    meeting = start_meeting
    topic = add_topic(meeting, "Release")
    parked = add_line(topic, "Parked for later")
    add_line(topic, "Kept")
    post agenda_path("/lines/#{parked["id"]}/park")
    assert_response :success

    post agenda_path("/meetings")
    assert_equal ["Kept"], RubylodeAgenda::Meeting.order(:id).last.lines.map(&:text)
  end
  test "starting twice in a row leaves exactly one open meeting" do
    post agenda_path("/meetings")
    post agenda_path("/meetings")
    assert_equal 2, RubylodeAgenda::Meeting.count
    assert_equal 1, RubylodeAgenda::Meeting.where(closed_at: nil).count
  end

  test "the start and close buttons disable themselves on submit" do
    post agenda_path("/meetings")
    get agenda_path
    assert_select "form[action$='/meetings'] input[type=submit][data-disable-with='Start next meeting']"
    assert_select "form[action$='/close'] input[type=submit][data-disable-with='Close meeting']"
  end
  test "closing a meeting twice keeps the first close" do
    meeting = start_meeting
    travel_to(Time.zone.local(2026, 11, 22, 18, 30)) { post agenda_path("/meetings/#{meeting.id}/close") }
    Role.find(2).add_permission!(:manage_rubylode_agenda)
    log_in_as_reader
    travel_to(Time.zone.local(2026, 11, 23, 9, 0)) { post agenda_path("/meetings/#{meeting.id}/close") }
    meeting.reload
    assert_equal Time.zone.local(2026, 11, 22, 18, 30), meeting.closed_at
    assert_equal 2, meeting.closed_by_id
  end
  test "a project whose identifier starts with a number is found by its identifier, not by that number" do
    numeric_looking = Project.create!(name: "Numeric looking", identifier: "2-agenda")
    numeric_looking.enable_module!(:rubylode_agenda)
    Member.create!(project: numeric_looking, user_id: 2, role_ids: [1])
    get agenda_path(project: numeric_looking)
    assert_response :success
    post agenda_path("/meetings", project: numeric_looking)
    assert_equal [numeric_looking.id], RubylodeAgenda::Meeting.pluck(:project_id)
  end
end
