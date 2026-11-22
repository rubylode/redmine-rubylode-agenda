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
  # How the two former link fields of the project settings map onto the list of links, both ways. Migration 008 calls
  # it; it is kept apart so the mapping can be tested without running migrations.
  module FormerLinkFields
    KPI_LABEL = "KPI sheet".freeze
    PROGRESS_LABEL = "Progress page".freeze

    # [[label, address], ...] for the fields that were filled in, KPI sheet first.
    def self.links_from(kpi_url:, progress_url:)
      [[KPI_LABEL, kpi_url], [PROGRESS_LABEL, progress_url]].filter_map do |label, url|
        address = url.to_s.strip
        [label, address] unless address.empty?
      end
    end

    # The fields again, from the first link with each label; nil where there is none.
    def self.fields_from(links)
      { kpi_url: links.find { |label, _| label == KPI_LABEL }&.last,
        progress_url: links.find { |label, _| label == PROGRESS_LABEL }&.last }
    end
  end
end
