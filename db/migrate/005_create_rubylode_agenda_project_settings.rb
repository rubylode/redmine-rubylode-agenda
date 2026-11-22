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

class CreateRubylodeAgendaProjectSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :rubylode_agenda_project_settings do |table|
      table.integer :project_id, null: false
      table.integer :query_id
      table.string :kpi_url
      table.string :progress_url
    end
    add_index :rubylode_agenda_project_settings, :project_id, unique: true,
              name: "rubylode_agenda_project_settings_on_project_id"
  end
end
