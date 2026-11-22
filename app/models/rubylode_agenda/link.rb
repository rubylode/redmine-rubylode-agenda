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
  # One of a project's standing links. Only http and https addresses are stored, and only those are ever rendered, so
  # a javascript: or data: address can neither be saved nor shown.
  class Link < ActiveRecord::Base
    self.table_name = "rubylode_agenda_links"

    ADDRESS_FORMAT = %r{\Ahttps?://\S+\z}i
    LABEL_LIMIT = 60
    ADDRESS_LIMIT = 1000

    belongs_to :project

    validates :label, presence: true, length: { maximum: LABEL_LIMIT }
    validates :url, presence: true, format: { with: ADDRESS_FORMAT }, length: { maximum: ADDRESS_LIMIT }

    scope :in_order, -> { order(:position, :id) }

    # The links to show for a project, in order; an address stored some other way is left out.
    def self.shown_for(project)
      where(project_id: project.id).in_order.select(&:safe_address?)
    end

    def safe_address?
      url.to_s.match?(ADDRESS_FORMAT)
    end
  end
end
