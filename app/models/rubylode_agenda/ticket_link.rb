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
  # A topic or a line that may point at a ticket. The agenda only points: a ticket is linked by someone who can see it,
  # and shown to others only if they can see it too, so a number or a status never leaks through a row.
  module TicketLink
    extend ActiveSupport::Concern

    included do
      belongs_to :issue, class_name: "::Issue", optional: true
    end

    # The linked ticket, or nil when there is none or the viewer may not see it.
    def visible_issue(viewer = User.current)
      issue if issue&.visible?(viewer)
    end

    # Takes what a person typed: a number, "#123", or blank to unlink. Answers false and notes the error when the number
    # is not a ticket this person may see; the message never says whether the ticket exists.
    def assign_ticket(raw, viewer)
      text = raw.to_s.strip.delete_prefix("#")
      found = ::Issue.visible(viewer).find_by(id: text) if text.match?(/\A\d+\z/)
      if text.empty? || found
        self.issue_id = found&.id
        return true
      end

      errors.add(:issue_id, :invalid)
      false
    end

    # A text that is only "#123" links that ticket and takes its subject as the text.
    def self.ticket_number_alone(text)
      text.to_s.strip[/\A#(\d+)\z/, 1]
    end
  end
end
