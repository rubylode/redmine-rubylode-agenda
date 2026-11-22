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

# Several tickets at once from selected lines: the review with its defaults, the choices of another project for one row,
# and the one request that makes them all or none. Redmine's own rules decide each ticket; the agenda only asks that the
# person may edit it and may add tickets somewhere.
class RubylodeAgendaBulkTicketsController < RubylodeAgendaBaseController
  ROW_FIELDS = %i[line_id lock_version subject description project_id tracker_id assigned_to_id fixed_version_id parent].freeze

  before_action :find_bulk_agenda, :require_adding_tickets

  def review
    ids = Array(params[:line_ids])
    return render_too_many if ids.size > RubylodeAgenda::BulkTickets::LIMIT

    render_review(@bulk.review_rows(ids))
  end

  # target_project_id, not project_id: the address already holds the project the agenda belongs to.
  def choices
    project = @bulk.allowed_projects.find { |candidate| candidate.id == params[:target_project_id].to_i } or return render_404
    line = @agenda.lines.shown.find_by(id: params[:line_id])
    found = @bulk.choices(project)
    render json: { trackers: found.trackers.map { |tracker| [tracker.id, tracker.name] }, tracker_id: found.tracker_id,
                   assignees: found.assignees.map { |user| [user.id, user.name] },
                   versions: found.versions.map { |version| [version.id, version.name] },
                   assigned_to_id: line && @bulk.default_assignee(line, found) }
  end

  def create
    raw_rows = Array(params.permit(rows: ROW_FIELDS)[:rows]).map { |row| row.to_h.stringify_keys }
    return render_too_many if raw_rows.size > RubylodeAgenda::BulkTickets::LIMIT

    rows = @bulk.rows_from(raw_rows)
    return render_message(:nothing_selected) if rows.empty?

    result = @bulk.create(rows)
    return render_failed(result.rows) unless result.success?

    revision = RubylodeAgenda::Agenda.where(id: @agenda.id).pick(:revision)
    render json: { agenda_id: @agenda.id, revision: revision, topics: [],
                   lines: result.linked_lines.map { |line| line_record(line) },
                   created: result.created.map { |ticket| { id: ticket.id, subject: ticket.subject, path: issue_path(ticket) } },
                   notice: l("rubylode_agenda.bulk.created", count: result.created.size) }
  end

  private

  def find_bulk_agenda
    @agenda = RubylodeAgenda::Agenda.where(project_id: @project.id).find(params[:agenda_id])
    @bulk = RubylodeAgenda::BulkTickets.new(agenda: @agenda, viewer: User.current)
  end

  def require_adding_tickets
    deny_access unless @bulk.may_add_tickets?
  end

  def render_review(rows)
    render partial: "rubylode_agenda_bulk_tickets/review", formats: [:html], layout: false,
           locals: { rows: rows, bulk: @bulk, agenda: @agenda, project: @project }
  end

  def render_failed(rows)
    html = render_to_string(partial: "rubylode_agenda_bulk_tickets/review", formats: [:html], layout: false,
                            locals: { rows: rows, bulk: @bulk, agenda: @agenda, project: @project })
    render json: { errors: [l("rubylode_agenda.bulk.failed")], review_html: html }, status: :unprocessable_entity
  end

  def render_too_many
    render json: { errors: [l("rubylode_agenda.bulk.too_many_at_once", limit: RubylodeAgenda::BulkTickets::LIMIT)] },
           status: :unprocessable_entity
  end

  def render_message(key)
    render json: { errors: [l("rubylode_agenda.bulk.#{key}")] }, status: :unprocessable_entity
  end
end
