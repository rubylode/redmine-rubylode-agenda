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

class RubylodeAgendaSidebarPageTest < RubylodeAgendaSidebarTest
  NOW = Time.utc(2026, 11, 21, 12, 0)

  def setup
    super
    @agenda = create_agenda(held_on: Date.new(2026, 11, 21), period_start: Date.new(2026, 11, 14), period_end: Date.new(2026, 11, 21))
  end

  test "the sidebar has its heading and the period" do
    travel_to NOW do
      get agenda_path
      assert_select "aside.rubylode-agenda-sidebar h3", text: "Since the last meeting"
      assert_select "aside.rubylode-agenda-sidebar .rubylode-agenda-sidebar-period", text: "11/14/2026 to 11/21/2026"
    end
  end

  test "the counts are closed and opened in the period and everything still open" do
    travel_to NOW do
      build_ticket(subject: "Closed one", closed: true, created_on: Time.utc(2026, 10, 1), closed_on: Time.utc(2026, 11, 15, 9))
      build_ticket(subject: "Closed two", closed: true, created_on: Time.utc(2026, 11, 16), closed_on: Time.utc(2026, 11, 17, 9))
      build_ticket(subject: "Closed long ago", closed: true, created_on: Time.utc(2026, 9, 1), closed_on: Time.utc(2026, 9, 2))
      build_ticket(subject: "Opened in the period", created_on: Time.utc(2026, 11, 20, 8))
      build_ticket(subject: "Opened before", created_on: Time.utc(2026, 11, 1))
      build_ticket(subject: "Opened after", created_on: Time.utc(2026, 11, 22, 8))
      get agenda_path
      assert_equal "2", sidebar_number("closed")
      assert_equal "2", sidebar_number("opened")
      assert_equal "3", sidebar_number("still_open")
    end
  end

  test "a closed ticket row shows its number, subject, assignee and closed date" do
    travel_to NOW do
      ticket = build_ticket(subject: "Fix the login", closed: true, closed_on: Time.utc(2026, 11, 18, 10), assigned_to_id: 2)
      get agenda_path
      assert_select "li.rubylode-agenda-closed-issue[data-issue-id='#{ticket.id}']" do
        assert_select "a[href='/issues/#{ticket.id}']", text: "##{ticket.id}"
        assert_select ".rubylode-agenda-closed-subject[title='Fix the login']", text: "Fix the login"
        assert_select ".rubylode-agenda-closed-assignee", text: "John Smith"
        assert_select ".rubylode-agenda-closed-date", text: "11/18/2026"
      end
    end
  end

  test "an empty period says no ticket was closed" do
    travel_to NOW do
      get agenda_path
      assert_select ".rubylode-agenda-closed-list .nodata", text: "No tickets were closed in this period."
    end
  end

  test "tickets are grouped by version with the ones without a version last" do
    travel_to NOW do
      alpha = build_version("Alpha")
      beta = build_version("Beta")
      build_ticket(subject: "No version", closed: true, closed_on: Time.utc(2026, 11, 20, 10))
      build_ticket(subject: "Beta one", closed: true, closed_on: Time.utc(2026, 11, 19, 10), version: beta)
      build_ticket(subject: "Alpha one", closed: true, closed_on: Time.utc(2026, 11, 18, 10), version: alpha)
      build_ticket(subject: "Alpha two", closed: true, closed_on: Time.utc(2026, 11, 17, 10), version: alpha)
      get agenda_path
      names = css_select(".rubylode-agenda-closed-group-name").map { |heading| heading.text.strip }
      assert_equal ["Alpha", "Beta", "No version"], names
      alpha_subjects = css_select(".rubylode-agenda-closed-group:first-of-type .rubylode-agenda-closed-subject").map { |subject| subject.text.strip }
      assert_equal ["Alpha one", "Alpha two"], alpha_subjects
    end
  end

  test "ten tickets are all shown and an eleventh and twelfth go behind Show 2 more" do
    travel_to NOW do
      alpha = build_version("Alpha")
      11.times do |index|
        build_ticket(subject: "Alpha #{index}", closed: true, closed_on: Time.utc(2026, 11, 20, 10) - index.hours, version: alpha)
      end
      build_ticket(subject: "Loose", closed: true, closed_on: Time.utc(2026, 11, 20, 10))
      get agenda_path
      assert_select ".rubylode-agenda-closed-list > .rubylode-agenda-closed-group li.rubylode-agenda-closed-issue", count: 10
      assert_select "details.rubylode-agenda-closed-more summary", text: "Show 2 more"
      assert_select "details.rubylode-agenda-closed-more li.rubylode-agenda-closed-issue", count: 2
      assert_select "details.rubylode-agenda-closed-more .rubylode-agenda-closed-group-name", text: "No version"
    end
  end

  test "exactly ten tickets have no Show more" do
    travel_to NOW do
      10.times { |index| build_ticket(subject: "Ticket #{index}", closed: true, closed_on: Time.utc(2026, 11, 20, 10) - index.hours) }
      get agenda_path
      assert_select "li.rubylode-agenda-closed-issue", count: 10
      assert_select "details.rubylode-agenda-closed-more", count: 0
    end
  end

  test "without Progress there is no progress block and the page works" do
    travel_to NOW do
      get agenda_path
      assert_response :success
      assert_select ".rubylode-agenda-progress", count: 0
      assert_select ".rubylode-agenda-numbers"
    end
  end

  test "the first agenda shows the current progress only" do
    travel_to NOW do
      version = build_version("Alpha")
      define_progress_stand_in(percent: 34, stages: [ProgressStandIn.stage(version, done: 2, total: 6)])
      get agenda_path
      assert_select ".rubylode-agenda-progress-after", text: "34%"
      assert_select ".rubylode-agenda-progress-bar[role=progressbar][aria-valuenow='34']"
      assert_select ".rubylode-agenda-progress-before", count: 0
      assert_select ".rubylode-agenda-progress-change", count: 0
      assert_select ".rubylode-agenda-stage-name", text: "Alpha"
      assert_select ".rubylode-agenda-stage-after", text: "2/6"
      assert_select ".rubylode-agenda-stage-before", count: 0
    end
  end

  test "a second agenda shows the previous snapshot as before with the change in points" do
    version = build_version("Alpha")
    first = create_agenda(held_on: Date.new(2026, 11, 14), period_start: Date.new(2026, 11, 7), period_end: Date.new(2026, 11, 14))
    define_progress_stand_in(percent: 34, stages: [ProgressStandIn.stage(version, done: 2, total: 6)])
    travel_to(Time.utc(2026, 11, 14, 10)) { close_agenda(first) }
    ProgressStandIn.percent = 51
    ProgressStandIn.stages = [ProgressStandIn.stage(version, done: 4, total: 8)]
    travel_to NOW do
      get agenda_path
      assert_select ".rubylode-agenda-progress-before", text: "34%"
      assert_select ".rubylode-agenda-progress-after", text: "51%"
      assert_select ".rubylode-agenda-progress-change", text: "+17 points"
      assert_select ".rubylode-agenda-stage-before", text: "2/6"
      assert_select ".rubylode-agenda-stage-after", text: "4/8"
    end
  end

  test "a drop in progress shows a negative change" do
    first = create_agenda(held_on: Date.new(2026, 11, 14), period_start: Date.new(2026, 11, 7), period_end: Date.new(2026, 11, 14))
    define_progress_stand_in(percent: 60)
    travel_to(Time.utc(2026, 11, 14, 10)) { close_agenda(first) }
    ProgressStandIn.percent = 55
    travel_to NOW do
      get agenda_path
      assert_select ".rubylode-agenda-progress-change", text: "-5 points"
    end
  end

  test "a previous agenda without a snapshot gives no before" do
    create_agenda(held_on: Date.new(2026, 11, 14), period_start: Date.new(2026, 11, 7), period_end: Date.new(2026, 11, 14),
                   closed_at: Time.utc(2026, 11, 14, 10))
    define_progress_stand_in(percent: 51)
    travel_to NOW do
      get agenda_path
      assert_select ".rubylode-agenda-progress-after", text: "51%"
      assert_select ".rubylode-agenda-progress-before", count: 0
    end
  end

  test "a closed agenda reads its counts and progress from its snapshot and says as of" do
    define_progress_stand_in(percent: 40)
    build_ticket(subject: "Closed in time", closed: true, closed_on: Time.utc(2026, 11, 18, 10))
    travel_to(Time.utc(2026, 11, 21, 18, 30)) { close_agenda(@agenda) }
    ProgressStandIn.percent = 90
    travel_to Time.utc(2026, 11, 25, 9) do
      build_ticket(subject: "Closed later in the same period", closed: true, closed_on: Time.utc(2026, 11, 19, 10))
      build_ticket(subject: "Newly open")
      get agendas_path("/#{@agenda.id}")
      assert_select ".rubylode-agenda-as-of", text: "As of 11/21/2026"
      assert_select "aside.rubylode-agenda-sidebar > h3 + .rubylode-agenda-as-of"
      assert_equal "1", sidebar_number("closed")
      assert_equal "0", sidebar_number("still_open")
      assert_select ".rubylode-agenda-progress-after", text: "40%"
      assert_equal 2, closed_issue_ids_in_sidebar.size
    end
  end

  test "the sidebar is a card of sections, each number a tile, and Show more a secondary button" do
    travel_to NOW do
      12.times { |index| build_ticket(subject: "Closed #{index}", closed: true, closed_on: Time.utc(2026, 11, 18, 10)) }
      get agenda_path
      assert_select "aside.rubylode-agenda-sidebar > h3 + .rubylode-agenda-sidebar-period"
      assert_select "aside.rubylode-agenda-sidebar > section.rubylode-agenda-sidebar-section", minimum: 2
      assert_select ".rubylode-agenda-number-tiles > .rubylode-agenda-number > .rubylode-agenda-number-value + .rubylode-agenda-number-label", count: 5
      assert_select "details.rubylode-agenda-closed-more > summary.rubylode-agenda-button"
    end
  end

  test "an open agenda has no as of line" do
    travel_to NOW do
      get agenda_path
      assert_select ".rubylode-agenda-as-of", count: 0
    end
  end

  test "the closed list of a closed agenda follows the viewer's own visibility" do
    visible = build_ticket(subject: "Public", closed: true, closed_on: Time.utc(2026, 11, 18, 10))
    build_ticket(subject: "Secret", closed: true, closed_on: Time.utc(2026, 11, 18, 10), is_private: true)
    travel_to(Time.utc(2026, 11, 21, 18, 30)) { close_agenda(@agenda) }
    assert_equal 2, @agenda.reload.snapshot.numbers["closed"]
    log_in_as_reader
    get agendas_path("/#{@agenda.id}")
    assert_equal [visible.id], closed_issue_ids_in_sidebar
    assert_equal "2", sidebar_number("closed")
  end
end
