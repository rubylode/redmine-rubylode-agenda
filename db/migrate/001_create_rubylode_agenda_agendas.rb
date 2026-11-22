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

class CreateRubylodeAgendaAgendas < ActiveRecord::Migration[7.2]
  def change
    create_table :rubylode_agenda_agendas do |table|
      table.integer :project_id, null: false
      table.date :held_on, null: false
      table.date :period_start, null: false
      table.date :period_end, null: false
      table.datetime :closed_at
      table.integer :closed_by_id
      table.integer :revision, null: false, default: 0
      table.timestamps null: true
    end
    add_index :rubylode_agenda_agendas, [:project_id, :held_on],
              name: "rubylode_agenda_agendas_on_project_id_and_held_on"
  end
end
