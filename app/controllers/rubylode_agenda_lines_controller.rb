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
  def create
    topic = project_topics.active.find(params[:topic_id])
    line = topic.lines.build(meeting: topic.meeting, text: params[:text].to_s.strip)
    return render_failure(line) unless line.save

    render_envelope(topic.meeting_id, lines: [line])
  end

  def update
    line = project_lines.active.find(params[:id])
    line.lock_version = params[:lock_version] if params[:lock_version].present?
    line.text = params[:text].to_s.strip if params.key?(:text)
    line.done = ActiveModel::Type::Boolean.new.cast(params[:done]) if params.key?(:done)
    return render_failure(line) unless line.save

    render_envelope(line.meeting_id, lines: [line])
  end

  def destroy
    line = project_lines.active.find(params[:id])
    line.soft_delete!
    render_envelope(line.meeting_id, lines: [line])
  end

  def reorder
    topic = project_topics.active.find(params[:topic_id])
    changed = RubylodeAgenda::Line.reorder!(topic, Array(params[:ids]))
    render_envelope(topic.meeting_id, lines: changed)
  end
end
