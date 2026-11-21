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

# The polling request: everything in a meeting changed after the revision the page last saw, deleted records included,
# in the same shape as the answer to a write.
class RubylodeAgendaChangesController < RubylodeAgendaBaseController
  def show
    meeting = RubylodeAgenda::Meeting.where(project_id: @project.id).find(params[:id])
    since = params[:since].to_s.match?(/\A\d+\z/) ? params[:since].to_i : 0
    topics = meeting.topics.where("revision > ?", since).order(:revision)
    lines = meeting.lines.where("revision > ?", since).order(:revision)
    render json: { meeting_id: meeting.id, revision: meeting.revision, topics: topics.map { |topic| topic_record(topic) },
                   lines: lines.map { |line| line_record(line) }, meeting_closed: !meeting.open? }
  end
end
