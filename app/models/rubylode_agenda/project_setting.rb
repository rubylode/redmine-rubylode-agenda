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
  class ProjectSetting < ActiveRecord::Base
    self.table_name = "rubylode_agenda_project_settings"

    LINK_FORMAT = %r{\Ahttps?://\S+\z}i

    belongs_to :project

    before_validation :clear_blank_links

    validates :project_id, presence: true
    validates :kpi_url, :progress_url, format: { with: LINK_FORMAT }, length: { maximum: 255 }, allow_nil: true

    def self.for(project)
      find_or_initialize_by(project_id: project.id)
    end

    private

    def clear_blank_links
      self.kpi_url = kpi_url.to_s.strip.presence
      self.progress_url = progress_url.to_s.strip.presence
    end
  end
end
