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
  # The one place the change counter moves. Every save of a topic or a line, whether it creates, edits, reorders or
  # deletes, bumps the meeting's revision inside the same transaction and stamps that number on the record, so the
  # polling request can ask for everything after the number it last saw. A save that fails rolls the bump back.
  module Revisioned
    extend ActiveSupport::Concern

    included do
      before_save :stamp_meeting_revision
    end

    private

    def stamp_meeting_revision
      self.revision = meeting.bump_revision!
    end
  end
end
