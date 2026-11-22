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

# The entry page of a project, and the place of everything that is not one agenda's: topics, lines, settings.
agenda = "projects/:project_id/agenda"
# One agenda, and what is made under it.
agendas = "projects/:project_id/agendas"

get agenda, to: "rubylode_agenda#show", as: :project_rubylode_agenda
get "#{agendas}/:id", to: "rubylode_agenda#show", as: :project_rubylode_agenda_agenda
post agendas, to: "rubylode_agenda_agendas#create", as: :project_rubylode_agenda_agendas
patch "#{agendas}/:id", to: "rubylode_agenda_agendas#update"
post "#{agendas}/:id/close", to: "rubylode_agenda_agendas#close", as: :close_project_rubylode_agenda_agenda
get "#{agendas}/:id/changes", to: "rubylode_agenda_changes#show", as: :changes_project_rubylode_agenda_agenda

post "#{agendas}/:agenda_id/topics", to: "rubylode_agenda_topics#create",
                                     as: :project_rubylode_agenda_agenda_topics
post "#{agendas}/:agenda_id/topics/reorder", to: "rubylode_agenda_topics#reorder",
                                             as: :reorder_project_rubylode_agenda_agenda_topics
patch "#{agenda}/topics/:id", to: "rubylode_agenda_topics#update", as: :project_rubylode_agenda_topic
delete "#{agenda}/topics/:id", to: "rubylode_agenda_topics#destroy"

post "#{agenda}/topics/:topic_id/lines", to: "rubylode_agenda_lines#create",
                                         as: :project_rubylode_agenda_topic_lines
post "#{agenda}/topics/:topic_id/lines/reorder", to: "rubylode_agenda_lines#reorder",
                                                 as: :reorder_project_rubylode_agenda_topic_lines
patch "#{agenda}/lines/:id", to: "rubylode_agenda_lines#update", as: :project_rubylode_agenda_line
delete "#{agenda}/lines/:id", to: "rubylode_agenda_lines#destroy"

get "#{agenda}/settings", to: "rubylode_agenda_settings#edit", as: :project_rubylode_agenda_settings
patch "#{agenda}/settings", to: "rubylode_agenda_settings#update"

# Tickets behind lines
get "#{agenda}/lines/:id/issue/new", to: "rubylode_agenda_line_issues#new", as: :new_project_rubylode_agenda_line_issue
get "#{agenda}/lines/:id/issue", to: "rubylode_agenda_line_issues#show", as: :project_rubylode_agenda_line_issue
post "#{agenda}/lines/:id/issue", to: "rubylode_agenda_line_issues#create"
post "#{agenda}/lines/:id/notes", to: "rubylode_agenda_line_issues#notes", as: :project_rubylode_agenda_line_notes
get "#{agenda}/lines/:id/issue/edit", to: "rubylode_agenda_line_issues#edit", as: :edit_project_rubylode_agenda_line_issue
patch "#{agenda}/lines/:id/issue", to: "rubylode_agenda_line_issues#update"
get "#{agenda}/lines/:id/picker", to: "rubylode_agenda_line_issues#picker", as: :project_rubylode_agenda_line_picker
post "#{agenda}/lines/:id/link", to: "rubylode_agenda_line_issues#link", as: :project_rubylode_agenda_line_link
post "#{agenda}/lines/:id/issue/parent", to: "rubylode_agenda_line_issues#parent",
                                         as: :project_rubylode_agenda_line_issue_parent
delete "#{agenda}/lines/:id/issue/parent", to: "rubylode_agenda_line_issues#remove_parent"
post "#{agenda}/lines/:id/issue/children", to: "rubylode_agenda_line_issues#children",
                                           as: :project_rubylode_agenda_line_issue_children

# Parking
post "#{agenda}/lines/:id/park", to: "rubylode_agenda_lines#park", as: :park_project_rubylode_agenda_line
post "#{agenda}/lines/:id/unpark", to: "rubylode_agenda_lines#unpark", as: :unpark_project_rubylode_agenda_line
