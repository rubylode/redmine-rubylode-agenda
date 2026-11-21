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

# A line's level under its topic: 0 is a lettered point, 1 a numbered sub-point, 2 a bullet under that. The parent of a
# line is the nearest line above it in the same topic with a smaller depth, so the flat order stays the only order.
class AddDepthToRubylodeAgendaLines < ActiveRecord::Migration[7.2]
  def change
    add_column :rubylode_agenda_lines, :depth, :integer, null: false, default: 0
  end
end
