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
  # The colour kind of a ticket status, from what Redmine knows, since its statuses are free-form: a closed status is
  # :closed; the open status with the lowest position (normally "New") is :first; every other open status takes amber,
  # purple and teal in turn by its rank among the open ones after the first. The page renders a class per kind.
  module StatusColour
    CYCLE = %i[amber purple teal].freeze

    def self.kind_for(status)
      return :closed if status.is_closed?

      open_ids = ::IssueStatus.where(is_closed: false).order(:position, :id).pluck(:id) # cached by the request's query cache
      rank = open_ids.index(status.id).to_i
      rank.zero? ? :first : CYCLE[(rank - 1) % CYCLE.size]
    end
  end
end
