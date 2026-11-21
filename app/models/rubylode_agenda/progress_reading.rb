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
  # The project's progress as the viewer sees it, read from the Progress plugin when it is installed and nothing
  # otherwise. Stages come back as plain hashes so they can be stored and compared later.
  class ProgressReading
    def initialize(project:, viewer:, meeting: nil)
      @project = project
      @viewer = viewer
    end

    def available?
      !!defined?(RubylodeProgress::ProjectProgress)
    end

    def percent
      return nil unless available?

      progress.percent
    end

    def stages
      return nil unless available?

      progress.stages.map do |stage|
        { "version_id" => stage.version.id, "name" => stage.version.name, "done" => stage.done_step_count,
          "total" => stage.step_count }
      end
    end

    private

    def progress
      @progress ||= RubylodeProgress::ProjectProgress.new(project: @project, viewer: @viewer)
    end
  end
end
