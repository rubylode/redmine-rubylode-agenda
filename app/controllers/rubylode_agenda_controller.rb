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

class RubylodeAgendaController < RubylodeAgendaBaseController
  menu_item :rubylode_agenda

  def show
    @meetings = RubylodeAgenda::Meeting.where(project_id: @project.id).newest_first.to_a
    @meeting = params[:id] ? @meetings.find { |meeting| meeting.id == params[:id].to_i } : RubylodeAgenda::Meeting.current_for(@project)
    return render_404 if params[:id] && @meeting.nil?

    @topics = @meeting ? @meeting.topics.active.in_order.includes(:owner) : []
    @setting = RubylodeAgenda::ProjectSetting.for(@project)
    @editable = User.current.allowed_to?(:manage_rubylode_agenda, @project)
  end
end
