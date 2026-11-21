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

class RubylodeAgendaNumbersTest < RubylodeAgendaSidebarTest
  NOW = Time.utc(2026, 11, 21, 12, 0)

  def setup
    super
    @meeting = create_meeting(held_on: Date.new(2026, 11, 21), period_start: Date.new(2026, 11, 14), period_end: Date.new(2026, 11, 21))
  end

  def closed_per_person_rows
    css_select(".rubylode-agenda-person").map do |row|
      [row.at_css(".rubylode-agenda-person-name").text.strip, row.at_css(".rubylode-agenda-person-count").text.strip]
    end
  end

  test "the average is the mean days from creation to close, to one decimal" do
    travel_to NOW do
      build_ticket(subject: "Five days", closed: true, created_on: Time.utc(2026, 11, 10, 12), closed_on: Time.utc(2026, 11, 15, 12))
      build_ticket(subject: "Two and a half", closed: true, created_on: Time.utc(2026, 11, 14, 0), closed_on: Time.utc(2026, 11, 16, 12))
      build_ticket(subject: "One and a quarter", closed: true, created_on: Time.utc(2026, 11, 17, 0), closed_on: Time.utc(2026, 11, 18, 6))
      build_ticket(subject: "Closed before the period", closed: true, created_on: Time.utc(2026, 1, 1), closed_on: Time.utc(2026, 11, 1))
      get agenda_path
      assert_equal "2.9", sidebar_number("average_days_to_close")
    end
  end

  test "the average is shown with one decimal even when it is whole" do
    travel_to NOW do
      build_ticket(subject: "Four days", closed: true, created_on: Time.utc(2026, 11, 10, 12), closed_on: Time.utc(2026, 11, 14, 12))
      get agenda_path
      assert_equal "4.0", sidebar_number("average_days_to_close")
    end
  end

  test "with nothing closed the average is a dash" do
    travel_to NOW do
      get agenda_path
      assert_equal "-", sidebar_number("average_days_to_close")
    end
  end

  test "overdue counts open tickets due before today" do
    travel_to NOW do
      build_ticket(subject: "Yesterday", due_date: Date.new(2026, 11, 20))
      build_ticket(subject: "Last month", due_date: Date.new(2026, 10, 1))
      build_ticket(subject: "Today", due_date: Date.new(2026, 11, 21))
      build_ticket(subject: "Tomorrow", due_date: Date.new(2026, 11, 22))
      build_ticket(subject: "No date")
      build_ticket(subject: "Closed and late", closed: true, due_date: Date.new(2026, 11, 1), closed_on: Time.utc(2026, 11, 2))
      get agenda_path
      assert_equal "2", sidebar_number("overdue")
    end
  end

  test "overdue is zero when nothing is late" do
    travel_to NOW do
      get agenda_path
      assert_equal "0", sidebar_number("overdue")
    end
  end

  test "a closed meeting counts overdue as of its own date, not the day it was closed" do
    build_ticket(subject: "Late at the meeting", due_date: Date.new(2026, 11, 20))
    build_ticket(subject: "Late only after the meeting", due_date: Date.new(2026, 11, 23))
    travel_to(Time.utc(2026, 11, 25, 9)) { close_meeting(@meeting) }
    assert_equal 1, @meeting.reload.snapshot.numbers["overdue"]
    travel_to Time.utc(2026, 12, 20, 9) do
      get agenda_path("/meetings/#{@meeting.id}")
      assert_equal "1", sidebar_number("overdue")
    end
  end

  test "closed per person is sorted by count then name with the unassigned as a row of their own" do
    travel_to NOW do
      3.times { |index| build_ticket(subject: "Hill #{index}", closed: true, closed_on: Time.utc(2026, 11, 18, 10), assigned_to_id: 4) }
      2.times { |index| build_ticket(subject: "Smith #{index}", closed: true, closed_on: Time.utc(2026, 11, 18, 10), assigned_to_id: 2) }
      2.times { |index| build_ticket(subject: "Lopper #{index}", closed: true, closed_on: Time.utc(2026, 11, 18, 10), assigned_to_id: 3) }
      build_ticket(subject: "Nobody", closed: true, closed_on: Time.utc(2026, 11, 18, 10))
      build_ticket(subject: "Closed before", closed: true, closed_on: Time.utc(2026, 11, 1), assigned_to_id: 2)
      get agenda_path
      assert_equal [["Robert Hill", "3"], ["Dave Lopper", "2"], ["John Smith", "2"], ["Unassigned", "1"]], closed_per_person_rows
    end
  end

  test "closed per person is empty when nothing was closed" do
    travel_to NOW do
      get agenda_path
      assert_equal [], closed_per_person_rows
    end
  end

  test "closing stores five numbers and no per-person data" do
    build_ticket(subject: "Closed by Hill", closed: true, created_on: Time.utc(2026, 11, 10, 12), closed_on: Time.utc(2026, 11, 14, 12), assigned_to_id: 4)
    build_ticket(subject: "Closed unassigned", closed: true, created_on: Time.utc(2026, 11, 15, 12), closed_on: Time.utc(2026, 11, 17, 12))
    build_ticket(subject: "Opened and late", created_on: Time.utc(2026, 11, 16), due_date: Date.new(2026, 11, 20))
    travel_to(Time.utc(2026, 11, 21, 18, 30)) { close_meeting(@meeting) }
    expected = {
      "closed" => 2, "opened" => 2, "still_open" => 1, "average_days_to_close" => 3.0, "overdue" => 1
    }
    assert_equal expected, @meeting.reload.snapshot.numbers
  end

  test "a closed meeting shows the stored average, not today's, and counts per person live" do
    ticket = build_ticket(subject: "Closed by Hill", closed: true, created_on: Time.utc(2026, 11, 10, 12), closed_on: Time.utc(2026, 11, 14, 12), assigned_to_id: 4)
    travel_to(Time.utc(2026, 11, 21, 18, 30)) { close_meeting(@meeting) }
    ticket.update_columns(assigned_to_id: 2)
    get agenda_path("/meetings/#{@meeting.id}")
    assert_equal "4.0", sidebar_number("average_days_to_close")
    assert_equal [["John Smith", "1"]], closed_per_person_rows
  end

  test "a viewer who cannot see a private ticket gets a per-person table without it while the stored count stays" do
    build_ticket(subject: "Public", closed: true, closed_on: Time.utc(2026, 11, 14, 12), assigned_to_id: 2)
    build_ticket(subject: "Private", closed: true, closed_on: Time.utc(2026, 11, 14, 12), assigned_to_id: 4, is_private: true)
    travel_to(Time.utc(2026, 11, 21, 18, 30)) { close_meeting(@meeting) }
    assert_equal 2, @meeting.reload.snapshot.numbers["closed"]
    log_in_as_reader
    get agenda_path("/meetings/#{@meeting.id}")
    assert_equal "2", sidebar_number("closed")
    assert_equal [["John Smith", "1"]], closed_per_person_rows
    assert_not_includes response.body, "Robert Hill"
  end

  test "the previous meeting's average and overdue stand beside the current ones" do
    first = create_meeting(held_on: Date.new(2026, 11, 14), period_start: Date.new(2026, 11, 7), period_end: Date.new(2026, 11, 14))
    build_ticket(subject: "Closed in the first period", closed: true, created_on: Time.utc(2026, 11, 6, 12), closed_on: Time.utc(2026, 11, 10, 12))
    build_ticket(subject: "Late for both", due_date: Date.new(2026, 11, 12))
    travel_to(Time.utc(2026, 11, 14, 10)) { close_meeting(first) }
    build_ticket(subject: "Late for the second", due_date: Date.new(2026, 11, 20))
    build_ticket(subject: "Closed in the second period", closed: true, created_on: Time.utc(2026, 11, 15, 0), closed_on: Time.utc(2026, 11, 17, 0))
    travel_to NOW do
      get agenda_path
      assert_equal "2.0", sidebar_number("average_days_to_close")
      assert_equal "4.0", sidebar_previous_number("average_days_to_close")
      assert_equal "2", sidebar_number("overdue")
      assert_equal "1", sidebar_previous_number("overdue")
      assert_nil sidebar_previous_number("closed")
    end
  end

  test "the first meeting shows no previous values" do
    travel_to NOW do
      get agenda_path
      assert_nil sidebar_previous_number("average_days_to_close")
      assert_nil sidebar_previous_number("overdue")
    end
  end

  test "a previous meeting that closed nothing has no previous average but a previous overdue of zero" do
    first = create_meeting(held_on: Date.new(2026, 11, 14), period_start: Date.new(2026, 11, 7), period_end: Date.new(2026, 11, 14))
    travel_to(Time.utc(2026, 11, 14, 10)) { close_meeting(first) }
    travel_to NOW do
      get agenda_path
      assert_nil sidebar_previous_number("average_days_to_close")
      assert_equal "0", sidebar_previous_number("overdue")
    end
  end

  test "a previous meeting without a snapshot shows no previous values" do
    create_meeting(held_on: Date.new(2026, 11, 14), period_start: Date.new(2026, 11, 7), period_end: Date.new(2026, 11, 14),
                   closed_at: Time.utc(2026, 11, 14, 10))
    travel_to NOW do
      get agenda_path
      assert_response :success
      assert_nil sidebar_previous_number("overdue")
    end
  end
end
