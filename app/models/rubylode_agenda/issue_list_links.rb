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

module RubylodeAgenda
  # The filters of Redmine's own issue list that shows exactly the tickets behind a number of the sidebar. They are
  # built from what the numbers use: the scope's saved query without its status filter, the project with its
  # subprojects, the period's days and the day overdue is counted from. Redmine's date filters take whole days in the
  # viewer's time zone, the same edges as the period. A number whose field the saved query already filters on cannot
  # be expressed in one filter set (one operator per field): it gets no link rather than a wrong one.
  class IssueListLinks
    NEEDED_FIELDS = {
      "closed" => %w[closed_on], "average_days_to_close" => %w[closed_on], "opened" => %w[created_on],
      "still_open" => [], "overdue" => %w[due_date]
    }.freeze
    CLOSED_SORT = "closed_on:desc,id:desc".freeze

    def initialize(project:, viewer:, agenda:)
      @project = project
      @viewer = viewer
      @agenda = agenda
      @scope = Scope.new(project: project, viewer: viewer, agenda: agenda)
    end

    # Redmine decides what the list shows; without the permission to view issues there is nothing to link to.
    def available?
      @viewer.allowed_to?(:view_issues, @project)
    end

    # The list's parameters for a tile, or nil when it cannot be linked.
    def params_for(key)
      return nil unless available?

      filters = base_filters
      return nil if NEEDED_FIELDS.fetch(key).any? { |field| filters.key?(field) }

      case key
      when "closed", "average_days_to_close" then to_params(closed(filters), sort: CLOSED_SORT)
      when "opened" then to_params(filters.merge("status_id" => ["*"], "created_on" => ["><", *period_days]))
      when "still_open" then to_params(filters.merge("status_id" => ["o"]))
      when "overdue" then to_params(filters.merge("status_id" => ["o"], "due_date" => ["<=", (@scope.overdue_as_of - 1).to_s]))
      end
    end

    # The Closed list narrowed to one assignee, or to none for the unassigned row.
    def person_params(user_id)
      return nil unless available?

      filters = base_filters
      return nil if filters.key?("closed_on") || filters.key?("assigned_to_id")

      assignee = user_id ? ["=", user_id.to_s] : ["!*"]
      to_params(closed(filters).merge("assigned_to_id" => assignee), sort: CLOSED_SORT)
    end

    # A row of closed per project, as [project the list is addressed to, its parameters], or nil when that list cannot
    # be built exactly. The project's own row is its list without subprojects; a subproject's row is the subproject's own
    # list with everything under it. The scope query goes along by its filters, not by its id, and only when every filter
    # exists in that list; a query that decides the subprojects itself (a subproject filter, or a project query while
    # Redmine shows no subprojects) cannot be followed into a subproject, so those rows are left unlinked.
    def project_row(row_project)
      return nil unless @viewer.allowed_to?(:view_issues, row_project)

      filters = base_filters.except("subproject_id")
      return nil if filters.key?("closed_on") || filters.key?("project_id")
      return nil if @scope.saved_query&.filters&.key?("subproject_id")

      if row_project == @project
        own = closed(filters)
        own["subproject_id"] = ["!*"] if @project.descendants.any?
        return [@project, to_params(own, sort: CLOSED_SORT)]
      end
      query = @scope.saved_query
      return nil if query&.project_id && !Setting.display_subprojects_issues?
      return nil unless filters_exist_in?(row_project, filters.keys)

      subtree = closed(filters)
      subtree["subproject_id"] = ["*"] if row_project.descendants.any?
      [row_project, to_params(subtree, sort: CLOSED_SORT)]
    end

    # A row of closed per category: the Closed list and that category, or none.
    def category_params(category_id)
      return nil unless available?

      filters = base_filters
      return nil if filters.key?("closed_on") || filters.key?("category_id")

      category = category_id ? ["=", category_id.to_s] : ["!*"]
      to_params(closed(filters).merge("category_id" => category), sort: CLOSED_SORT)
    end

    private

    def filters_exist_in?(project, fields)
      available = IssueQuery.new(project: project).available_filters
      fields.all? { |field| available.key?(field) }
    end

    def closed(filters)
      filters.merge("status_id" => ["c"], "closed_on" => ["><", *period_days])
    end

    def period_days
      [@agenda.period_start.to_s, @agenda.period_end.to_s]
    end

    # The saved query's filters but its status, and the subprojects as the numbers count them: all of them without a
    # query or with a query saved for every project; as the query says (or Redmine's own setting) with a project query.
    def base_filters
      query = @scope.saved_query
      filters = (query&.filters || {}).except("status_id").to_h do |field, filter|
        [field, [filter[:operator] || filter["operator"], *Array(filter[:values] || filter["values"])]]
      end
      if (query.nil? || query.project_id.nil?) && !filters.key?("subproject_id") && @project.descendants.any?
        filters["subproject_id"] = ["*"]
      end
      filters
    end

    def to_params(filters, sort: nil)
      params = { set_filter: 1, f: filters.keys + [""], op: filters.transform_values(&:first),
                 v: filters.transform_values { |filter| filter.drop(1) }.reject { |_, values| values.empty? } }
      params[:sort] = sort if sort
      params
    end
  end
end
