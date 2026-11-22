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

# The topic rail: one link per topic with its number, its title and its lines as "active + quiet", and the project's
# links under it.
class RubylodeAgendaRailTest < RubylodeAgendaIntegrationTest
  fixtures :trackers, :projects_trackers, :issue_statuses, :issues, :enumerations, :custom_fields, :custom_values,
           :custom_fields_trackers, :workflows

  def rail_entries
    css_select("nav.rubylode-agenda-rail a.rubylode-agenda-rail-link").map do |link|
      [link.at_css(".rubylode-agenda-rail-number").text.strip, link.at_css(".rubylode-agenda-rail-title").text.strip,
       link.at_css(".rubylode-agenda-rail-count").text.strip]
    end
  end

  # Two notes carried and quiet, one carried with an edit, and one new line: "2 +2 carried" for Release; Budget has one.
  def agenda_with_folded_lines
    first = start_agenda
    release = add_topic(first, "Release")
    add_line(release, "Quiet one")
    add_line(release, "Quiet two")
    add_line(release, "Edited later")
    post agendas_path("")
    agenda = RubylodeAgenda::Agenda.order(:id).last
    topic = agenda.topics.first
    edited = topic.lines.find_by(text: "Edited later")
    patch agenda_path("/lines/#{edited.id}"), params: { text: "Edited now", lock_version: edited.lock_version }
    add_line({ "id" => topic.id }, "Brand new")
    budget = add_topic(agenda, "Budget")
    add_line(budget, "Only line")
    agenda
  end

  test "the rail counts the active and the quiet lines of each topic, in topic order" do
    agenda_with_folded_lines
    get agenda_path
    assert_equal [["1.", "Release", "2 +2 carried"], ["2.", "Budget", "1"]], rail_entries
    assert_select "nav.rubylode-agenda-rail .rubylode-agenda-rail-legend", count: 0
    assert_select "nav.rubylode-agenda-rail .rubylode-agenda-rail-count .rubylode-agenda-rail-carried", text: "+2 carried", count: 1
    labels = css_select("nav.rubylode-agenda-rail a.rubylode-agenda-rail-link").map { |link| link["aria-label"] }
    assert_equal ["1. Release, 2 active lines, 2 carried lines with no change", "2. Budget, 1 active line"], labels
  end

  test "a topic with only carried lines shows 0 and the carried count" do
    first = start_agenda
    topic = add_topic(first, "Quiet only")
    add_line(topic, "Carried and untouched")
    post agendas_path
    get agenda_path
    assert_equal [["1.", "Quiet only", "0 +1 carried"]], rail_entries
    assert_equal "1. Quiet only, 0 active lines, 1 carried line with no change",
                 css_select("nav.rubylode-agenda-rail a.rubylode-agenda-rail-link").first["aria-label"]
  end

  test "rail links point at the topic sections" do
    agenda = agenda_with_folded_lines
    get agenda_path
    agenda.topics.active.each do |topic|
      assert_select "nav.rubylode-agenda-rail a[href='#rubylode-agenda-topic-#{topic.id}'][data-rail-topic-id='#{topic.id}']"
      assert_select "li.rubylode-agenda-topic#rubylode-agenda-topic-#{topic.id}"
    end
  end

  test "deleted topics and deleted or parked lines are not counted" do
    agenda = start_agenda
    kept = add_topic(agenda, "Kept")
    add_line(kept, "Counted")
    gone = add_line(kept, "Deleted")
    parked = add_line(kept, "Parked")
    delete agenda_path("/lines/#{gone["id"]}")
    post agenda_path("/lines/#{parked["id"]}/park")
    dropped = add_topic(agenda, "Dropped")
    delete agenda_path("/topics/#{dropped["id"]}")
    get agenda_path
    assert_equal [["1.", "Kept", "1"]], rail_entries
  end

  test "the counts are worked out in one place on the server" do
    agenda = agenda_with_folded_lines
    entries = RubylodeAgenda::TopicRail.new(agenda.topics.active.in_order).entries
    assert_equal [[1, "Release", 2, 2], [2, "Budget", 1, 0]],
                 entries.map { |entry| [entry.number, entry.topic.title, entry.active_count, entry.quiet_count] }
  end

  test "under the topics the rail holds the parked list and the project's links, each once" do
    patch agenda_path("/settings"), params: { kpi_url: "https://sheets.example.com/kpi", progress_url: "https://example.com/progress" }
    agenda = start_agenda
    topic = add_topic(agenda, "Release")
    parked = add_line(topic, "Parked")
    post agenda_path("/lines/#{parked["id"]}/park")
    get agenda_path
    assert_select "nav.rubylode-agenda-rail a.rubylode-agenda-rail-parked[href='#rubylode-agenda-parked']", text: "Parked (1)"
    assert_select "details.rubylode-agenda-parked#rubylode-agenda-parked"
    assert_select "nav.rubylode-agenda-rail a.rubylode-agenda-link[href='https://sheets.example.com/kpi']", count: 1
    assert_select "a.rubylode-agenda-link[href='https://sheets.example.com/kpi']", count: 1
    assert_select "nav.rubylode-agenda-rail a.rubylode-agenda-settings-link", count: 1
    assert_select "a.rubylode-agenda-settings-link", count: 1
  end

  test "the parked entry is left out when nothing is parked" do
    agenda = start_agenda
    add_topic(agenda, "Release")
    get agenda_path
    assert_select "nav.rubylode-agenda-rail li[hidden] .rubylode-agenda-rail-parked", count: 1
  end

  test "a reader gets the rail too, without the settings link" do
    agenda_with_folded_lines
    log_in_as_reader
    get agenda_path
    assert_equal [["1.", "Release", "2 +2 carried"], ["2.", "Budget", "1"]], rail_entries
    assert_select "nav.rubylode-agenda-rail a.rubylode-agenda-settings-link", count: 0
  end

  test "without an agenda there is no rail" do
    get agenda_path
    assert_select "nav.rubylode-agenda-rail", count: 0
  end

  test "the header names the agenda and says open" do
    agenda = start_agenda
    get agenda_path
    assert_select ".rubylode-agenda-header h2", text: "Meeting of #{agenda.held_on.strftime("%m/%d/%Y")}"
    assert_select ".rubylode-agenda-header .rubylode-agenda-open-pill", text: "open"
    post agendas_path("/#{agenda.id}/close")
    get agenda_path
    assert_select ".rubylode-agenda-header .rubylode-agenda-open-pill", count: 0
    assert_select ".rubylode-agenda-header .rubylode-agenda-closed", text: /Closed on/
  end
end
