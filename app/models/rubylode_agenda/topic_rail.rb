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
  # The rail beside the agenda: one entry per topic, in order, with its number and how many of its lines show (active)
  # and how many sit in the fold of quiet carried lines. Deleted lines and parked lines are not counted. The page builds
  # the same entries again from its own topic sections after every change it applies; this is the one place the server
  # counts them.
  class TopicRail
    Entry = Struct.new(:topic, :number, :active_count, :quiet_count)

    def initialize(topics)
      @topics = topics
    end

    def entries
      @topics.each_with_index.map do |topic, index|
        quiet_lines, active_lines = topic.lines.shown.includes(:issue, :agenda).partition(&:quiet?)
        Entry.new(topic, index + 1, active_lines.size, quiet_lines.size)
      end
    end
  end
end
