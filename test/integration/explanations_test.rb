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
require_relative "../support/sidebar_helpers"

# Every button and number of the page explains itself: the plugin's own tooltip (data-tooltip), and the same words for
# screen readers (aria-description). Never a title, which Redmine turns into a tooltip that sticks on moving rows.
class RubylodeAgendaExplanationsTest < RubylodeAgendaSidebarTest
  NOW = Time.utc(2026, 11, 21, 12, 0)

  def setup
    super
    Role.find(1).add_permission!(:add_issues, :view_issues)
    @agenda = create_agenda(held_on: Date.new(2026, 11, 21), period_start: Date.new(2026, 11, 14), period_end: Date.new(2026, 11, 21))
  end

  def tip(selector)
    element = css_select(selector).first
    assert element, "#{selector} is on the page"
    assert_equal element["data-tooltip"], element["aria-description"] || element.at_css("[aria-description]")&.[]("aria-description")
    element["data-tooltip"]
  end

  def tile_tip(key)
    tip(".rubylode-agenda-number[data-kpi=#{key}]")
  end

  test "the header buttons say what they do" do
    travel_to(NOW) { get agenda_path }
    start_next = tip("form.rubylode-agenda-tip[data-tooltip*='Closes the open meeting']")
    assert_includes start_next, "Lines that are not done, and lines with an open ticket, move to the new meeting"
    close = tip("form.rubylode-agenda-tip[data-tooltip*='Ends the meeting and freezes its numbers']")
    assert_includes close, "so later ticket changes do not alter them"
    assert_includes close, "Topics and lines can still be edited."
    assert_includes close, "Start next meeting does this too and opens the next one."
    assert_includes tip("button[data-action~='click->rubylode-agenda#startSelecting']"), "Nothing is created until you confirm"
    assert_includes tip(".rubylode-agenda-dates > summary"), "the days the numbers cover"
  end

  # A tooltip that only repeats what the control already says is not there at all.
  test "controls whose label says it all have no tooltip" do
    travel_to NOW do
      topic = add_topic(@agenda, "Release")
      add_line(topic, "Write the changelog")
      12.times { |index| build_ticket(subject: "Closed #{index}", closed: true, closed_on: Time.utc(2026, 11, 18, 10)) }
      get agenda_path
    end
    ["label.rubylode-agenda-switcher-label", "select.rubylode-agenda-switcher", ".rubylode-agenda-dates [type=submit]",
     "li.rubylode-agenda-line .rubylode-agenda-menu-button", "li.rubylode-agenda-line .rubylode-agenda-handle",
     ".rubylode-agenda-topic-header .rubylode-agenda-handle", ".rubylode-agenda-topic-header .rubylode-agenda-menu-button",
     ".rubylode-agenda-breakdown h4", "a.rubylode-agenda-closed-see-all", "details.rubylode-agenda-closed-more > summary",
     "[data-action~='click->rubylode-agenda#stopSelecting']", "[data-action~='click->rubylode-agenda#reviewSelection']",
     "nav.rubylode-agenda-rail a.rubylode-agenda-rail-link"].each do |selector|
      element = css_select(selector).first
      assert element, "#{selector} is on the page"
      assert_nil element["data-tooltip"], "#{selector} has no tooltip"
      assert_nil element["aria-description"], "#{selector} has no description"
    end
    assert_select ".rubylode-agenda-breakdown h4[tabindex]", count: 0
    css_select(".rubylode-agenda-number").each { |tile| assert_not_includes tile["data-tooltip"], "Click" }
  end

  test "Cancel in the forms under a line has no tooltip" do
    line = travel_to(NOW) { add_line(add_topic(@agenda, "Release"), "Write the changelog") }
    get agenda_path("/lines/#{line["id"]}/issue/new")
    cancel = css_select("button[data-action~='click->rubylode-agenda#closeTicketForm']").first
    assert_nil cancel["data-tooltip"]
    assert_nil css_select("[type=submit]").first["data-tooltip"]
  end

  test "the first meeting's button says nothing is carried over" do
    RubylodeAgenda::Agenda.delete_all
    get agenda_path
    assert_includes tip("form.rubylode-agenda-tip[data-tooltip*='first meeting']"), "It covers the last seven days."
  end

  test "an open agenda's tiles say what they count, over which days, and the overdue day" do
    travel_to(NOW) { get agenda_path }
    assert_includes tile_tip("closed"), "Tickets closed from 11/14/2026 to 11/21/2026"
    assert_includes tile_tip("closed"), "in this project and its subprojects"
    assert_includes tile_tip("opened"), "Tickets created from 11/14/2026 to 11/21/2026"
    assert_includes tile_tip("still_open"), "All open tickets"
    assert_includes tile_tip("average_days_to_close"), "Average days from created to closed, for the tickets in Closed"
    assert_includes tile_tip("overdue"), "that are past their due date"
    assert_includes tile_tip("overdue"), "compares with the previous meeting"
  end

  test "with a scope query the tiles name it" do
    query = IssueQuery.new(name: "Without the backlog", visibility: IssueQuery::VISIBILITY_PUBLIC, project: @project)
    query.user_id = 2
    query.save!
    RubylodeAgenda::ProjectSetting.for(@project).update!(query_id: query.id)
    travel_to(NOW) { get agenda_path }
    assert_includes tile_tip("closed"), "filtered by the query “Without the backlog”"
  end

  test "a closed agenda's tiles say the numbers are stored and the overdue day is the meeting's date" do
    travel_to(Time.utc(2026, 11, 21, 18)) { close_agenda(@agenda) }
    travel_to(Time.utc(2026, 12, 1, 9)) { get agendas_path("/#{@agenda.id}") }
    assert_includes tile_tip("overdue"), "that were past their due date on 11/21/2026"
    assert_includes tile_tip("closed"), "Saved when the meeting closed. The list shows the tickets as they are now."
    assert_includes tip(".rubylode-agenda-dates > summary"), "fixed for a closed meeting"
  end

  test "the done box explains itself, and no row control carries a title" do
    travel_to NOW do
      topic = add_topic(@agenda, "Release")
      add_line(topic, "Write the changelog")
      get agenda_path
    end
    assert_includes tip("li.rubylode-agenda-line .rubylode-agenda-done-tip"), "still moves to the next meeting if its ticket is open"
    controls = css_select(".rubylode-agenda-row-control, .rubylode-agenda-handle, .rubylode-agenda-menu-button, .rubylode-agenda-done-tip")
    assert_equal [], controls.select { |control| control["title"] }
  end

  test "a reader sees the tile explanations but none for controls they do not have" do
    travel_to NOW do
      topic = add_topic(@agenda, "Release")
      add_line(topic, "Write the changelog")
      log_in_as_reader
      get agenda_path
    end
    assert_includes tile_tip("closed"), "Tickets closed from"
    assert_select "form.rubylode-agenda-tip", count: 0
    assert_select ".rubylode-agenda-menu-button", count: 0
    assert_select ".rubylode-agenda-done-tip", count: 0
    assert_select "[data-tooltip*='Pick lines and turn them into tickets']", count: 0
  end
end
