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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative "../test_helper"

class RubylodeAgendaPluginRegisteredTest < Redmine::IntegrationTest
  include RubylodeAgendaTestHelpers

  test "the plugin is registered under its id and name" do
    plugin = Redmine::Plugin.find(:redmine_rubylode_agenda)
    assert_equal "Rubylode Agenda", plugin.name
  end

  # The Agenda tab on a page that has an id of its own (the project overview, a wiki page) must not take that id for an
  # agenda's: "/projects/x/agendas/x" is a 404.
  test "the Agenda tab links to the project's agenda page from a page that has an id" do
    project = Project.find(1)
    project.enable_module!(:rubylode_agenda)
    Role.find(1).add_permission!(:view_rubylode_agenda)
    log_user("jsmith", "jsmith")

    get "/projects/#{project.identifier}"

    assert_response :success
    assert_select "#main-menu a[href=?]", "/projects/#{project.identifier}/agenda"
    assert_select "#main-menu a[href*='/agendas/']", false
  end
end
