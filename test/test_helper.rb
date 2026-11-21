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

require File.expand_path("../../../test/test_helper", __dir__)

module RubylodeAgendaTestHelpers
  def agenda_path(suffix = "", project: @project)
    "/projects/#{project.identifier}/agenda#{suffix}"
  end

  def json_response
    JSON.parse(response.body)
  end

  def start_meeting
    post agenda_path("/meetings")
    RubylodeAgenda::Meeting.where(project_id: @project.id).order(:id).last
  end

  def add_topic(meeting, title, owner_id: nil)
    post agenda_path("/meetings/#{meeting.id}/topics"), params: { title: title, owner_id: owner_id }
    assert_response :success
    json_response["topics"].first
  end

  def add_line(topic_record, text)
    post agenda_path("/topics/#{topic_record["id"]}/lines"), params: { text: text }
    assert_response :success
    json_response["lines"].first
  end
end

# One project with the module on, a manager (jsmith) who can write and a developer (dlopper) who can only read.
class RubylodeAgendaIntegrationTest < Redmine::IntegrationTest
  include RubylodeAgendaTestHelpers

  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses

  def setup
    @project = Project.find(1)
    @project.enable_module!(:rubylode_agenda)
    Role.find(1).add_permission!(:view_rubylode_agenda)
    Role.find(1).add_permission!(:manage_rubylode_agenda)
    Role.find(2).add_permission!(:view_rubylode_agenda)
    Role.find(2).remove_permission!(:manage_rubylode_agenda)
    log_user("jsmith", "jsmith")
  end

  def log_in_as_reader
    post "/logout"
    log_user("dlopper", "foo")
  end
end
