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

# The links that stand beside every meeting of a project: a call, a calendar, a roadmap. An ordered list with a label
# and a web address; at most two are shown as buttons at the top.
class CreateRubylodeAgendaLinks < ActiveRecord::Migration[7.2]
  def change
    create_table :rubylode_agenda_links do |table|
      table.integer :project_id, null: false
      table.string :label, null: false, limit: 60
      table.string :url, null: false, limit: 1000
      table.integer :position, null: false, default: 0
      table.boolean :shown_at_top, null: false, default: false
      table.timestamps null: true
    end
    add_index :rubylode_agenda_links, [:project_id, :position], name: "rubylode_agenda_links_on_project_id_and_position"
  end
end
