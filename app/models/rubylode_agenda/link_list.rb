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
  # The list of links as the settings page sends it: every row in one request, kept as typed when anything is refused,
  # and saved whole or not at all. A row with neither label nor address is the empty row offered for adding one, and is
  # skipped; a row marked for removal is dropped.
  class LinkList
    LIMIT = 12
    TOP_LIMIT = 2

    Row = Struct.new(:label, :url, :shown_at_top, :remove, :messages, keyword_init: true) do
      def blank?
        label.to_s.empty? && url.to_s.empty?
      end
    end

    attr_reader :rows, :messages

    # The rows of the stored links, with one empty row at the end.
    def self.for(project)
      rows = Link.where(project_id: project.id).in_order.map do |link|
        Row.new(label: link.label, url: link.url, shown_at_top: link.shown_at_top, remove: false, messages: [])
      end
      new(project, rows + [Row.new(label: "", url: "", shown_at_top: false, remove: false, messages: [])])
    end

    # From the form's parameters: { "0" => { label:, url:, shown_at_top:, remove: }, ... }, in the order of the keys.
    def self.from_params(project, values)
      cast = ActiveModel::Type::Boolean.new
      rows = values.to_h.sort_by { |key, _| key.to_i }.map do |_, row|
        Row.new(label: row["label"].to_s.strip, url: row["url"].to_s.strip, shown_at_top: cast.cast(row["shown_at_top"]) == true,
                remove: cast.cast(row["remove"]) == true, messages: [])
      end
      new(project, rows)
    end

    def initialize(project, rows)
      @project = project
      @rows = rows
      @messages = []
    end

    def save
      kept = @rows.reject { |row| row.remove || row.blank? }
      kept.each do |row|
        link = Link.new(project: @project, label: row.label, url: row.url, shown_at_top: row.shown_at_top)
        row.messages.concat(link.errors.full_messages) unless link.valid?
      end
      @messages << ::I18n.t("rubylode_agenda.settings.links_too_many", limit: LIMIT) if kept.size > LIMIT
      @messages << ::I18n.t("rubylode_agenda.settings.links_too_many_at_top") if kept.count(&:shown_at_top) > TOP_LIMIT
      return false if @messages.any? || kept.any? { |row| row.messages.any? }

      Link.transaction do
        Link.where(project_id: @project.id).delete_all
        kept.each_with_index do |row, index|
          Link.create!(project: @project, label: row.label, url: row.url, shown_at_top: row.shown_at_top, position: index + 1)
        end
      end
      true
    end
  end
end
