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
# Colour that means something, decided on the server: the kind of a ticket's status, the age of a carried line, a line
# new this period, an overdue count above zero, and the owner's initials. The page renders classes, never colours.
class RubylodeAgendaColourTest < RubylodeAgendaIntegrationTest
  fixtures :trackers, :projects_trackers, :issue_statuses, :issues, :enumerations, :custom_fields, :custom_values,
           :custom_fields_trackers, :workflows

  def row_of(record)
    Nokogiri::HTML5.fragment(record["html"]).at_css("li")
  end

  test "a status is closed, the first open one, or by its rank among the other open ones" do
    kinds = IssueStatus.order(:position).to_h { |status| [status.name, RubylodeAgenda::StatusColour.kind_for(status)] }
    assert_equal({ "New" => :first, "Assigned" => :amber, "Resolved" => :purple, "Feedback" => :teal, "Closed" => :closed,
                   "Rejected" => :closed }, kinds.slice("New", "Assigned", "Resolved", "Feedback", "Closed", "Rejected"))
    fifth = IssueStatus.create!(name: "Waiting", is_closed: false)
    assert_equal :amber, RubylodeAgenda::StatusColour.kind_for(fifth)
  end

  test "a linked line shows its status as a pill of its kind" do
    agenda = start_agenda
    topic = add_topic(agenda, "Release")
    ticket = Issue.generate!(project_id: 1, subject: "Assigned one")
    ticket.update_column(:status_id, 2)
    record = add_line(topic, "##{ticket.id}")
    assert_not_nil row_of(record).at_css(".rubylode-agenda-ticket-status.rubylode-agenda-status-amber")
    ticket.update_column(:status_id, 5)
    get agenda_path
    assert_select ".rubylode-agenda-ticket-status.rubylode-agenda-status-closed", text: "Closed"
  end

  test "a carried line's chip warms with age at 3 and at 6" do
    kinds = [1, 2, 3, 5, 6, 9].to_h { |count| [count, RubylodeAgenda::CarriedAge.kind_for(count)] }
    assert_equal({ 1 => :fresh, 2 => :fresh, 3 => :warm, 5 => :warm, 6 => :old, 9 => :old }, kinds)
    agenda = start_agenda
    topic = add_topic(agenda, "Release")
    line = add_line(topic, "Carried a lot")
    RubylodeAgenda::Line.find(line["id"]).update_columns(carried_count: 6, carried_from_id: line["id"])
    get agenda_path
    assert_select ".rubylode-agenda-carried.rubylode-agenda-carried-old", text: "carried 6x"
  end

  test "a line made in this period is new, a carried one is not, and neither is one on an agenda of the past" do
    first = start_agenda
    old_topic = add_topic(first, "Release")
    add_line(old_topic, "Carried along")
    post agendas_path
    current = RubylodeAgenda::Agenda.order(:id).last
    topic = current.topics.first
    record = add_line({ "id" => topic.id }, "Brand new")
    assert_not_nil row_of(record).at_css(".rubylode-agenda-new"), "the envelope's row is new too"
    get agenda_path
    assert_select "li.rubylode-agenda-line", text: /Brand new/ do
      assert_select ".rubylode-agenda-new", text: "new"
      assert_select ".rubylode-agenda-carried", count: 0
    end
    carried = css_select("li.rubylode-agenda-line").find { |row| row.text.include?("Carried along") }
    assert_nil carried.at_css(".rubylode-agenda-new")
    assert_not_nil carried.at_css(".rubylode-agenda-carried")
    past = RubylodeAgenda::Agenda.create!(project_id: 1, held_on: Date.new(2026, 1, 9), period_start: Date.new(2026, 1, 2),
                                          period_end: Date.new(2026, 1, 9), closed_at: Time.utc(2026, 1, 9, 18))
    past_topic = RubylodeAgenda::Topic.create!(agenda: past, title: "Old")
    RubylodeAgenda::Line.create!(agenda: past, topic: past_topic, text: "Written today on an old agenda")
    get agendas_path("/#{past.id}")
    assert_select ".rubylode-agenda-new", count: 0
  end

  test "the overdue tile is marked only when something is overdue" do
    start_agenda
    Issue.where(project_id: 1).update_all(due_date: nil)
    get agenda_path
    assert_select ".rubylode-agenda-number[data-kpi=overdue].rubylode-agenda-number-alert", count: 0
    Issue.generate!(project_id: 1, subject: "Late", due_date: Date.current - 3)
    get agenda_path
    assert_select ".rubylode-agenda-number[data-kpi=overdue].rubylode-agenda-number-alert", count: 1
  end

  test "an owner shows as an initials chip, for editors and readers, and no owner shows none" do
    agenda = start_agenda
    add_topic(agenda, "Owned", owner_id: 3)
    add_topic(agenda, "Nobody's")
    get agenda_path
    assert_equal %w[DL], css_select(".rubylode-agenda-owner-chip:not([hidden])").map { |chip| chip.text.strip }
    log_in_as_reader
    get agenda_path
    assert_equal %w[DL], css_select(".rubylode-agenda-owner-chip:not([hidden])").map { |chip| chip.text.strip }
  end

  test "initials take the first letters of the first two words, or the first two letters of one" do
    assert_equal "AR", RubylodeAgenda::Initials.for("Alex Rivers")
    assert_equal "AD", RubylodeAgenda::Initials.for("admin")
    assert_equal "JM", RubylodeAgenda::Initials.for("Jean-Paul  Marat Smith")
    assert_equal "", RubylodeAgenda::Initials.for(nil)
  end

  test "the no-category row of the breakdown keeps the plain bar" do
    project = Project.find(2)
    project.enable_module!(:rubylode_agenda)
    @project = project
    agenda = RubylodeAgenda::Agenda.create!(project_id: 2, held_on: Date.current, period_start: Date.current - 7, period_end: Date.current)
    ticket = Issue.generate!(project_id: 2, subject: "Closed without category")
    ticket.update_columns(status_id: 5, closed_on: Time.current, category_id: nil)
    get agendas_path("/#{agenda.id}", project: project)
    assert_select ".rubylode-agenda-breakdown-row.rubylode-agenda-breakdown-plain"
  end
end
