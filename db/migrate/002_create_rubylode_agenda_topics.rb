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

class CreateRubylodeAgendaTopics < ActiveRecord::Migration[7.2]
  def change
    create_table :rubylode_agenda_topics do |table|
      table.integer :agenda_id, null: false
      table.integer :position, null: false, default: 0
      table.string :title, null: false, default: ""
      table.integer :owner_id
      table.integer :issue_id
      table.integer :revision, null: false, default: 0
      table.integer :lock_version, null: false, default: 0
      table.datetime :deleted_at
      table.timestamps null: true
    end
    add_index :rubylode_agenda_topics, [:agenda_id, :revision],
              name: "rubylode_agenda_topics_on_agenda_id_and_revision"
  end
end
