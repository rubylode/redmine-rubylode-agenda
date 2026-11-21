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

class CreateRubylodeAgendaSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :rubylode_agenda_snapshots do |table|
      table.integer :meeting_id, null: false
      table.decimal :percent, precision: 6, scale: 2
      table.text :stages
      table.text :numbers
      table.datetime :taken_at
      table.integer :taken_by_id
    end
    add_index :rubylode_agenda_snapshots, :meeting_id, unique: true,
              name: "index_rubylode_agenda_snapshots_on_meeting_id"
  end
end
