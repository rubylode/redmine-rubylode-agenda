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

# What every agenda controller shares: the project from the address, the permission check, and the JSON envelope that
# answers every write: { revision, topics, lines }, each record carrying its server-rendered row.
class RubylodeAgendaBaseController < ApplicationController
  before_action :find_agenda_project, :authorize
  rescue_from ActiveRecord::StaleObjectError, with: :render_conflict
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def find_agenda_project
    @project = Project.find_by(id: params[:project_id]) || Project.find_by(identifier: params[:project_id])
    render_404 unless @project
  end

  def record_not_found
    render_404
  end

  def project_topics
    RubylodeAgenda::Topic.joins(:meeting).where(rubylode_agenda_meetings: { project_id: @project.id })
  end

  def project_lines
    RubylodeAgenda::Line.joins(:meeting).where(rubylode_agenda_meetings: { project_id: @project.id })
  end

  def render_envelope(meeting_id, topics: [], lines: [], status: :ok)
    revision = RubylodeAgenda::Meeting.where(id: meeting_id).pick(:revision)
    render json: { meeting_id: meeting_id, revision: revision, topics: topics.map { |topic| topic_record(topic) },
                   lines: lines.map { |line| line_record(line) } }, status: status
  end

  def render_failure(record)
    render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
  end

  def render_conflict(error)
    record = error.record.reload
    if record.is_a?(RubylodeAgenda::Topic)
      render_envelope(record.meeting_id, topics: [record], status: :conflict)
    else
      render_envelope(record.meeting_id, lines: [record], status: :conflict)
    end
  end

  def topic_record(topic)
    { id: topic.id, position: topic.position, lock_version: topic.lock_version, deleted: topic.deleted?,
      html: topic.deleted? ? nil : render_row("rubylode_agenda/topic", topic: topic) }
  end

  def line_record(line)
    { id: line.id, topic_id: line.topic_id, position: line.position, lock_version: line.lock_version,
      deleted: line.deleted?, parked: line.parked?, quiet: line.quiet?,
      html: line.deleted? ? nil : render_row("rubylode_agenda/line", line: line) }
  end

  def render_row(partial, locals)
    render_to_string(partial: partial, formats: [:html], layout: false,
                     locals: locals.merge(project: @project,
                                          editable: User.current.allowed_to?(:manage_rubylode_agenda, @project)))
  end
end
