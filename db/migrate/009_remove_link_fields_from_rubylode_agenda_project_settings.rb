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

# The two fixed link fields are in the list now (see migration 008).
class RemoveLinkFieldsFromRubylodeAgendaProjectSettings < ActiveRecord::Migration[7.2]
  def change
    remove_column :rubylode_agenda_project_settings, :kpi_url, :string
    remove_column :rubylode_agenda_project_settings, :progress_url, :string
  end
end
