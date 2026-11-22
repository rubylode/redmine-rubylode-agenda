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

class RubylodeAgendaAgendasTest < RubylodeAgendaIntegrationTest
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
    post agendas_path("")
    assert_response :forbidden
    assert_equal 0, RubylodeAgenda::Agenda.count
  end

  test "a project without agendas offers to start the first one" do
    get agenda_path
    assert_response :success
    assert_select "input[type=submit][value=?]", "Start the first meeting"
  end

  test "a reader of an empty agenda is not offered the start button" do
    log_in_as_reader
    get agenda_path
    assert_select "input[type=submit]", count: 0
  end

  test "starting the first agenda holds it today with a period of seven days" do
    travel_to Time.zone.local(2026, 11, 21, 10, 0) do
      post agendas_path("")
      assert_response :redirect
      agenda = RubylodeAgenda::Agenda.last
      assert_equal Date.new(2026, 11, 21), agenda.held_on
      assert_equal Date.new(2026, 11, 14), agenda.period_start
      assert_equal Date.new(2026, 11, 21), agenda.period_end
      assert_nil agenda.closed_at
      assert_equal 1, agenda.project_id
    end
  end

  test "starting the next agenda closes the open one and starts the period at its date" do
    travel_to(Time.zone.local(2026, 11, 21, 10, 0)) { post agendas_path("") }
    travel_to Time.zone.local(2026, 11, 28, 9, 0) do
      post agendas_path("")
      first, second = RubylodeAgenda::Agenda.order(:id).to_a
      assert_equal Time.zone.local(2026, 11, 28, 9, 0), first.closed_at
      assert_equal 2, first.closed_by_id
      assert_equal Date.new(2026, 11, 21), second.period_start
      assert_equal Date.new(2026, 11, 28), second.period_end
      assert_nil second.closed_at
    end
  end

  test "a missed week makes a two week period" do
    travel_to(Time.zone.local(2026, 11, 21, 10, 0)) { post agendas_path("") }
    travel_to Time.zone.local(2026, 12, 5, 9, 0) do
      post agendas_path("")
      assert_equal Date.new(2026, 11, 21), RubylodeAgenda::Agenda.order(:id).last.period_start
    end
  end

  test "the page shows the open agenda with its period and the dated switcher" do
    travel_to(Time.zone.local(2026, 11, 21, 10, 0)) { post agendas_path("") }
    travel_to(Time.zone.local(2026, 11, 28, 10, 0)) { post agendas_path("") }
    get agenda_path
    assert_response :success
    assert_select "select.rubylode-agenda-switcher option", count: 2
    assert_select "select.rubylode-agenda-switcher option[selected]", text: /11\/28\/2026/
    assert_select ".rubylode-agenda-period", text: /11\/21\/2026.*11\/28\/2026/m
    assert_select "aside.rubylode-agenda-sidebar"
  end

  test "an older agenda can be opened by its id and another project's cannot" do
    first = nil
    travel_to(Time.zone.local(2026, 11, 21, 10, 0)) { first = start_agenda }
    travel_to(Time.zone.local(2026, 11, 28, 10, 0)) { post agendas_path("") }
    get agendas_path("/#{first.id}")
    assert_response :success
    assert_select "select.rubylode-agenda-switcher option[selected]", text: /11\/21\/2026/
    get agendas_path("/#{first.id}", project: Project.find(3))
    assert_response :forbidden
    @project = Project.find(3)
    @project.enable_module!(:rubylode_agenda)
    Role.find(1).add_permission!(:view_rubylode_agenda)
    Member.where(project_id: 3, user_id: 2).first_or_create!(role_ids: [1])
    get agendas_path("/#{first.id}", project: Project.find(3))
    assert_response :not_found
  end

  test "the date and the period of an open agenda can be changed" do
    agenda = start_agenda
    patch agendas_path("/#{agenda.id}"),
          params: { held_on: "2026-12-01", period_start: "2026-11-20", period_end: "2026-12-01" }
    assert_response :redirect
    agenda.reload
    assert_equal Date.new(2026, 12, 1), agenda.held_on
    assert_equal Date.new(2026, 11, 20), agenda.period_start
    assert_equal Date.new(2026, 12, 1), agenda.period_end
  end

  test "a period that ends before it starts is refused" do
    agenda = start_agenda
    before = [agenda.period_start, agenda.period_end]
    patch agendas_path("/#{agenda.id}"), params: { period_start: "2026-12-05", period_end: "2026-12-01" }
    assert_equal before, agenda.reload.then { |stored| [stored.period_start, stored.period_end] }
    assert_response :redirect
    follow_redirect!
    assert_select "#flash_error"
  end

  test "the date of a closed agenda can change" do
    agenda = nil
    travel_to(Time.zone.local(2026, 11, 21, 10, 0)) { agenda = start_agenda }
    post agendas_path("/#{agenda.id}/close")
    patch agendas_path("/#{agenda.id}"), params: { held_on: "2026-11-22" }
    agenda.reload
    assert_equal Date.new(2026, 11, 22), agenda.held_on
    assert_equal Date.new(2026, 11, 14), agenda.period_start
    assert_equal Date.new(2026, 11, 21), agenda.period_end
  end

  test "a request to change the period of a closed agenda is refused and stores nothing" do
    agenda = nil
    travel_to(Time.zone.local(2026, 11, 21, 10, 0)) { agenda = start_agenda }
    post agendas_path("/#{agenda.id}/close")
    patch agendas_path("/#{agenda.id}"),
          params: { held_on: "2026-11-22", period_start: "2026-01-01", period_end: "2026-01-02" }
    assert_response :redirect
    follow_redirect!
    assert_select "#flash_error", text: /period of a closed meeting cannot be changed/
    agenda.reload
    assert_equal Date.new(2026, 11, 21), agenda.held_on
    assert_equal Date.new(2026, 11, 14), agenda.period_start
    assert_equal Date.new(2026, 11, 21), agenda.period_end
  end

  test "closing an agenda stamps the time and the person" do
    agenda = start_agenda
    travel_to Time.zone.local(2026, 11, 22, 18, 30) do
      post agendas_path("/#{agenda.id}/close")
    end
    assert_response :redirect
    agenda.reload
    assert_equal Time.zone.local(2026, 11, 22, 18, 30), agenda.closed_at
    assert_equal 2, agenda.closed_by_id
  end

  test "a reader cannot close or change an agenda" do
    agenda = start_agenda
    log_in_as_reader
    post agendas_path("/#{agenda.id}/close")
    assert_response :forbidden
    patch agendas_path("/#{agenda.id}"), params: { held_on: "2026-12-01" }
    assert_response :forbidden
    assert_nil agenda.reload.closed_at
  end

  test "starting the next agenda carries unfinished notes and skips finished topics" do
    agenda = start_agenda
    open_topic = add_topic(agenda, "Release", owner_id: 3)
    add_line(open_topic, "Write the changelog")
    finished_line = add_line(open_topic, "Tag the build")
    removed_line = add_line(open_topic, "Cancelled idea")
    finished_topic = add_topic(agenda, "Hiring")
    only_done = add_line(finished_topic, "Post the job")
    patch agenda_path("/lines/#{finished_line["id"]}"), params: { done: "1", lock_version: finished_line["lock_version"] }
    patch agenda_path("/lines/#{only_done["id"]}"), params: { done: "1", lock_version: only_done["lock_version"] }
    delete agenda_path("/lines/#{removed_line["id"]}")
    removed_topic = add_topic(agenda, "Dropped")
    add_line(removed_topic, "Never mind")
    delete agenda_path("/topics/#{removed_topic["id"]}")

    post agendas_path("")
    next_agenda = RubylodeAgenda::Agenda.order(:id).last
    topics = next_agenda.topics.order(:position).to_a
    assert_equal ["Release"], topics.map(&:title)
    assert_equal 3, topics.first.owner_id
    lines = topics.first.lines.order(:position).to_a
    assert_equal ["Write the changelog"], lines.map(&:text)
    assert_equal 1, lines.first.carried_count
    assert_equal open_topic["id"], lines.first.carried_from.topic_id
    assert_not lines.first.done
  end

  test "a line carried twice counts two" do
    agenda = start_agenda
    add_line(add_topic(agenda, "Release"), "Write the changelog")
    post agendas_path("")
    post agendas_path("")
    line = RubylodeAgenda::Line.joins(:agenda).where(rubylode_agenda_agendas: { project_id: 1 }).order(:id).last
    assert_equal "Write the changelog", line.text
    assert_equal 2, line.carried_count
    assert_equal 3, RubylodeAgenda::Agenda.count
  end

  test "the carried copy shows on the page" do
    agenda = start_agenda
    add_line(add_topic(agenda, "Release"), "Write the changelog")
    post agendas_path("")
    get agenda_path
    assert_select "li.rubylode-agenda-topic", count: 1
    assert_select "textarea[data-field=line-text]", text: "Write the changelog", count: 1
  end

  test "a line whose ticket is open is carried with its ticket, a line whose ticket is closed is not" do
    open_issue = Issue.generate!(project_id: 1, subject: "Still open")
    closed_issue = Issue.generate!(project_id: 1, subject: "Finished")
    closed_issue.update_column(:status_id, 5)
    agenda = start_agenda
    topic = add_topic(agenda, "Release")
    open_line = add_line(topic, "##{open_issue.id}")
    add_line(topic, "##{closed_issue.id}")
    add_line(topic, "A plain note")
    patch agenda_path("/lines/#{open_line["id"]}"), params: { done: "1", lock_version: open_line["lock_version"] }
    assert_response :success

    post agendas_path("")
    carried = RubylodeAgenda::Agenda.order(:id).last.lines.order(:position).to_a
    assert_equal ["Still open", "A plain note"], carried.map(&:text)
    assert_equal [open_issue.id, nil], carried.map(&:issue_id)
    assert_equal [1, 1], carried.map(&:carried_count)
  end

  test "a parked line is not carried" do
    agenda = start_agenda
    topic = add_topic(agenda, "Release")
    parked = add_line(topic, "Parked for later")
    add_line(topic, "Kept")
    post agenda_path("/lines/#{parked["id"]}/park")
    assert_response :success

    post agendas_path("")
    assert_equal ["Kept"], RubylodeAgenda::Agenda.order(:id).last.lines.map(&:text)
  end
  test "starting twice in a row leaves exactly one open agenda" do
    post agendas_path("")
    post agendas_path("")
    assert_equal 2, RubylodeAgenda::Agenda.count
    assert_equal 1, RubylodeAgenda::Agenda.where(closed_at: nil).count
  end

  test "the start and close buttons disable themselves on submit" do
    post agendas_path("")
    get agenda_path
    assert_select "form[action$='/agendas'] input[type=submit][data-disable-with='Start next meeting']"
    assert_select "form[action$='/close'] input[type=submit][data-disable-with='Close meeting']"
  end
  test "closing an agenda twice keeps the first close" do
    agenda = start_agenda
    travel_to(Time.zone.local(2026, 11, 22, 18, 30)) { post agendas_path("/#{agenda.id}/close") }
    Role.find(2).add_permission!(:manage_rubylode_agenda)
    log_in_as_reader
    travel_to(Time.zone.local(2026, 11, 23, 9, 0)) { post agendas_path("/#{agenda.id}/close") }
    agenda.reload
    assert_equal Time.zone.local(2026, 11, 22, 18, 30), agenda.closed_at
    assert_equal 2, agenda.closed_by_id
  end
  test "a project whose identifier starts with a number is found by its identifier, not by that number" do
    numeric_looking = Project.create!(name: "Numeric looking", identifier: "2-agenda")
    numeric_looking.enable_module!(:rubylode_agenda)
    Member.create!(project: numeric_looking, user_id: 2, role_ids: [1])
    get agenda_path(project: numeric_looking)
    assert_response :success
    post agendas_path("", project: numeric_looking)
    assert_equal [numeric_looking.id], RubylodeAgenda::Agenda.pluck(:project_id)
  end
end
