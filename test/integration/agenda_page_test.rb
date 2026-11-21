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

class RubylodeAgendaPageTest < Redmine::IntegrationTest
  include RubylodeAgendaTestHelpers

  fixtures :users, :email_addresses, :roles

  test "a logged in user sees the empty page" do
    log_user("jsmith", "jsmith")
    get "/agenda"
    assert_response :success
    assert_select "h2", text: "Agenda"
    assert_select "p.nodata", text: "Nothing to show yet"
  end

  test "an anonymous visitor is sent to the login page" do
    get "/agenda"
    assert_redirected_to %r{/login}
  end
end
