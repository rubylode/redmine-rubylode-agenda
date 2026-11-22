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
  # The labels the page shows in front of an agenda's lines, worked out on the server: the topic's number, the letter of
  # a point, the numeral of a sub-point, and the place of a bullet ("2.b", "2.b.ii", "2.b.ii.1"). Lines are read in the
  # order the page shows them: the open lines of each topic, then its fold of quiet lines, whose letters run on. The
  # page draws the same letters with CSS counters; these are for the review of several tickets, where a line is named.
  class Outline
    Entry = Struct.new(:line, :label, :depth, :order)

    def initialize(agenda)
      @agenda = agenda
    end

    def entries
      @entries ||= build
    end

    def entry_for(line_id)
      entries_by_line_id[line_id.to_i]
    end

    private

    def entries_by_line_id
      @entries_by_line_id ||= entries.to_h { |entry| [entry.line.id, entry] }
    end

    def build
      order = 0
      @agenda.topics.active.in_order.each_with_index.flat_map do |topic, topic_index|
        quiet_lines, other_lines = topic.lines.shown.includes(:issue, :agenda, :topic).in_order.partition(&:quiet?)
        point = 0
        labels = []
        [other_lines, quiet_lines].flat_map do |sequence|
          depths = Line.shown_depths(sequence)
          sequence.map do |line|
            depth = depths.fetch(line.id)
            labels = labels.first(depth)
            if depth.zero?
              point += 1
              labels = [letter(point)]
            else
              counter = (@counters ||= Hash.new(0))
              key = [topic.id, labels.join(".")]
              counter[key] += 1
              labels << (depth == 1 ? roman(counter[key]) : counter[key].to_s)
            end
            order += 1
            Entry.new(line, "#{topic_index + 1}.#{labels.join(".")}", depth, order)
          end
        end
      end
    end

    def letter(number)
      label = +""
      while number.positive?
        number -= 1
        label.prepend(("a".ord + (number % 26)).chr)
        number /= 26
      end
      label
    end

    ROMAN = { 1000 => "m", 900 => "cm", 500 => "d", 400 => "cd", 100 => "c", 90 => "xc", 50 => "l", 40 => "xl", 10 => "x",
              9 => "ix", 5 => "v", 4 => "iv", 1 => "i" }.freeze

    def roman(number)
      ROMAN.reduce(+"") do |label, (value, numeral)|
        count, number = number.divmod(value)
        label << (numeral * count)
      end
    end
  end
end
