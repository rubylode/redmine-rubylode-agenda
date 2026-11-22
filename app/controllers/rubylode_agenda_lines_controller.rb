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

class RubylodeAgendaLinesController < RubylodeAgendaBaseController
  # A new line goes at the end of the topic, or right after the line named by after_id, at the depth asked for as far as
  # its place allows. The answer holds the new line and any line that moved down to make room.
  def create
    topic = project_topics.active.find(params[:topic_id])
    line = topic.lines.build(agenda: topic.agenda)
    return render_failure(line) unless line.assign_text(params[:text], User.current)
    return render_failure(line) unless line.valid?

    above = topic.lines.shown.find(params[:after_id]) if params[:after_id].present?
    moved = []
    RubylodeAgenda::Line.transaction do
      moved = line.make_room_after!(above) if above
      raise ActiveRecord::Rollback if params[:depth].present? && !line.assign_depth(params[:depth])

      line.save!
    end
    return render_failure(line) if line.new_record?

    render_envelope(topic.agenda_id, lines: [line, *moved])
  end

  def update
    line = project_lines.active.find(params[:id])
    line.lock_version = params[:lock_version] if params[:lock_version].present?
    return render_failure(line) if params.key?(:text) && !line.assign_text(params[:text], User.current)
    return render_failure(line) if params.key?(:issue_id) && !line.assign_ticket(params[:issue_id], User.current)
    return render_failure(line) if params.key?(:depth) && !line.assign_depth(params[:depth])

    line.done = ActiveModel::Type::Boolean.new.cast(params[:done]) if params.key?(:done)
    return render_failure(line) unless line.save

    render_envelope(line.agenda_id, lines: [line])
  end

  def destroy
    line = project_lines.active.find(params[:id])
    line.soft_delete!
    render_envelope(line.agenda_id, lines: [line])
  end

  def reorder
    topic = project_topics.active.find(params[:topic_id])
    changed = RubylodeAgenda::Line.reorder!(topic, Array(params[:ids]))
    render_envelope(topic.agenda_id, lines: changed)
  end

  def park
    line = project_lines.shown.find(params[:id])
    line.lock_version = params[:lock_version] if params[:lock_version].present?
    line.park!
    render_with_parked_list(line.agenda_id, lines: [line])
  end

  def unpark
    line = project_lines.active.where.not(parked_at: nil).find(params[:id])
    line.lock_version = params[:lock_version] if params[:lock_version].present?
    result = line.unpark!
    return render json: { errors: [l("rubylode_agenda.parked.no_open_agenda")] }, status: :unprocessable_entity unless result

    render_with_parked_list(result.agenda.id, topics: [result.made_topic].compact, lines: [line],
                            agenda_path: project_rubylode_agenda_agenda_path(@project, result.agenda))
  end

  private

  # The usual envelope, plus the project's parked list, which sits outside any topic and so is not a record of its own.
  def render_with_parked_list(agenda_id, topics: [], lines: [], agenda_path: nil)
    revision = RubylodeAgenda::Agenda.where(id: agenda_id).pick(:revision)
    parked_html = render_to_string(partial: "rubylode_agenda/parked", formats: [:html], layout: false,
                                   locals: { project: @project, editable: true })
    render json: { agenda_id: agenda_id, agenda_path: agenda_path, revision: revision,
                   topics: topics.map { |topic| topic_record(topic) },
                   lines: lines.map { |line| line_record(line) }, parked_html: parked_html }
  end
end
