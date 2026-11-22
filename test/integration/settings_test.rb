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
  def link_rows(*rows)
    { links: rows.each_with_index.to_h { |row, index| [index.to_s, row] } }
  end

  test "the settings page lists the links with one empty row to add one" do
    RubylodeAgenda::Link.create!(project: @project, label: "Call", url: "https://meet.example.com/abc", position: 1, shown_at_top: true)
    get agenda_path("/settings")
    assert_response :success
    assert_select "input[name='links[0][label]'][value=Call]"
    assert_select "input[name='links[0][url]'][value='https://meet.example.com/abc']"
    assert_select "input[type=checkbox][name='links[0][shown_at_top]'][checked]"
    assert_select "input[type=checkbox][name='links[0][remove]']"
    assert_select "input[name='links[1][label]']:not([value])"
    assert_select "input[name=kpi_url]", count: 0
    assert_select "input[name=query_id]", count: 0
  end

  test "the links are stored in order and shown in the rail" do
    patch agenda_path("/settings"), params: link_rows({ label: "KPI sheet", url: "https://sheets.example.com/kpi" },
                                                     { label: "Roadmap", url: "https://example.com/roadmap" },
                                                     { label: "", url: "" })
    assert_response :redirect
    assert_equal [["KPI sheet", 1], ["Roadmap", 2]], RubylodeAgenda::Link.where(project_id: 1).order(:position).pluck(:label, :position)
    start_agenda
    get agenda_path
    assert_equal %w[https://sheets.example.com/kpi https://example.com/roadmap],
                 css_select("nav.rubylode-agenda-rail a.rubylode-agenda-link").map { |link| link["href"] }
  end

  test "the settings page offers closed per person, off by default, and saves it" do
    get agenda_path("/settings")
    assert_select "input[type=checkbox][name=show_closed_per_person][value='1']:not([checked])"
    assert_select ".rubylode-agenda-hint", text: "Lists how many tickets each person closed in the period. Off by default."
    assert_not RubylodeAgenda::ProjectSetting.for(@project).show_closed_per_person
    patch agenda_path("/settings"), params: { show_closed_per_person: "1" }
    assert_response :redirect
    assert RubylodeAgenda::ProjectSetting.find_by!(project_id: 1).show_closed_per_person
    get agenda_path("/settings")
    assert_select "input[type=checkbox][name=show_closed_per_person][checked]"
    patch agenda_path("/settings"), params: { show_closed_per_person: "0" }
    assert_not RubylodeAgenda::ProjectSetting.find_by!(project_id: 1).show_closed_per_person
  end

  test "a reader cannot turn closed per person on" do
    log_in_as_reader
    patch agenda_path("/settings"), params: { show_closed_per_person: "1" }
    assert_response :forbidden
    assert_not RubylodeAgenda::ProjectSetting.for(@project).show_closed_per_person
  end

  test "a reader sees the links but cannot open or save the settings" do
    RubylodeAgenda::Link.create!(project: @project, label: "KPI sheet", url: "https://sheets.example.com/kpi", position: 1)
    start_agenda
    log_in_as_reader
    get agenda_path
    assert_select "a.rubylode-agenda-link[href='https://sheets.example.com/kpi']"
    assert_select "a.rubylode-agenda-settings-link", count: 0
    get agenda_path("/settings")
    assert_response :forbidden
    patch agenda_path("/settings"), params: link_rows({ label: "Evil", url: "https://evil.example.com" })
    assert_response :forbidden
    assert_equal ["KPI sheet"], RubylodeAgenda::Link.where(project_id: 1).pluck(:label)
  end
end
