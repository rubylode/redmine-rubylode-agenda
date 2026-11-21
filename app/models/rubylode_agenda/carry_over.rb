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
  # Copies the unfinished lines of one meeting into the next: notes not done, and lines whose ticket is still open. A topic
  # with nothing to carry is left behind; a copied topic keeps its title, owner and ticket, and a copied line keeps its
  # ticket and remembers where it came from and how often it has moved on.
  class CarryOver
    def initialize(from:, to:)
      @from = from
      @to = to
    end

    def call
      @from.topics.active.in_order.each do |topic|
        carried = topic.lines.carryable.in_order.to_a
        next if carried.empty?

        copy = @to.topics.create!(title: topic.title, owner_id: topic.owner_id, issue_id: topic.issue_id)
        carried.each do |line|
          copy.lines.create!(meeting: @to, text: line.text, issue_id: line.issue_id, carried_from_id: line.id,
                             carried_count: line.carried_count + 1)
        end
      end
    end
  end
end
