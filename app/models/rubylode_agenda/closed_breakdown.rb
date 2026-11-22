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
  # Where the Closed number's tickets came from, counted for the viewer and never stored. With a subproject the viewer
  # may see: per project, the project itself (its own tickets) first, then each direct subproject with everything under
  # it, in Redmine's order, quiet subprojects included. Otherwise per category, most first, "no category" last. The rows
  # count exactly the Closed number's tickets, so they add up to it.
  class ClosedBreakdown
    Row = Struct.new(:name, :count, :project, :category_id, :no_category, keyword_init: true)

    def initialize(project:, viewer:, agenda:)
      @project = project
      @viewer = viewer
      @closed = ClosedIssues.new(project: project, viewer: viewer, agenda: agenda).relation
    end

    def kind
      @kind ||= @project.descendants.visible(@viewer).exists? ? :project : :category
    end

    def rows
      @rows ||= kind == :project ? project_rows : category_rows
    end

    private

    def project_rows
      counts = @closed.group(:project_id).count
      children = @project.children.visible(@viewer).order(:lft).to_a
      own = Row.new(name: @project.name, count: counts.fetch(@project.id, 0), project: @project)
      own_rows = children.map do |child|
        subtree = child.self_and_descendants.pluck(:id)
        Row.new(name: child.name, count: counts.slice(*subtree).values.sum, project: child)
      end
      [own, *own_rows]
    end

    def category_rows
      counts = @closed.group(:category_id).count
      names = IssueCategory.where(id: counts.keys.compact).pluck(:id, :name).to_h
      named = counts.except(nil).map { |category_id, count| Row.new(name: names[category_id], count: count, category_id: category_id) }
      named.sort_by! { |row| [-row.count, row.name.to_s.downcase] }
      named << Row.new(name: nil, count: counts[nil], no_category: true) if counts[nil]
      named
    end
  end
end
