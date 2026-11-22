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

# The sparklines of the number tiles: the stored snapshots of the earlier closed agendas, oldest first, then the agenda
# shown (live while open, its snapshot once closed), at most eight points. Nothing new is stored.
class RubylodeAgendaNumberHistoryTest < RubylodeAgendaSidebarTest
  def closed_agenda_with(held_on, numbers)
    agenda = create_agenda(held_on: held_on, period_start: held_on - 7, period_end: held_on, closed_at: held_on.to_time + 3600)
    RubylodeAgenda::Snapshot.create!(agenda_id: agenda.id, numbers: numbers, stages: [], taken_at: held_on.to_time + 3600, taken_by_id: 2)
    agenda
  end

  def numbers(closed)
    { "closed" => closed, "opened" => closed + 1, "still_open" => 10, "average_days_to_close" => closed * 0.5, "overdue" => 1 }
  end

  def values(history, key)
    history.points(key).map { |point| [point.date, point.value] }
  end

  def history_for(agenda, current = {})
    RubylodeAgenda::NumberHistory.new(agenda: agenda, current_numbers: current)
  end

  test "an agenda in the middle of the history sees the earlier ones and itself, not the later ones" do
    first = closed_agenda_with(Date.new(2026, 11, 7), numbers(2))
    middle = closed_agenda_with(Date.new(2026, 11, 14), numbers(4))
    closed_agenda_with(Date.new(2026, 11, 21), numbers(6))
    assert_equal [[first.held_on, 2], [middle.held_on, 4]], values(history_for(middle.reload), "closed")
  end

  test "an open agenda ends with the live value shown in its tile" do
    closed_agenda_with(Date.new(2026, 11, 7), numbers(2))
    closed_agenda_with(Date.new(2026, 11, 14), numbers(4))
    open_agenda = create_agenda(held_on: Date.new(2026, 11, 21), period_start: Date.new(2026, 11, 14), period_end: Date.new(2026, 11, 21))
    assert_equal [[Date.new(2026, 11, 7), 2], [Date.new(2026, 11, 14), 4], [Date.new(2026, 11, 21), 9]],
                 values(history_for(open_agenda, numbers(9)), "closed")
  end

  test "at most the last eight points" do
    10.times { |index| closed_agenda_with(Date.new(2026, 9, 1) + (7 * index), numbers(index)) }
    last = RubylodeAgenda::Agenda.order(:held_on).last
    assert_equal (2..9).to_a, history_for(last).points("closed").map(&:value)
  end

  test "a project with one agenda has one point and no sparkline" do
    only = create_agenda(held_on: Date.new(2026, 11, 21), period_start: Date.new(2026, 11, 14), period_end: Date.new(2026, 11, 21))
    assert_equal 1, history_for(only, numbers(3)).points("closed").size
    travel_to(Time.utc(2026, 11, 21, 12)) { get agenda_path }
    assert_select "svg.rubylode-agenda-sparkline", count: 0
    assert_select ".rubylode-agenda-number", count: 5
  end

  test "a missing value is a gap, not a zero" do
    closed_agenda_with(Date.new(2026, 11, 7), numbers(2).merge("average_days_to_close" => nil))
    closed_agenda_with(Date.new(2026, 11, 14), numbers(4).except("overdue"))
    last = closed_agenda_with(Date.new(2026, 11, 21), numbers(6))
    history = history_for(last)
    assert_equal [nil, 2.0, 3.0], history.points("average_days_to_close").map(&:value)
    assert_equal [1, nil, 1], history.points("overdue").map(&:value)
  end

  test "the tiles draw a sparkline with a named, dated list of values" do
    closed_agenda_with(Date.new(2026, 11, 7), numbers(2))
    closed_agenda_with(Date.new(2026, 11, 14), numbers(4))
    last = closed_agenda_with(Date.new(2026, 11, 21), numbers(6))
    get agendas_path("/#{last.id}")
    assert_select "svg.rubylode-agenda-sparkline[role=img]", count: 5
    spark = css_select(".rubylode-agenda-number[data-kpi=closed] svg.rubylode-agenda-sparkline").first
    assert_equal "Closed by meeting: 11/07/2026 2, 11/14/2026 4, 11/21/2026 6", spark["aria-label"]
    assert_equal "2.0,18.0 32.0,10.0 62.0,2.0", spark.at_css("polyline")["points"]
    assert_not_nil spark.at_css("circle")
    assert_nil spark.at_css("title")
    flat = css_select(".rubylode-agenda-number[data-kpi=still_open] svg polyline").first
    assert_equal "2.0,10.0 32.0,10.0 62.0,10.0", flat["points"]
  end
end
