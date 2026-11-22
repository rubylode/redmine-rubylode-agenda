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
    assert_includes start_next, "Lines that are not done and lines with an open ticket carry over"
    assert_includes start_next, "parked lines stay behind"
    close = tip("form.rubylode-agenda-tip[data-tooltip*='Stores the numbers as they are now']")
    assert_includes close, "Tickets are not changed."
    assert_includes close, "the period cannot"
    assert_includes tip("button[data-action~='click->rubylode-agenda#startSelecting']"), "Nothing is created until you confirm"
    assert_includes tip(".rubylode-agenda-dates > summary"), "The period is the days the numbers cover"
    assert_includes tip("label.rubylode-agenda-switcher-label"), "the numbers stored when it closed"
  end

  test "the first meeting's button says nothing is carried over" do
    RubylodeAgenda::Agenda.delete_all
    get agenda_path
    assert_includes tip("form.rubylode-agenda-tip[data-tooltip*='first meeting']"), "Nothing is carried over."
  end

  test "an open agenda's tiles say what they count, over which days, and the overdue day" do
    travel_to(NOW) { get agenda_path }
    assert_includes tile_tip("closed"), "Tickets closed from 11/14/2026 to 11/21/2026 that are still closed"
    assert_includes tile_tip("closed"), "in this project and its subprojects"
    assert_includes tile_tip("opened"), "Tickets created from 11/14/2026 to 11/21/2026"
    assert_includes tile_tip("still_open"), "Every open ticket"
    assert_includes tile_tip("average_days_to_close"), "Average days from creation to close for the tickets counted in Closed"
    assert_includes tile_tip("overdue"), "that were due before today"
    assert_includes tile_tip("overdue"), "compare with the previous meeting"
    assert_includes tile_tip("closed"), "Click to open them in the issue list."
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
    assert_includes tile_tip("overdue"), "that were due before the meeting's date, 11/21/2026"
    assert_includes tile_tip("closed"), "Stored when the meeting closed. The list shows the tickets as they are now."
    assert_includes tip(".rubylode-agenda-dates > summary"), "The period is fixed"
  end

  test "sections and row controls explain themselves, with the plugin's tooltip and no title" do
    travel_to NOW do
      topic = add_topic(@agenda, "Release")
      add_line(topic, "Write the changelog")
      get agenda_path
    end
    assert_includes tip(".rubylode-agenda-breakdown h4"), "The tickets counted in Closed, by"
    assert_includes tip("li.rubylode-agenda-line .rubylode-agenda-handle"), "Drag"
    assert_includes tip("li.rubylode-agenda-line .rubylode-agenda-menu-button"), "Actions for this line"
    assert_includes tip("li.rubylode-agenda-line .rubylode-agenda-done-tip"), "carries over only if its ticket is still open"
    assert_includes tip("nav.rubylode-agenda-rail a.rubylode-agenda-rail-link"), "Jumps to this topic"
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
    assert_select "[data-tooltip*='Tick lines that have no ticket']", count: 0
  end
end
