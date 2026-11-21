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

class RubylodeAgendaSettingsController < RubylodeAgendaBaseController
  menu_item :rubylode_agenda

  def edit
    @setting = RubylodeAgenda::ProjectSetting.for(@project)
  end

  def update
    @setting = RubylodeAgenda::ProjectSetting.for(@project)
    @setting.assign_attributes(params.permit(:kpi_url, :progress_url).to_h)
    if @setting.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to project_rubylode_agenda_settings_path(@project)
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
