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

require_relative "../test_helper"

class RubylodeAgendaSettingsTest < RubylodeAgendaIntegrationTest
  test "the settings page has the two link fields" do
    get agenda_path("/settings")
    assert_response :success
    assert_select "input[name=kpi_url]"
    assert_select "input[name=progress_url]"
    assert_select "input[name=query_id]", count: 0
  end

  test "the links are stored and shown under the agenda" do
    patch agenda_path("/settings"), params: { kpi_url: "https://sheets.example.com/kpi", progress_url: "https://example.com/progress" }
    assert_response :redirect
    stored = RubylodeAgenda::ProjectSetting.find_by!(project_id: 1)
    assert_equal "https://sheets.example.com/kpi", stored.kpi_url
    assert_equal "https://example.com/progress", stored.progress_url
    start_meeting
    get agenda_path
    assert_select "a.rubylode-agenda-link[href='https://sheets.example.com/kpi']"
    assert_select "a.rubylode-agenda-link[href='https://example.com/progress']"
  end

  test "a link that is not http or https is refused" do
    patch agenda_path("/settings"), params: { kpi_url: "javascript:alert(1)", progress_url: "" }
    assert_response :unprocessable_entity
    assert_equal 0, RubylodeAgenda::ProjectSetting.where.not(kpi_url: nil).count
  end

  test "clearing a link removes it" do
    patch agenda_path("/settings"), params: { kpi_url: "https://sheets.example.com/kpi" }
    patch agenda_path("/settings"), params: { kpi_url: "" }
    assert_nil RubylodeAgenda::ProjectSetting.find_by!(project_id: 1).kpi_url
  end

  test "a reader sees the links but cannot open or save the settings" do
    patch agenda_path("/settings"), params: { kpi_url: "https://sheets.example.com/kpi" }
    start_meeting
    log_in_as_reader
    get agenda_path
    assert_select "a.rubylode-agenda-link[href='https://sheets.example.com/kpi']"
    assert_select "a.rubylode-agenda-settings-link", count: 0
    get agenda_path("/settings")
    assert_response :forbidden
    patch agenda_path("/settings"), params: { kpi_url: "https://evil.example.com" }
    assert_response :forbidden
  end
end
