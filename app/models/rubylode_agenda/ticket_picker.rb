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
  # The tickets offered when a line is tied to another ticket: those already linked on the agenda's lines and topics
  # that the viewer may see, without the line's own. Whatever comes back from the page is looked up again here, so a
  # ticket that is hidden and one that does not exist answer the same way.
  class TicketPicker
    def initialize(agenda:, viewer:, except: nil)
      @agenda = agenda
      @viewer = viewer
      @except = except
    end

    def candidates
      ids = @agenda.lines.shown.where.not(issue_id: nil).pluck(:issue_id) +
            @agenda.topics.active.where.not(issue_id: nil).pluck(:issue_id)
      ids = ids.uniq - [@except&.id]
      ::Issue.visible(@viewer).where(id: ids).includes(:status).order(:id).to_a
    end

    # The ticket named by "#123" or "123" when the viewer may see it, else nil.
    def self.find(raw, viewer)
      number = raw.to_s.strip.delete_prefix("#")
      ::Issue.visible(viewer).find_by(id: number) if number.match?(/\A\d+\z/)
    end
  end
end
