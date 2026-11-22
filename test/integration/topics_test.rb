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

class RubylodeAgendaTopicsTest < RubylodeAgendaIntegrationTest
  def setup
    super
    @agenda = start_agenda
  end

  test "creating a topic answers the envelope with the rendered row" do
    post agendas_path("/#{@agenda.id}/topics"), params: { title: "Release plan", owner_id: 3 }
    assert_response :success
    body = json_response
    assert_equal 1, body["revision"]
    assert_equal 1, body["topics"].size
    assert_equal [], body["lines"]
    record = body["topics"].first
    assert_equal 1, record["position"]
    assert_equal false, record["deleted"]
    assert_includes record["html"], "Release plan"
    stored = RubylodeAgenda::Topic.find(record["id"])
    assert_equal 3, stored.owner_id
    assert_equal 1, stored.revision
  end

  test "an owner who is not a member of the project is refused and nothing is stored" do
    outsider = User.find(4)
    assert_not @project.users.include?(outsider)
    post agendas_path("/#{@agenda.id}/topics"), params: { title: "Release plan", owner_id: outsider.id }
    assert_response :unprocessable_entity
    assert_equal 1, json_response["errors"].size
    assert_equal 0, RubylodeAgenda::Topic.count
  end

  test "changing the owner to a non-member is refused and the row never shows the name" do
    topic = add_topic(@agenda, "One", owner_id: 3)
    patch agenda_path("/topics/#{topic["id"]}"), params: { owner_id: 4, lock_version: topic["lock_version"] }
    assert_response :unprocessable_entity
    assert_equal 3, RubylodeAgenda::Topic.find(topic["id"]).owner_id
    get agenda_path
    assert_not_includes response.body, User.find(4).name
  end

  test "an owner who has since left the project stays while the owner is not changed" do
    topic = add_topic(@agenda, "One", owner_id: 3)
    Member.where(project_id: @project.id, user_id: 3).destroy_all
    patch agenda_path("/topics/#{topic["id"]}"), params: { title: "Renamed", lock_version: topic["lock_version"] }
    assert_response :success
    assert_equal 3, RubylodeAgenda::Topic.find(topic["id"]).owner_id
  end

  test "a blank title is refused with a message" do
    post agendas_path("/#{@agenda.id}/topics"), params: { title: "  " }
    assert_response :unprocessable_entity
    assert_equal 1, json_response["errors"].size
    assert_equal 0, RubylodeAgenda::Topic.count
  end

  test "each write raises the revision by one and stamps the changed record" do
    first = add_topic(@agenda, "One")
    second = add_topic(@agenda, "Two")
    assert_equal [1, 2], [first, second].map { |record| RubylodeAgenda::Topic.find(record["id"]).revision }
    patch agenda_path("/topics/#{first["id"]}"), params: { title: "One renamed", lock_version: first["lock_version"] }
    assert_response :success
    assert_equal 3, json_response["revision"]
    assert_equal 3, RubylodeAgenda::Topic.find(first["id"]).revision
    assert_equal 2, RubylodeAgenda::Topic.find(second["id"]).revision
    assert_equal 3, @agenda.reload.revision
  end

  test "updating the title and the owner" do
    topic = add_topic(@agenda, "One")
    patch agenda_path("/topics/#{topic["id"]}"), params: { title: "Budget", owner_id: 2, lock_version: topic["lock_version"] }
    assert_response :success
    stored = RubylodeAgenda::Topic.find(topic["id"])
    assert_equal "Budget", stored.title
    assert_equal 2, stored.owner_id
    assert_equal 1, json_response["topics"].first["lock_version"]
  end

  test "a stale update answers 409 with the current record and changes nothing" do
    topic = add_topic(@agenda, "One")
    patch agenda_path("/topics/#{topic["id"]}"), params: { title: "Mine", lock_version: topic["lock_version"] }
    patch agenda_path("/topics/#{topic["id"]}"), params: { title: "Late", lock_version: topic["lock_version"] }
    assert_response :conflict
    body = json_response
    assert_equal 2, body["revision"]
    assert_equal 1, body["topics"].first["lock_version"]
    assert_includes body["topics"].first["html"], "Mine"
    assert_equal "Mine", RubylodeAgenda::Topic.find(topic["id"]).title
  end

  test "deleting a topic keeps the record, marks it and its lines deleted" do
    topic = add_topic(@agenda, "One")
    line = add_line(topic, "Note")
    delete agenda_path("/topics/#{topic["id"]}")
    assert_response :success
    body = json_response
    assert_equal 4, body["revision"]
    assert_equal true, body["topics"].first["deleted"]
    assert_equal [line["id"]], body["lines"].map { |record| record["id"] }
    assert_equal true, body["lines"].first["deleted"]
    assert_not_nil RubylodeAgenda::Topic.find(topic["id"]).deleted_at
    get agenda_path
    assert_select "li.rubylode-agenda-topic", count: 0
  end

  test "reordering rewrites positions and answers the topics that moved" do
    one = add_topic(@agenda, "One")
    two = add_topic(@agenda, "Two")
    three = add_topic(@agenda, "Three")
    post agendas_path("/#{@agenda.id}/topics/reorder"), params: { ids: [three["id"], one["id"], two["id"]] }
    assert_response :success
    body = json_response
    assert_equal 6, body["revision"]
    assert_equal({ three["id"] => 1, one["id"] => 2, two["id"] => 3 },
                 body["topics"].to_h { |record| [record["id"], record["position"]] })
    get agenda_path
    assert_equal %w[Three One Two], css_select("li.rubylode-agenda-topic input[data-field=topic-title]").map { |input| input["value"] }
  end

  test "the page numbers the topics in order" do
    add_topic(@agenda, "One")
    add_topic(@agenda, "Two")
    get agenda_path
    assert_select "ol.rubylode-agenda-topics > li.rubylode-agenda-topic", count: 2
  end

  test "a reader cannot write topics" do
    topic = add_topic(@agenda, "One")
    log_in_as_reader
    post agendas_path("/#{@agenda.id}/topics"), params: { title: "Nope" }
    assert_response :forbidden
    patch agenda_path("/topics/#{topic["id"]}"), params: { title: "Nope" }
    assert_response :forbidden
    delete agenda_path("/topics/#{topic["id"]}")
    assert_response :forbidden
    post agendas_path("/#{@agenda.id}/topics/reorder"), params: { ids: [topic["id"]] }
    assert_response :forbidden
    assert_equal "One", RubylodeAgenda::Topic.find(topic["id"]).title
  end

  test "a topic of another project is not found" do
    topic = add_topic(@agenda, "One")
    other = Project.find(3)
    other.enable_module!(:rubylode_agenda)
    Member.create!(project: other, user_id: 2, role_ids: [1])
    patch agenda_path("/topics/#{topic["id"]}", project: other), params: { title: "Nope" }
    assert_response :not_found
    assert_equal "One", RubylodeAgenda::Topic.find(topic["id"]).title
  end

  test "text is still editable after the agenda is closed" do
    topic = add_topic(@agenda, "One")
    post agendas_path("/#{@agenda.id}/close")
    patch agenda_path("/topics/#{topic["id"]}"), params: { title: "Corrected", lock_version: topic["lock_version"] }
    assert_response :success
    assert_equal "Corrected", RubylodeAgenda::Topic.find(topic["id"]).title
  end
end
