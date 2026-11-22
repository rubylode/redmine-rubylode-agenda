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

require "redmine"

Redmine::Plugin.register :redmine_rubylode_agenda do
  name "Rubylode Agenda"
  author "Rubylode"
  author_url "https://github.com/rubylode"
  url "https://github.com/rubylode/redmine-rubylode-agenda"
  description "Dated meeting agendas with progress change and closed tickets"
  version "1.1.2"
  requires_redmine version_or_higher: "7.0.0"

  project_module :rubylode_agenda do
    permission :view_rubylode_agenda, {
      rubylode_agenda: [:show],
      rubylode_agenda_changes: [:show],
      rubylode_agenda_line_issues: [:show]
    }, read: true
    permission :manage_rubylode_agenda, {
      rubylode_agenda_agendas: [:create, :update, :close],
      rubylode_agenda_topics: [:create, :update, :destroy, :reorder],
      rubylode_agenda_lines: [:create, :update, :destroy, :reorder, :park, :unpark],
      rubylode_agenda_line_issues: [:new, :create, :notes, :edit, :update, :picker, :link, :parent, :remove_parent,
                                    :children],
      rubylode_agenda_bulk_tickets: [:review, :choices, :create],
      rubylode_agenda_settings: [:edit, :update]
    }
  end

  menu :project_menu, :rubylode_agenda,
       { controller: "rubylode_agenda", action: "show", id: nil },
       caption: :label_rubylode_agenda, after: :roadmap, param: :project_id
end
