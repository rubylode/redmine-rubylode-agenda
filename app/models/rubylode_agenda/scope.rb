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
  # The tickets that count in the sidebar: what the viewer may see in the project and its subprojects, narrowed by the
  # saved query chosen in the project's agenda settings. A missing query, one the viewer may not see, and one that
  # belongs to another project are ignored.
  #
  # Only the query's filters are applied (its statement), never its sort or columns, and never its status filter.
  class Scope
    attr_reader :project, :viewer, :meeting

    def initialize(project:, viewer:, meeting:)
      @project = project
      @viewer = viewer
      @meeting = meeting
    end

    def issues
      @issues ||= begin
        relation = Issue.visible(viewer).joins(:status).where(project_id: project.self_and_descendants.pluck(:id))
        saved_query ? relation.where(statement_without_status) : relation
      end
    end

    # A query saved in Redmine starts with "open tickets only". Taken as it is, that would empty the closed list and
    # every count of closed tickets, so the sidebar decides open or closed itself.
    def statement_without_status
      query = saved_query.dup
      query.filters = saved_query.filters.except("status_id")
      query.statement
    end

    def open_issues
      issues.where(issue_statuses: { is_closed: false })
    end

    def closed_issues
      issues.where(issue_statuses: { is_closed: true })
    end

    # From the start of the first day to the end of the last day, in the viewer's own time zone as Redmine shows dates
    # to that person, falling back to the server's zone for someone with none set.
    def period_range
      zone = viewer.time_zone || Time.zone
      meeting.period_start.in_time_zone(zone).beginning_of_day..meeting.period_end.in_time_zone(zone).end_of_day
    end

    def saved_query
      return @saved_query if defined?(@saved_query)

      query_id = ProjectSetting.where(project_id: project.id).pick(:query_id)
      @saved_query = query_id && IssueQuery.visible(viewer).where(project_id: [nil, project.id]).find_by(id: query_id)
    end
  end
end
