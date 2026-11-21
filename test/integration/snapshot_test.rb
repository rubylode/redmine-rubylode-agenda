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

class RubylodeAgendaSnapshotTest < RubylodeAgendaSidebarTest
  def setup
    super
    @meeting = create_meeting(held_on: Date.new(2026, 11, 21), period_start: Date.new(2026, 11, 14), period_end: Date.new(2026, 11, 21))
  end

  test "closing a meeting stores its progress, counts, time and person" do
    version = build_version("Alpha")
    define_progress_stand_in(percent: 51, stages: [ProgressStandIn.stage(version, done: 4, total: 8)])
    build_ticket(subject: "Closed", closed: true, created_on: Time.utc(2026, 11, 1), closed_on: Time.utc(2026, 11, 18, 10))
    build_ticket(subject: "Opened", created_on: Time.utc(2026, 11, 20, 8))
    travel_to Time.utc(2026, 11, 21, 18, 30) do
      close_meeting(@meeting)
    end
    snapshot = RubylodeAgenda::Snapshot.find_by!(meeting_id: @meeting.id)
    assert_equal 51, snapshot.percent
    assert_equal [{ "version_id" => version.id, "done" => 4, "total" => 8 }], snapshot.stages
    assert_equal 1, snapshot.numbers["closed"]
    assert_equal 1, snapshot.numbers["opened"]
    assert_equal 1, snapshot.numbers["still_open"]
    assert_equal Time.utc(2026, 11, 21, 18, 30), snapshot.taken_at
    assert_equal 2, snapshot.taken_by_id
  end

  test "a stage whose version the viewer may not see shows as another stage with its counts" do
    hidden_project = Project.create!(name: "Hidden", identifier: "hiddenproject", is_public: false)
    hidden_version = Version.create!(project: hidden_project, name: "Secret launch")
    visible_version = build_version("Alpha")
    define_progress_stand_in(percent: 51, stages: [ProgressStandIn.stage(visible_version, done: 4, total: 8),
                                                   ProgressStandIn.stage(hidden_version, done: 1, total: 3)])
    close_meeting(@meeting)
    get agenda_path("/meetings/#{@meeting.id}")
    assert_equal %w[Alpha Another\ stage], css_select(".rubylode-agenda-stage-name").map { |name| name.text.strip }
    assert_equal %w[4/8 1/3], css_select(".rubylode-agenda-stage-after").map { |steps| steps.text.strip }
    assert_not_includes response.body, "Secret launch"
  end

  test "without Progress the percent and the stages are empty" do
    close_meeting(@meeting)
    snapshot = RubylodeAgenda::Snapshot.find_by!(meeting_id: @meeting.id)
    assert_nil snapshot.percent
    assert_nil snapshot.stages
  end

  test "closing twice stores one snapshot and changes nothing" do
    build_ticket(subject: "Closed", closed: true, closed_on: Time.utc(2026, 11, 18, 10))
    travel_to(Time.utc(2026, 11, 21, 18, 30)) { close_meeting(@meeting) }
    build_ticket(subject: "Closed too", closed: true, closed_on: Time.utc(2026, 11, 19, 10))
    travel_to(Time.utc(2026, 11, 22, 9)) { close_meeting(@meeting) }
    assert_equal 1, RubylodeAgenda::Snapshot.where(meeting_id: @meeting.id).count
    assert_equal 1, RubylodeAgenda::Snapshot.find_by!(meeting_id: @meeting.id).numbers["closed"]
    assert_equal Time.utc(2026, 11, 21, 18, 30), @meeting.reload.closed_at
    assert_equal Time.utc(2026, 11, 21, 18, 30), @meeting.snapshot.taken_at
  end

  test "a later change in tickets does not change a closed meeting's counts" do
    ticket = build_ticket(subject: "Closed", closed: true, closed_on: Time.utc(2026, 11, 18, 10))
    travel_to(Time.utc(2026, 11, 21, 18, 30)) { close_meeting(@meeting) }
    ticket.update_columns(status_id: 1, closed_on: nil)
    travel_to Time.utc(2026, 11, 25, 9) do
      get agenda_path("/meetings/#{@meeting.id}")
      assert_equal "1", sidebar_number("closed")
      assert_equal 1, @meeting.reload.snapshot.numbers["closed"]
    end
  end

  test "starting the next meeting snapshots the one it closes" do
    build_ticket(subject: "Closed", closed: true, closed_on: Time.utc(2026, 11, 18, 10))
    travel_to(Time.utc(2026, 11, 28, 9)) { post agenda_path("/meetings") }
    assert_equal 1, @meeting.reload.snapshot.numbers["closed"]
    assert_equal Time.utc(2026, 11, 28, 9), @meeting.snapshot.taken_at
  end

  test "the snapshot is taken as the person closing, so a private ticket is not counted for someone who cannot see it" do
    build_ticket(subject: "Public", closed: true, closed_on: Time.utc(2026, 11, 18, 10))
    build_ticket(subject: "Secret", closed: true, closed_on: Time.utc(2026, 11, 18, 10), is_private: true)
    Role.find(2).add_permission!(:manage_rubylode_agenda)
    log_in_as_reader
    close_meeting(@meeting)
    snapshot = @meeting.reload.snapshot
    assert_equal 1, snapshot.numbers["closed"]
    assert_equal 3, snapshot.taken_by_id
  end

  test "the closed meeting's period cannot be changed" do
    close_meeting(@meeting)
    patch agenda_path("/meetings/#{@meeting.id}"), params: { period_start: "2026-01-01" }
    assert_equal Date.new(2026, 11, 14), @meeting.reload.period_start
  end
end
