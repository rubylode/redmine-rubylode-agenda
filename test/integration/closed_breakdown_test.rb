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

# The section that took the place of closed per person: closed per project when the project has a subproject the viewer
# may see, else closed per category. Its rows count exactly the Closed tile's tickets, so they add up to it, and each row
# links to Redmine's issue list of exactly its tickets.
class RubylodeAgendaClosedBreakdownTest < RubylodeAgendaSidebarTest
  fixtures :issue_categories, :custom_fields, :custom_values, :custom_fields_trackers, :custom_fields_projects

  NOW = Time.utc(2026, 11, 21, 12, 0)

  def setup
    super
    Role.find(1).update!(issues_visibility: "default")
    @agenda = create_agenda(held_on: Date.new(2026, 11, 21), period_start: Date.new(2026, 11, 14), period_end: Date.new(2026, 11, 21))
  end

  def rows
    css_select(".rubylode-agenda-breakdown-row").map do |row|
      name = row.at_css(".rubylode-agenda-breakdown-name")
      [name.text.strip, row.at_css(".rubylode-agenda-breakdown-count").text.strip.to_i, name.name == "a" ? name["href"] : nil]
    end
  end

  def list_count(path)
    get path
    assert_response :success
    items = css_select("span.items").first&.text
    items ? items[%r{/(\d+)\)}, 1].to_i : 0
  end

  def closed_tile
    sidebar_number("closed").to_i
  end

  def closed_inside(subject, **options)
    build_ticket(subject: subject, closed: true, closed_on: Time.utc(2026, 11, 18, 10), **options)
  end

  def use_scope_query(filters)
    query = IssueQuery.new(name: "Scope", visibility: IssueQuery::VISIBILITY_PUBLIC, project: @project)
    query.user_id = 2
    query.filters = filters
    query.save!
    RubylodeAgenda::ProjectSetting.for(@project).update!(query_id: query.id)
  end

  def project_tree_data
    @child = Project.find(3)
    @grandchild = Project.create!(name: "Deep corner", identifier: "deep-corner", is_public: true)
    @grandchild.set_parent!(@child)
    [@child, @grandchild].each { |project| project.enable_module!(:issue_tracking) }
    closed_inside("Here")
    closed_inside("Here too")
    closed_inside("In the child", project: @child)
    closed_inside("In the grandchild", project: @grandchild)
    closed_inside("Private, not seen", is_private: true).update_columns(author_id: 3)
    closed_inside("Second tracker").update_columns(tracker_id: 2)
    build_ticket(subject: "Closed long ago", closed: true, closed_on: Time.utc(2026, 10, 1))
  end

  test "with a visible subproject the section counts per project, the grandchild under its direct ancestor" do
    travel_to NOW do
      project_tree_data
      get agenda_path
      assert_select ".rubylode-agenda-breakdown h4", text: "Closed per project"
      names = rows.map(&:first)
      assert_equal @project.name, names.first
      assert_equal 3, rows.find { |name, *| name == @project.name }[1]
      assert_equal 2, rows.find { |name, *| name == @child.name }[1]
      assert_equal closed_tile, rows.sum { |_, count, _| count }
      assert_equal Project.find(1).children.visible(User.find(2)).order(:lft).map(&:name), names.drop(1)
      zero = css_select(".rubylode-agenda-breakdown-row.rubylode-agenda-breakdown-empty")
      assert_operator zero.size, :>=, 1
    end
  end

  test "each project row lists exactly its tickets" do
    travel_to NOW do
      project_tree_data
      get agenda_path
      linked = rows.select { |_, _, href| href }
      assert_operator linked.size, :>=, 2
      linked.each { |name, count, href| assert_equal count, list_count(href), "#{name} row" }
    end
  end

  test "with a scope query the project rows still add up and list exactly" do
    travel_to NOW do
      project_tree_data
      use_scope_query("tracker_id" => { operator: "=", values: ["1"] }, "status_id" => { operator: "o", values: [""] })
      get agenda_path
      assert_equal closed_tile, rows.sum { |_, count, _| count }
      rows.select { |_, _, href| href }.each { |name, count, href| assert_equal count, list_count(href), "#{name} row" }
    end
  end

  test "without a visible subproject the section counts per category, most first, no category last" do
    project = Project.find(2)
    @project = project
    project.enable_module!(:rubylode_agenda)
    Role.find(2).update!(issues_visibility: "default")
    @agenda = create_agenda(held_on: Date.new(2026, 11, 21), period_start: Date.new(2026, 11, 14), period_end: Date.new(2026, 11, 21))
    printing = IssueCategory.create!(project: project, name: "Packing")
    recipes = IssueCategory.create!(project: project, name: "Shipping")
    travel_to NOW do
      2.times { |index| closed_inside("Printing #{index}", project: project).update_columns(category_id: printing.id) }
      closed_inside("Recipe", project: project).update_columns(category_id: recipes.id)
      closed_inside("No category", project: project)
      closed_inside("Private recipe", project: project, is_private: true).update_columns(category_id: recipes.id, author_id: 3)
      get agenda_path(project: project)
      assert_select ".rubylode-agenda-breakdown h4", text: "Closed per category"
      assert_equal [["Packing", 2], ["Shipping", 1], ["No category", 1]], rows.map { |name, count, _| [name, count] }
      assert_equal closed_tile, rows.sum { |_, count, _| count }
      rows.each { |name, count, href| assert_equal count, list_count(href), "#{name} row" }
    end
  end

  test "nothing closed says so" do
    project = Project.find(2)
    @project = project
    project.enable_module!(:rubylode_agenda)
    Role.find(2).update!(issues_visibility: "default")
    create_agenda(held_on: Date.new(2026, 11, 21), period_start: Date.new(2026, 11, 14), period_end: Date.new(2026, 11, 21))
    travel_to(NOW) { get agenda_path(project: project) }
    assert_select ".rubylode-agenda-breakdown .nodata"
  end

  # ---- closed per person, now an option of the project, off by default

  test "closed per person is off by default: not shown and not counted" do
    travel_to NOW do
      closed_inside("Smith", assigned_to_id: 2)
      grouped = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        grouped << payload[:sql] if payload[:sql] =~ /GROUP BY [^)]*assigned_to_id/i
      end
      begin
        get agenda_path
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end
      assert_select ".rubylode-agenda-closed-per-person", count: 0
      assert_equal [], grouped
    end
  end

  test "turned on, closed per person follows the breakdown, ordered by name, without bars, with links" do
    RubylodeAgenda::ProjectSetting.for(@project).update!(show_closed_per_person: true)
    travel_to NOW do
      3.times { |index| closed_inside("Hill #{index}", assigned_to_id: 4) }
      closed_inside("Lopper", assigned_to_id: 3)
      closed_inside("Nobody")
      get agenda_path
      sections = css_select("aside.rubylode-agenda-sidebar > section").map { |section| section["class"] }
      assert_operator sections.index { |name| name.include?("rubylode-agenda-breakdown") }, :<,
                      sections.index { |name| name.include?("rubylode-agenda-closed-per-person") }
      people = css_select(".rubylode-agenda-person").map do |row|
        [row.at_css(".rubylode-agenda-person-name").text.strip, row.at_css(".rubylode-agenda-person-count").text.strip, row["style"]]
      end
      assert_equal [["Dave Lopper", "1", nil], ["Robert Hill", "3", nil], ["Unassigned", "1", nil]], people
      css_select("a.rubylode-agenda-person-name").each do |link|
        assert_equal link.parent.at_css(".rubylode-agenda-person-count").text.to_i, list_count(link["href"])
      end
    end
  end
end
