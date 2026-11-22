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

# The two fixed link fields of the project settings become entries of the list: "KPI sheet" first, then "Progress
# page", each only when it was filled in. Going back copies the first link with each of those labels into the fields.
# The migration keeps its own small model classes, so later changes to the plugin's models cannot break it.
class MoveRubylodeAgendaLinkFieldsIntoLinks < ActiveRecord::Migration[7.2]
  class ProjectSettingRow < ActiveRecord::Base
    self.table_name = "rubylode_agenda_project_settings"
  end

  class LinkRow < ActiveRecord::Base
    self.table_name = "rubylode_agenda_links"
  end

  def up
    [ProjectSettingRow, LinkRow].each(&:reset_column_information)
    ProjectSettingRow.find_each do |setting|
      last = LinkRow.where(project_id: setting.project_id).maximum(:position).to_i
      links = RubylodeAgenda::FormerLinkFields.links_from(kpi_url: setting.kpi_url, progress_url: setting.progress_url)
      links.each_with_index do |(label, url), index|
        LinkRow.create!(project_id: setting.project_id, label: label, url: url, position: last + index + 1, shown_at_top: false)
      end
    end
  end

  def down
    [ProjectSettingRow, LinkRow].each(&:reset_column_information)
    LinkRow.distinct.pluck(:project_id).each do |project_id|
      links = LinkRow.where(project_id: project_id).order(:position, :id).pluck(:label, :url)
      setting = ProjectSettingRow.find_or_create_by!(project_id: project_id)
      setting.update!(RubylodeAgenda::FormerLinkFields.fields_from(links))
    end
  end
end
