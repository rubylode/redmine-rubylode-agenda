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

    private

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
