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
  # The numbers of an agenda as they stood when it closed, seen by the person who closed it. Written once and never
  # changed: only aggregates are kept, never ticket lists, so a private ticket can at most nudge a count.
  class Snapshot < ActiveRecord::Base
    self.table_name = "rubylode_agenda_snapshots"

    belongs_to :agenda, class_name: "RubylodeAgenda::Agenda"
    belongs_to :taken_by, class_name: "User", optional: true

    serialize :stages, coder: JSON
    serialize :numbers, coder: JSON

    # Does nothing when the agenda already has one.
    def self.take!(agenda:, viewer:, at: Time.current)
      return if exists?(agenda_id: agenda.id)

      progress = ProgressReading.new(project: agenda.project, viewer: viewer, agenda: agenda)
      numbers = Numbers.new(project: agenda.project, viewer: viewer, agenda: agenda)
      create!(agenda_id: agenda.id, percent: progress.percent, stages: progress.stages, numbers: numbers.to_h,
              taken_at: at, taken_by_id: viewer.id)
    end
  end
end
