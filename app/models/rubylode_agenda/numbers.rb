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
  # The numbers of the sidebar, all counted inside the scope for the meeting's period.
  class Numbers
    SECONDS_PER_DAY = 86_400.0

    def initialize(project:, viewer:, meeting:)
      @viewer = viewer
      @meeting = meeting
      @scope = Scope.new(project: project, viewer: viewer, meeting: meeting)
      @closed_issues = ClosedIssues.new(project: project, viewer: viewer, meeting: meeting)
    end

    def closed
      @closed_issues.relation.count
    end

    def opened
      @scope.issues.where(created_on: @scope.period_range).count
    end

    def still_open
      @scope.open_issues.count
    end

    # Mean days from creation to close of the tickets closed in the period, to one decimal; nil when there are none.
    def average_days_to_close
      spans = @closed_issues.relation.pluck(:created_on, :closed_on).map { |created_on, closed_on| closed_on - created_on }
      return nil if spans.empty?

      (spans.sum / spans.size / SECONDS_PER_DAY).round(1)
    end

    # Open tickets due before today while the meeting is open, before its own date once it is closed.
    def overdue
      @scope.open_issues.where("#{Issue.table_name}.due_date < ?", overdue_as_of).count
    end

    # Who closed how many, by the assignee at the moment of the report: most first, then by name, the unassigned
    # as a row of their own that sorts after named people with the same count.
    def closed_per_person
      counts = @closed_issues.relation.group(:assigned_to_id).count
      names = Principal.where(id: counts.keys.compact).to_h { |principal| [principal.id, principal.name] }
      rows = counts.map { |principal_id, count| { "user_id" => principal_id, "name" => names[principal_id], "count" => count } }
      rows.sort_by { |row| [-row["count"], row["user_id"] ? 0 : 1, row["name"].to_s.downcase] }
    end

    # What a snapshot stores. The per-person table is left out on purpose: it carries names, so it is counted again for
    # each viewer.
    def to_h
      { "closed" => closed, "opened" => opened, "still_open" => still_open,
        "average_days_to_close" => average_days_to_close, "overdue" => overdue }
    end

    private

    def overdue_as_of
      @meeting.open? ? @viewer.today : @meeting.held_on
    end
  end
end
