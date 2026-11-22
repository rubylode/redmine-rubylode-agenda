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

# The project's standing links: an ordered list with a label and a web address, at most twelve, at most two shown as
# buttons at the top; listed in the rail of every meeting.
class RubylodeAgendaLinksTest < RubylodeAgendaIntegrationTest
  def link_rows(*rows)
    { links: rows.each_with_index.to_h { |row, index| [index.to_s, row] } }
  end

  def stored
    RubylodeAgenda::Link.where(project_id: 1).order(:position).pluck(:label, :url, :shown_at_top)
  end

  test "an address that is not http or https is refused and the typed rows are kept" do
    patch agenda_path("/settings"), params: link_rows({ label: "Fine", url: "https://example.com/fine" },
                                                     { label: "Bad", url: "javascript:alert(1)" },
                                                     { label: "Data", url: "data:text/html,hi" })
    assert_response :unprocessable_entity
    assert_equal [], stored
    assert_select "input[name='links[0][url]'][value='https://example.com/fine']"
    assert_select "input[name='links[1][url]'][value='javascript:alert(1)']"
    assert_select "tr.rubylode-agenda-link-row-failed input[name='links[1][label]'][value=Bad]"
    assert_select "tr.rubylode-agenda-link-row-failed input[name='links[2][label]'][value=Data]"
    assert_select "tr.rubylode-agenda-link-row-failed", count: 2
  end

  test "a label and an address are both needed, the label up to 60 characters" do
    patch agenda_path("/settings"), params: link_rows({ label: "", url: "https://example.com/a" }, { label: "x" * 61, url: "https://example.com/b" })
    assert_response :unprocessable_entity
    assert_select "tr.rubylode-agenda-link-row-failed", count: 2
    assert_equal [], stored
  end

  test "more than twelve links are refused" do
    rows = Array.new(13) { |index| { label: "Link #{index}", url: "https://example.com/#{index}" } }
    patch agenda_path("/settings"), params: link_rows(*rows)
    assert_response :unprocessable_entity
    assert_select ".rubylode-agenda-links-error", text: /12/
    assert_equal [], stored
  end

  test "more than two links at the top are refused" do
    rows = Array.new(3) { |index| { label: "Top #{index}", url: "https://example.com/#{index}", shown_at_top: "1" } }
    patch agenda_path("/settings"), params: link_rows(*rows)
    assert_response :unprocessable_entity
    assert_select ".rubylode-agenda-links-error", text: /two/
    assert_equal [], stored
  end

  test "removing a row removes the link and the others keep their order" do
    RubylodeAgenda::Link.create!(project: @project, label: "One", url: "https://example.com/1", position: 1)
    RubylodeAgenda::Link.create!(project: @project, label: "Two", url: "https://example.com/2", position: 2)
    patch agenda_path("/settings"), params: link_rows({ label: "Two", url: "https://example.com/2" },
                                                     { label: "One", url: "https://example.com/1", remove: "1" },
                                                     { label: "Three", url: "https://example.com/3" })
    assert_response :redirect
    assert_equal [["Two", "https://example.com/2", false], ["Three", "https://example.com/3", false]], stored
  end

  test "a save without the list keeps the links" do
    RubylodeAgenda::Link.create!(project: @project, label: "One", url: "https://example.com/1", position: 1)
    patch agenda_path("/settings"), params: { show_closed_per_person: "1" }
    assert_response :redirect
    assert_equal ["One"], stored.map(&:first)
  end

  test "a link flagged for the top is a button in the header and is listed in the rail; every meeting shows the list" do
    patch agenda_path("/settings"), params: link_rows({ label: "Join the call", url: "https://meet.example.com/abc", shown_at_top: "1" },
                                                     { label: "Calendar", url: "https://calendar.example.com/team" })
    first = start_agenda
    post agendas_path("/#{first.id}/close")
    start_agenda
    [agenda_path, agendas_path("/#{first.id}")].each do |path|
      get path
      assert_select ".rubylode-agenda-header a.rubylode-agenda-button.rubylode-agenda-header-link[href='https://meet.example.com/abc'][target=_blank][rel='noopener noreferrer']", text: "Join the call"
      assert_select ".rubylode-agenda-header a.rubylode-agenda-header-link", count: 1
      assert_equal ["Join the call", "Calendar"], css_select("nav.rubylode-agenda-rail a.rubylode-agenda-link").map { |link| link.text.strip }
      assert_select "nav.rubylode-agenda-rail a.rubylode-agenda-link[target=_blank][rel='noopener noreferrer']"
      assert_select "nav.rubylode-agenda-rail a.rubylode-agenda-link[title]", count: 0
    end
    log_in_as_reader
    get agenda_path
    assert_select ".rubylode-agenda-header a.rubylode-agenda-header-link", text: "Join the call"
  end

  test "a stored address that is not http or https is never rendered" do
    link = RubylodeAgenda::Link.new(project: @project, label: "Sneaky", url: "javascript:alert(1)", position: 1)
    link.save(validate: false)
    start_agenda
    get agenda_path
    assert_not_includes response.body, "javascript:alert(1)"
  end

  # The move of the two former link fields into the list, as the migrations do it.
  test "the former KPI and Progress fields become list entries, in that order, only when present" do
    move = RubylodeAgenda::FormerLinkFields
    assert_equal [["KPI sheet", "https://k.example.com"], ["Progress page", "https://p.example.com"]],
                 move.links_from(kpi_url: "https://k.example.com", progress_url: "https://p.example.com")
    assert_equal [["Progress page", "https://p.example.com"]], move.links_from(kpi_url: nil, progress_url: "https://p.example.com")
    assert_equal [["KPI sheet", "https://k.example.com"]], move.links_from(kpi_url: "https://k.example.com", progress_url: " ")
    assert_equal [], move.links_from(kpi_url: nil, progress_url: nil)
  end

  test "moving back takes the first link with each label" do
    move = RubylodeAgenda::FormerLinkFields
    links = [["Call", "https://meet.example.com"], ["Progress page", "https://p1.example.com"], ["KPI sheet", "https://k.example.com"],
             ["Progress page", "https://p2.example.com"]]
    assert_equal({ kpi_url: "https://k.example.com", progress_url: "https://p1.example.com" }, move.fields_from(links))
    assert_equal({ kpi_url: nil, progress_url: nil }, move.fields_from([["Call", "https://meet.example.com"]]))
  end
end
