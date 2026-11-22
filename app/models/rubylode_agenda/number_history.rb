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
  # The recent course of the sidebar's numbers, for the sparklines in their tiles. Only what is already stored is read:
  # the snapshots of the project's earlier closed agendas, oldest first, then the agenda shown (its live numbers while
  # it is open, its own snapshot once closed). At most the last eight points. A snapshot without a value (an older
  # shape, or no average because nothing was closed) is a gap, never a zero.
  class NumberHistory
    LIMIT = 8
    # Held before the agenda shown, or the same day and made before it. Named in full: the snapshots are joined.
    EARLIER = "rubylode_agenda_agendas.held_on < :held_on OR " \
              "(rubylode_agenda_agendas.held_on = :held_on AND rubylode_agenda_agendas.id < :id)".freeze

    Point = Struct.new(:date, :value)

    def initialize(agenda:, current_numbers:)
      @agenda = agenda
      @current_numbers = current_numbers
    end

    def points(key)
      rows.map { |date, numbers| Point.new(date, numbers.is_a?(Hash) ? numbers[key] : nil) }
    end

    private

    def rows
      @rows ||= begin
        earlier = Agenda.where(project_id: @agenda.project_id)
                        .where(EARLIER, held_on: @agenda.held_on, id: @agenda.id)
                        .joins(:snapshot).includes(:snapshot).order(:held_on, :id)
        list = earlier.map { |agenda| [agenda.held_on, agenda.snapshot.numbers] }
        own = @agenda.open? ? @current_numbers : @agenda.snapshot&.numbers
        list << [@agenda.held_on, own] if own
        list.last(LIMIT)
      end
    end
  end
end
