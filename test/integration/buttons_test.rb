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

# One clear order of buttons: one primary action per place, secondary ones beside it.
class RubylodeAgendaButtonsTest < RubylodeAgendaIntegrationTest
  fixtures :trackers, :projects_trackers, :issue_statuses, :issues, :enumerations, :custom_fields, :custom_values,
           :custom_fields_trackers, :workflows

  PRIMARY = "rubylode-agenda-button-primary".freeze

  test "an open agenda's primary action is Close meeting; Start next and Make tickets are secondary" do
    Role.find(1).add_permission!(:add_issues)
    start_agenda
    get agenda_path
    assert_select ".rubylode-agenda-actions input[type=submit].rubylode-agenda-button.#{PRIMARY}[value='Close meeting']"
    assert_select ".rubylode-agenda-actions input[type=submit].rubylode-agenda-button[value='Start next meeting']:not(.#{PRIMARY})"
    assert_select ".rubylode-agenda-actions button.rubylode-agenda-button:not(.#{PRIMARY})", text: "Make tickets"
    assert_select ".rubylode-agenda-dates > summary.rubylode-agenda-button"
    assert_select ".rubylode-agenda-dates input[type=submit].#{PRIMARY}"
  end

  test "a closed agenda's primary action is Start next meeting" do
    agenda = start_agenda
    post agendas_path("/#{agenda.id}/close")
    get agenda_path
    assert_select ".rubylode-agenda-actions input[type=submit].#{PRIMARY}[value='Start next meeting']"
  end

  test "the first meeting's start button is primary" do
    get agenda_path
    assert_select "input[type=submit].rubylode-agenda-button.#{PRIMARY}[value='Start the first meeting']"
  end

  test "the forms under a line have one primary button and a secondary Cancel" do
    Role.find(1).add_permission!(:add_issues)
    agenda = start_agenda
    topic = add_topic(agenda, "Release")
    line = add_line(topic, "Write the changelog")
    get agenda_path("/lines/#{line["id"]}/issue/new")
    assert_select "input[type=submit].#{PRIMARY}", count: 1
    assert_select "button.rubylode-agenda-button:not(.#{PRIMARY})", text: /Cancel/
    get agendas_path("/#{agenda.id}/tickets/review"), params: { line_ids: [line["id"]] }
    assert_select "input[type=submit].#{PRIMARY}", count: 1
  end

  test "row controls are always in the page, not added on hover" do
    agenda = start_agenda
    topic = add_topic(agenda, "Release")
    add_line(topic, "Write the changelog")
    get agenda_path
    assert_select "li.rubylode-agenda-line .rubylode-agenda-row-control.rubylode-agenda-menu-button"
    assert_select "li.rubylode-agenda-line .rubylode-agenda-row-control.rubylode-agenda-handle"
  end
end
