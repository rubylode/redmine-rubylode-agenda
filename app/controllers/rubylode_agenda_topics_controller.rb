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

class RubylodeAgendaTopicsController < RubylodeAgendaBaseController
  def create
    meeting = RubylodeAgenda::Meeting.where(project_id: @project.id).find(params[:meeting_id])
    topic = meeting.topics.build(owner_id: params[:owner_id].presence)
    return render_failure(topic) unless topic.assign_title(params[:title], User.current)
    return render_failure(topic) unless topic.save

    render_envelope(meeting.id, topics: [topic])
  end

  def update
    topic = project_topics.active.find(params[:id])
    topic.lock_version = params[:lock_version] if params[:lock_version].present?
    return render_failure(topic) if params.key?(:title) && !topic.assign_title(params[:title], User.current)
    return render_failure(topic) if params.key?(:issue_id) && !topic.assign_ticket(params[:issue_id], User.current)

    topic.owner_id = params[:owner_id].presence if params.key?(:owner_id)
    return render_failure(topic) unless topic.save

    render_envelope(topic.meeting_id, topics: [topic])
  end

  def destroy
    topic = project_topics.active.find(params[:id])
    removed_lines = topic.soft_delete!
    render_envelope(topic.meeting_id, topics: [topic], lines: removed_lines)
  end

  def reorder
    meeting = RubylodeAgenda::Meeting.where(project_id: @project.id).find(params[:meeting_id])
    changed = RubylodeAgenda::Topic.reorder!(meeting, Array(params[:ids]))
    render_envelope(meeting.id, topics: changed)
  end
end
