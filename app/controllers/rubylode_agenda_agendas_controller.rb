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

class RubylodeAgendaAgendasController < RubylodeAgendaBaseController
  menu_item :rubylode_agenda

  def create
    agenda = RubylodeAgenda::Agenda.start_next(project: @project, user: User.current)
    redirect_to project_rubylode_agenda_agenda_path(@project, agenda)
  end

  def update
    agenda = find_agenda
    attributes = params.permit(:held_on, :period_start, :period_end)
    if period_change_refused?(agenda, attributes)
      flash[:error] = l("rubylode_agenda.agenda.period_frozen")
    elsif agenda.update(attributes.to_h)
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = agenda.errors.full_messages.to_sentence
    end
    redirect_to project_rubylode_agenda_agenda_path(@project, agenda)
  end

  def close
    agenda = find_agenda
    agenda.close!(User.current) if agenda.open?
    redirect_to project_rubylode_agenda_agenda_path(@project, agenda)
  end

  private

  # A closed agenda's period is frozen: a request that would move it is refused whole, so nothing is stored.
  def period_change_refused?(agenda, attributes)
    return false if agenda.open?

    { period_start: agenda.period_start, period_end: agenda.period_end }.any? do |name, stored|
      attributes.key?(name) && attributes[name].to_s != stored.to_s
    end
  end

  def find_agenda
    RubylodeAgenda::Agenda.where(project_id: @project.id).find(params[:id])
  end
end
