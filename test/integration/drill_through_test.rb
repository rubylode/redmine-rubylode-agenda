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

# Each number of the sidebar links to Redmine's own issue list of exactly the tickets behind it: the test follows every
# link as the same person and compares the count the list reports with the number in the tile.
class RubylodeAgendaDrillThroughTest < RubylodeAgendaSidebarTest
  fixtures :issue_categories, :custom_fields, :custom_values, :custom_fields_trackers, :custom_fields_projects

  NOW = Time.utc(2026, 11, 21, 12, 0)

  def setup
    super
    Role.find(1).update!(issues_visibility: "default")
    Role.find(1).add_permission!(:view_issues)
    User.find(2).pref.update!(time_zone: "Tokyo")
    RubylodeAgenda::ProjectSetting.for(@project).update!(show_closed_per_person: true)
    @agenda = create_agenda(held_on: Date.new(2026, 11, 21), period_start: Date.new(2026, 11, 14), period_end: Date.new(2026, 11, 21))
  end

  # Tokyo is nine hours ahead of UTC: the period runs from 11/13 15:00 UTC to 11/21 14:59:59 UTC.
  def build_mixed_data
    subproject = Project.find(3)
    subproject.enable_module!(:issue_tracking)
    build_ticket(subject: "Closed inside", closed: true, created_on: Time.utc(2026, 11, 10), closed_on: Time.utc(2026, 11, 18, 10), assigned_to_id: 2)
    build_ticket(subject: "Closed at the last minute", closed: true, closed_on: Time.utc(2026, 11, 21, 14, 59), assigned_to_id: 3)
    build_ticket(subject: "Closed just after", closed: true, closed_on: Time.utc(2026, 11, 21, 15, 1), assigned_to_id: 2)
    build_ticket(subject: "Closed just before", closed: true, closed_on: Time.utc(2026, 11, 13, 14, 59))
    build_ticket(subject: "Closed at the first minute", closed: true, closed_on: Time.utc(2026, 11, 13, 15, 1))
    build_ticket(project: subproject, subject: "Subproject closed", closed: true, closed_on: Time.utc(2026, 11, 19), assigned_to_id: 2)
    build_ticket(subject: "Private closed", closed: true, closed_on: Time.utc(2026, 11, 19), is_private: true).update_columns(author_id: 3)
    build_ticket(subject: "Opened inside", created_on: Time.utc(2026, 11, 20), due_date: Date.new(2026, 11, 19))
    build_ticket(subject: "Opened just after", created_on: Time.utc(2026, 11, 21, 15, 1))
    build_ticket(subject: "Late", due_date: Date.new(2026, 11, 20))
    build_ticket(subject: "Due today", due_date: Date.new(2026, 11, 21))
    build_ticket(project: subproject, subject: "Subproject late", due_date: Date.new(2026, 11, 1))
    other_tracker = build_ticket(subject: "Other tracker, closed", closed: true, closed_on: Time.utc(2026, 11, 18))
    other_tracker.update_columns(tracker_id: 2)
    Project.find(1).trackers << Tracker.find(2) unless Project.find(1).trackers.include?(Tracker.find(2))
  end

  def use_scope_query(filters)
    query = IssueQuery.new(name: "Scope", visibility: IssueQuery::VISIBILITY_PUBLIC, project: @project)
    query.user_id = 2
    query.filters = filters
    query.save!
    RubylodeAgenda::ProjectSetting.for(@project).update!(query_id: query.id)
  end

  def list_count(path)
    get path
    assert_response :success
    items = css_select("span.items").first&.text
    items ? items[%r{/(\d+)\)}, 1].to_i : 0
  end

  def tile_link(key)
    css_select(".rubylode-agenda-number[data-kpi=#{key}]").first
  end

  def assert_each_tile_matches_its_list(keys)
    get agenda_path
    numbers = keys.to_h { |key| [key, tile_link(key)] }
    people = css_select("a.rubylode-agenda-person-name").map { |link| [link["href"], link.parent.at_css(".rubylode-agenda-person-count").text.strip.to_i] }
    see_all = css_select("a.rubylode-agenda-closed-see-all").first
    numbers.each do |key, tile|
      assert_equal "a", tile.name, "#{key} is a link"
      next if key == "average_days_to_close"

      assert_equal tile.at_css(".rubylode-agenda-number-value").text.to_i, list_count(tile["href"]), "#{key} list count"
    end
    closed_count = numbers["closed"].at_css(".rubylode-agenda-number-value").text.to_i
    assert_equal closed_count, list_count(numbers["average_days_to_close"]["href"])
    assert_equal closed_count, list_count(see_all["href"])
    assert people.any?
    people.each { |href, count| assert_equal count, list_count(href) }
  end

  test "every tile and every person row lists exactly its tickets, subprojects and edges included" do
    travel_to NOW do
      build_mixed_data
      assert_each_tile_matches_its_list(%w[closed opened still_open average_days_to_close overdue])
      get agenda_path
      # inside, last minute, first minute, subproject and the other tracker; not the private one nor the edges outside
      assert_equal "5", sidebar_number("closed")
    end
  end

  test "with a scope query the lists apply its filters but not its status" do
    travel_to NOW do
      build_mixed_data
      use_scope_query("tracker_id" => { operator: "=", values: ["1"] }, "status_id" => { operator: "o", values: [""] })
      assert_each_tile_matches_its_list(%w[closed opened still_open average_days_to_close overdue])
    end
  end

  test "a scope query on the same field as a tile leaves that tile unlinked" do
    travel_to NOW do
      build_mixed_data
      use_scope_query("created_on" => { operator: ">t-", values: ["30"] })
      get agenda_path
      assert_equal "p", tile_link("opened").name
      assert_equal "a", tile_link("closed").name
    end
  end

  test "the closed list's edges are the period's whole days in the viewer's zone" do
    travel_to NOW do
      build_mixed_data
      get agenda_path
      href = tile_link("closed")["href"]
      assert_includes CGI.unescape(href), "v[closed_on][]=2026-11-14"
      assert_includes CGI.unescape(href), "v[closed_on][]=2026-11-21"
      get href
      subjects = css_select("td.subject").map { |cell| cell.text.strip }
      assert_includes subjects, "Closed at the last minute"
      assert_includes subjects, "Closed at the first minute"
      assert_not_includes subjects, "Closed just after"
      assert_not_includes subjects, "Closed just before"
      assert_not_includes subjects, "Private closed"
    end
  end

  test "the tile's name starts with its number and measure and the whole tile is one link" do
    travel_to NOW do
      build_mixed_data
      get agenda_path
      tile = tile_link("closed")
      assert_includes tile["class"], "rubylode-agenda-number-link"
      assert_equal "show the tickets", tile.at_css(".rubylode-agenda-visually-hidden").text.strip.delete_prefix(", ")
      assert_match(/\A\d+\s+Closed/, tile.text.squish)
      assert_nil tile["target"]
    end
  end

  test "a closed agenda keeps the links and says the lists are live" do
    travel_to(Time.utc(2026, 11, 21, 18)) { close_agenda(@agenda) }
    get agendas_path("/#{@agenda.id}")
    assert_select "a.rubylode-agenda-number[data-kpi=closed]"
    assert_select ".rubylode-agenda-sidebar-live-note", text: "Lists show the tickets as they are now."
    assert_includes tile_link("closed").at_css(".rubylode-agenda-visually-hidden").text, "as they are now"
  end

  test "an open agenda has no live note" do
    travel_to(NOW) { get agenda_path }
    assert_select ".rubylode-agenda-sidebar-live-note", count: 0
  end

  test "a reader gets the same links" do
    travel_to NOW do
      build_mixed_data
      log_in_as_reader
      get agenda_path
      assert_select "a.rubylode-agenda-number", count: 5
    end
  end

  test "someone who may not view issues gets no links" do
    Role.find(1).remove_permission!(:view_issues)
    travel_to(NOW) { get agenda_path }
    assert_select "a.rubylode-agenda-number", count: 0
    assert_select "p.rubylode-agenda-number", count: 5
  end
end
