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

class CreateRubylodeAgendaLines < ActiveRecord::Migration[7.2]
  def change
    create_table :rubylode_agenda_lines do |table|
      table.integer :topic_id, null: false
      table.integer :meeting_id, null: false
      table.integer :position, null: false, default: 0
      table.text :text, null: false
      table.integer :issue_id
      table.boolean :done, null: false, default: false
      table.datetime :parked_at
      table.integer :carried_from_id
      table.integer :carried_count, null: false, default: 0
      table.datetime :edited_at
      table.integer :revision, null: false, default: 0
      table.integer :lock_version, null: false, default: 0
      table.datetime :deleted_at
      table.timestamps null: true
    end
    add_index :rubylode_agenda_lines, [:meeting_id, :revision],
              name: "index_rubylode_agenda_lines_on_meeting_id_and_revision"
    add_index :rubylode_agenda_lines, :topic_id, name: "index_rubylode_agenda_lines_on_topic_id"
  end
end
