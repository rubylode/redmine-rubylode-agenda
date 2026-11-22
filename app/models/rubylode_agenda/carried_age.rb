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
  # How old a carried line is, by how many meetings it has been carried: up to two is fresh, three to five warm, six
  # and more old. The chip warms with it.
  module CarriedAge
    WARM_FROM = 3
    OLD_FROM = 6

    def self.kind_for(count)
      if count >= OLD_FROM then :old
      elsif count >= WARM_FROM then :warm
      else :fresh
      end
    end
  end
end
