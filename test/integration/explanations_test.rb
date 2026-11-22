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
    assert_includes start_next, "Lines that are not done, and lines whose ticket is still open, are carried over"
    assert_includes start_next, "parked lines stay behind"
    close = tip("form.rubylode-agenda-tip[data-tooltip*='stores its numbers as you see them now']")
    assert_includes close, "Closing changes nothing in the tickets."
    assert_includes close, "the period cannot"
    assert_includes tip("button[data-action~='click->rubylode-agenda#startSelecting']"), "Nothing is created until you confirm"
    assert_includes tip(".rubylode-agenda-dates > summary"), "the period is the stretch of days the card counts over"
    assert_includes tip("label.rubylode-agenda-switcher-label"), "the numbers stored when it was closed"
  end

  test "the first meeting's button says nothing is carried over" do
    RubylodeAgenda::Agenda.delete_all
    get agenda_path
    assert_includes tip("form.rubylode-agenda-tip[data-tooltip*='first meeting']"), "Nothing is carried over."
  end

  test "an open agenda's tiles say what they count, over which days, and the overdue day" do
    travel_to(NOW) { get agenda_path }
    assert_includes tile_tip("closed"), "Tickets closed between 11/14/2026 and 11/21/2026 and still closed now"
    assert_includes tile_tip("closed"), "in this project and its subprojects"
    assert_includes tile_tip("opened"), "Tickets created between 11/14/2026 and 11/21/2026"
    assert_includes tile_tip("still_open"), "All open tickets"
    assert_includes tile_tip("average_days_to_close"), "Mean days from creation to close of the tickets counted in Closed"
    assert_includes tile_tip("overdue"), "whose due date is before today"
    assert_includes tile_tip("overdue"), "compares with the previous meeting"
    assert_includes tile_tip("closed"), "Click to see them in the issue list."
  end

  test "with a scope query the tiles name it" do
    query = IssueQuery.new(name: "Without the backlog", visibility: IssueQuery::VISIBILITY_PUBLIC, project: @project)
    query.user_id = 2
    query.save!
    RubylodeAgenda::ProjectSetting.for(@project).update!(query_id: query.id)
    travel_to(NOW) { get agenda_path }
    assert_includes tile_tip("closed"), "narrowed by the query “Without the backlog”"
  end

  test "a closed agenda's tiles say the numbers are stored and the overdue day is the meeting's date" do
    travel_to(Time.utc(2026, 11, 21, 18)) { close_agenda(@agenda) }
    travel_to(Time.utc(2026, 12, 1, 9)) { get agendas_path("/#{@agenda.id}") }
    assert_includes tile_tip("overdue"), "whose due date was before the meeting's date, 11/21/2026"
    assert_includes tile_tip("closed"), "Stored when the meeting closed; the list shows the tickets as they are now."
    assert_includes tip(".rubylode-agenda-dates > summary"), "its period is fixed"
  end

  test "sections and row controls explain themselves, with the plugin's tooltip and no title" do
    travel_to NOW do
      topic = add_topic(@agenda, "Release")
      add_line(topic, "Write the changelog")
      get agenda_path
    end
    assert_includes tip(".rubylode-agenda-breakdown h4"), "split by"
    assert_includes tip("li.rubylode-agenda-line .rubylode-agenda-handle"), "Drag"
    assert_includes tip("li.rubylode-agenda-line .rubylode-agenda-menu-button"), "actions for this line"
    assert_includes tip("li.rubylode-agenda-line .rubylode-agenda-done-tip"), "not carried"
    assert_includes tip("nav.rubylode-agenda-rail a.rubylode-agenda-rail-link"), "Scrolls to this topic"
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
    assert_includes tile_tip("closed"), "Tickets closed between"
    assert_select "form.rubylode-agenda-tip", count: 0
    assert_select ".rubylode-agenda-menu-button", count: 0
    assert_select ".rubylode-agenda-done-tip", count: 0
    assert_select "[data-tooltip*='Lets you tick lines']", count: 0
  end
end
