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

  before_action :load_scope_queries

  def edit
    @setting = RubylodeAgenda::ProjectSetting.for(@project)
  end

  def update
    @setting = RubylodeAgenda::ProjectSetting.for(@project)
    @setting.assign_attributes(params.permit(:kpi_url, :progress_url, :query_id, :show_closed_per_person).to_h)
    @setting.errors.add(:query_id, l("rubylode_agenda.settings.query_not_available")) unless scope_query_allowed?
    if @setting.errors.empty? && @setting.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to project_rubylode_agenda_settings_path(@project)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # The saved queries the person may pick: this project's and the global ones, as far as they may see them.
  def load_scope_queries
    @scope_queries = IssueQuery.visible(User.current).where(project_id: [nil, @project.id]).order(:name).to_a
  end

  def scope_query_allowed?
    @setting.query_id.nil? || @scope_queries.any? { |query| query.id == @setting.query_id }
  end
end
