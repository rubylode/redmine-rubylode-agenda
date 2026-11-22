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
  # Several tickets made at once from selected lines of an agenda. The review answers one row per line with its
  # defaults; creating makes every ticket, parents first, through Redmine's own rules for the acting person, in one
  # transaction: one failing row and nothing is made, and every row comes back with what was entered and its messages.
  class BulkTickets
    LIMIT = 50

    # One row of the review. parent is what the parent field holds: "", "#123", or the line token of another row
    # ("line 1.a") for the ticket made from that row.
    Row = Struct.new(:entry, :lock_version, :subject, :description, :project_id, :tracker_id, :assigned_to_id,
                     :fixed_version_id, :parent, :messages, keyword_init: true) do
      def line
        entry.line
      end

      def failed?
        messages.any?
      end
    end

    Choices = Struct.new(:trackers, :tracker_id, :assignees, :versions, keyword_init: true)
    Result = Struct.new(:rows, :created, :linked_lines, keyword_init: true) do
      def success?
        rows.none?(&:failed?)
      end
    end

    def initialize(agenda:, viewer:)
      @agenda = agenda
      @viewer = viewer
    end

    def outline
      @outline ||= Outline.new(@agenda)
    end

    # The projects where the person may add tickets, the agenda's own first.
    def allowed_projects
      @allowed_projects ||= ::Issue.allowed_target_projects(@viewer).to_a.sort_by { |project| [project.id == @agenda.project_id ? 0 : 1, project.lft.to_i] }
    end

    def may_add_tickets?
      allowed_projects.any?
    end

    def line_token(entry)
      ::I18n.t("rubylode_agenda.bulk.line_token", label: entry.label)
    end

    # The lines asked for that are shown on the agenda and have no ticket, in agenda order, each with its defaults.
    def review_rows(line_ids)
      ids = Array(line_ids).map(&:to_i)
      entries = outline.entries.select { |entry| ids.include?(entry.line.id) && entry.line.issue_id.nil? }
      selected = entries.map { |entry| entry.line.id }
      entries.map { |entry| default_row(entry, selected) }
    end

    # Tracker, assignee and version choices in a project, with the defaults for the given line.
    def choices(project, _line = nil)
      (@choices ||= {})[project.id] ||= choices_in(project)
    end

    def choices_in(project)
      draft = ::Issue.new(project: project, author: @viewer)
      trackers = draft.allowed_target_trackers(@viewer).to_a
      draft.tracker = trackers.first
      Choices.new(trackers: trackers, tracker_id: trackers.first&.id,
                  assignees: project.assignable_users(draft.tracker).to_a, versions: draft.assignable_versions.to_a)
    end

    def default_assignee(line, choices)
      owner_id = line.topic.owner_id
      owner_id if owner_id && choices.assignees.any? { |user| user.id == owner_id }
    end

    def default_version(line, choices)
      version_id = line.ticket_source(@viewer)&.fixed_version_id
      version_id if version_id && choices.versions.any? { |version| version.id == version_id }
    end

    # Rows as sent back by the page, read against the agenda again: only lines of this agenda, in agenda order.
    def rows_from(params_rows)
      params_rows.filter_map do |values|
        entry = outline.entry_for(values["line_id"])
        next unless entry

        Row.new(entry: entry, lock_version: values["lock_version"].to_i, subject: values["subject"].to_s.strip,
                description: values["description"].to_s.strip, project_id: values["project_id"].to_i,
                tracker_id: values["tracker_id"].to_i, assigned_to_id: values["assigned_to_id"].presence&.to_i,
                fixed_version_id: values["fixed_version_id"].presence&.to_i, parent: values["parent"].to_s.strip,
                messages: [])
      end.sort_by { |row| row.entry.order }
    end

    def create(rows)
      created = {}
      linked = []
      ::Issue.transaction do
        rows.each do |row|
          ticket = make_ticket(row, created)
          next unless ticket

          created[row.line.id] = ticket
          row.line.update!(issue_id: ticket.id)
          linked << row.line
        end
        raise ActiveRecord::Rollback if rows.any?(&:failed?)
      end
      return Result.new(rows: rows, created: [], linked_lines: []) if rows.any?(&:failed?)

      Result.new(rows: rows, created: created.values, linked_lines: linked)
    end

    private

    def default_row(entry, selected)
      line = entry.line
      project = allowed_projects.find { |candidate| candidate.id == @agenda.project_id } || allowed_projects.first
      row_choices = choices(project, line)
      Row.new(entry: entry, lock_version: line.lock_version, subject: line.ticket_subject,
              description: line.ticket_description, project_id: project&.id, tracker_id: row_choices.tracker_id,
              assigned_to_id: default_assignee(line, row_choices), fixed_version_id: default_version(line, row_choices),
              parent: default_parent(line, selected), messages: [])
    end

    def default_parent(line, selected)
      parent_line = line.parent_line
      return line_token(outline.entry_for(parent_line.id)) if parent_line && selected.include?(parent_line.id)

      ticket = line.ticket_source(@viewer)
      ticket ? "##{ticket.id}" : ""
    end

    # Answers the ticket made for the row, or nil with the reasons on the row. Every value goes through
    # safe_attributes, so the tracker's workflow, the required fields and the person's permissions apply.
    def make_ticket(row, created)
      line = row.line.reload
      return refuse(row, ::I18n.t("rubylode_agenda.tickets.errors.already_linked")) if line.issue_id
      return refuse(row, ::I18n.t("rubylode_agenda.messages.conflict")) if line.lock_version != row.lock_version

      project = allowed_projects.find { |candidate| candidate.id == row.project_id }
      return refuse(row, ::I18n.t("rubylode_agenda.bulk.project_not_allowed")) unless project

      parent_id = resolve_parent(row, created)
      return nil if row.failed?

      ticket = ::Issue.new(project: project, author: @viewer)
      tracker = ticket.allowed_target_trackers(@viewer).find { |candidate| candidate.id == row.tracker_id }
      return refuse(row, ::I18n.t("rubylode_agenda.tickets.errors.tracker_not_offered")) unless tracker

      ticket.tracker = tracker
      ticket.status = tracker.default_status
      ticket.priority = ::IssuePriority.default || ::IssuePriority.active.first
      ticket.safe_attributes = { "subject" => row.subject, "description" => row.description.presence,
                                 "assigned_to_id" => row.assigned_to_id.to_s, "fixed_version_id" => row.fixed_version_id.to_s,
                                 "parent_issue_id" => parent_id.to_s }
      return ticket if ticket.save

      ticket.errors.full_messages.each { |message| row.messages << message }
      nil
    end

    def resolve_parent(row, created)
      return nil if row.parent.empty?

      above = outline.entries.find { |entry| line_token(entry) == row.parent }
      if above
        return created.fetch(above.line.id).id if created.key?(above.line.id)

        return refuse(row, ::I18n.t("rubylode_agenda.bulk.parent_not_above"))
      end
      ticket = TicketPicker.find(row.parent, @viewer)
      ticket ? ticket.id : refuse(row, ::I18n.t("rubylode_agenda.tickets.errors.not_found"))
    end

    def refuse(row, message)
      row.messages << message
      nil
    end
  end
end
