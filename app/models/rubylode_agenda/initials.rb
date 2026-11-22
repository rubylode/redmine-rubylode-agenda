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
  # Two letters for a person's chip: the first letters of the first two words of the name, or the first two letters of
  # a one-word name. The script that follows an owner change uses the same rule.
  module Initials
    def self.for(name)
      words = name.to_s.split(/\s+/).reject(&:empty?)
      letters = words.size >= 2 ? words.first(2).map { |word| word[0] }.join : words.first.to_s[0, 2]
      letters.upcase
    end
  end
end
