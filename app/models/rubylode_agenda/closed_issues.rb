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
  # The tickets in the scope that were closed inside the meeting's period and are closed now: one closed and reopened
  # since does not count. Always a live query under the viewer's own visibility.
  class ClosedIssues
    Group = Struct.new(:version, :issues, keyword_init: true)

    def initialize(project:, viewer:, meeting:)
      @scope = Scope.new(project: project, viewer: viewer, meeting: meeting)
    end

    def relation
      @scope.closed_issues.where(closed_on: @scope.period_range)
    end

    def issues
      @issues ||= relation.preload(:assigned_to, :fixed_version, :status, :tracker).reorder(closed_on: :desc, id: :desc).to_a
    end

    # By version in the versions' own order, tickets without a version last, newest closed first inside each.
    def groups
      @groups ||= issues.group_by(&:fixed_version).map { |version, version_issues| Group.new(version: version, issues: version_issues) }
                        .sort_by { |group| group.version ? [0, group.version] : [1] }
    end

    # The groups cut after limit tickets: [shown, hidden]. A group that straddles the cut appears in both.
    def split(limit)
      shown = []
      hidden = []
      remaining = limit
      groups.each do |group|
        head = group.issues.first(remaining)
        tail = group.issues.drop(head.size)
        shown << Group.new(version: group.version, issues: head) if head.any?
        hidden << Group.new(version: group.version, issues: tail) if tail.any?
        remaining -= head.size
      end
      [shown, hidden]
    end
  end
end
