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

# Two agendas: the first holds two notes and two ticket lines; the second carries all four. The period of the second
# starts today, so a ticket updated before today has nothing new to say and a ticket updated now does.
class RubylodeAgendaFoldingTest < RubylodeAgendaIntegrationTest
  fixtures :trackers, :projects_trackers, :issue_statuses, :issues, :enumerations, :custom_fields, :custom_values,
           :custom_fields_trackers, :workflows

  def setup
    super
    @still_ticket = Issue.generate!(project_id: 1, subject: "Still the same")
    @still_ticket.update_column(:updated_on, Time.zone.local(2026, 1, 1))
    @moving_ticket = Issue.generate!(project_id: 1, subject: "Moving along")
    first = start_agenda
    topic = add_topic(first, "Release")
    add_line(topic, "First note")
    add_line(topic, "Second note")
    add_line(topic, "##{@still_ticket.id}")
    add_line(topic, "##{@moving_ticket.id}")
    post agendas_path("")
    @agenda = RubylodeAgenda::Agenda.order(:id).last
    @carried = @agenda.topics.first.lines.in_order.to_a
  end

  def folded_lines
    css_select("li.rubylode-agenda-quiet li.rubylode-agenda-line textarea[data-field=line-text]").map(&:text)
  end

  def shown_lines
    css_select("ol.rubylode-agenda-lines > li.rubylode-agenda-line textarea[data-field=line-text]").map(&:text)
  end

  test "carried lines with no activity fold into one row and the others show in order" do
    get agenda_path
    assert_equal ["Moving along"], shown_lines
    assert_equal ["First note", "Second note", "Still the same"], folded_lines
    assert_select "ol.rubylode-agenda-lines > li.rubylode-agenda-quiet details:not([open]) > summary", text: "3 carried, no change"
  end

  test "a line that is new this time is never folded" do
    topic = @agenda.topics.first
    add_line({ "id" => topic.id }, "Brand new")
    get agenda_path
    assert_includes shown_lines, "Brand new"
    assert_not_includes folded_lines, "Brand new"
  end

  test "editing the text of a folded line brings it out of the fold" do
    patch agenda_path("/lines/#{@carried[0].id}"), params: { text: "First note, reworded", lock_version: 0 }
    assert_response :success
    get agenda_path
    assert_equal ["First note, reworded", "Moving along"], shown_lines
    assert_equal ["Second note", "Still the same"], folded_lines
    assert_select "li.rubylode-agenda-quiet > details > summary", text: "2 carried, no change"
  end

  test "ticking a line done does not count as activity" do
    patch agenda_path("/lines/#{@carried[0].id}"), params: { done: "1", lock_version: 0 }
    get agenda_path
    assert_includes folded_lines, "First note"
  end

  test "a ticket updated inside the period brings its line out of the fold" do
    @still_ticket.update_column(:updated_on, Time.current)
    get agenda_path
    assert_includes shown_lines, "Still the same"
    assert_not_includes folded_lines, "Still the same"
  end

  test "a ticket updated before the period began stays folded" do
    @moving_ticket.update_column(:updated_on, Time.zone.local(2026, 1, 1))
    get agenda_path
    assert_equal [], shown_lines
    assert_equal 4, folded_lines.size
    assert_select "li.rubylode-agenda-quiet summary", text: "4 carried, no change"
  end

  test "the fold is left out when nothing is quiet" do
    @still_ticket.update_column(:updated_on, Time.current)
    @moving_ticket.update_column(:updated_on, Time.current)
    patch agenda_path("/lines/#{@carried[0].id}"), params: { text: "One", lock_version: 0 }
    patch agenda_path("/lines/#{@carried[1].id}"), params: { text: "Two", lock_version: 0 }
    get agenda_path
    assert_select "li.rubylode-agenda-quiet", count: 0
    assert_equal 4, shown_lines.size
  end

  test "every carried line shows how often it was carried" do
    post agendas_path("")
    get agenda_path
    assert_select "li.rubylode-agenda-line .rubylode-agenda-carried", text: "carried 2x", count: 4
  end

  test "a line that was never carried shows no count" do
    topic = @agenda.topics.first
    add_line({ "id" => topic.id }, "Brand new")
    get agenda_path
    assert_select "li.rubylode-agenda-line .rubylode-agenda-carried", count: 4
  end

  test "the folded lines sit inside the same list's lettering, not in a list of their own" do
    get agenda_path
    assert_select "ol.rubylode-agenda-lines ol.rubylode-agenda-lines", count: 0
    assert_select "ol.rubylode-agenda-lines > li.rubylode-agenda-quiet > details > ol.rubylode-agenda-quiet-lines", count: 1
    assert_select "ol.rubylode-agenda-quiet-lines > li.rubylode-agenda-line", count: 3
  end

  test "each line record and row says whether the line is quiet" do
    get agenda_path
    assert_select "li[data-line-id='#{@carried[0].id}'][data-quiet=true]"
    assert_select "li[data-line-id='#{@carried[3].id}'][data-quiet=false]"
    patch agenda_path("/lines/#{@carried[0].id}"), params: { done: "1", lock_version: 0 }
    assert_equal true, json_response["lines"].first["quiet"]
    patch agenda_path("/lines/#{@carried[0].id}"), params: { text: "Reworded", lock_version: 1 }
    assert_equal false, json_response["lines"].first["quiet"]
  end

  test "a reader sees the fold too" do
    log_in_as_reader
    get agenda_path
    assert_select "li.rubylode-agenda-quiet summary", text: "3 carried, no change"
  end
end
