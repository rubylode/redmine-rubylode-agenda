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

class RubylodeAgendaAgendaStartNextTest < ActiveSupport::TestCase
  fixtures :projects, :users

  test "an agenda opened after the caller loaded its data is closed, never left open next to the new one" do
    project = Project.find(1)
    user = User.find(2)
    RubylodeAgenda::Agenda.start_next(project: project, user: user, today: Date.new(2026, 11, 21))
    RubylodeAgenda::Agenda.create!(project_id: 1, held_on: Date.new(2026, 11, 22),
                                    period_start: Date.new(2026, 11, 21), period_end: Date.new(2026, 11, 22))

    RubylodeAgenda::Agenda.start_next(project: project, user: user, today: Date.new(2026, 11, 28))

    agendas = RubylodeAgenda::Agenda.where(project_id: 1)
    assert_equal 3, agendas.count
    assert_equal 1, agendas.where(closed_at: nil).count
    assert_equal Date.new(2026, 11, 28), agendas.find_by(closed_at: nil).held_on
  end
end
