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

agenda = "projects/:project_id/agenda"

get agenda, to: "rubylode_agenda#show", as: :project_rubylode_agenda
get "#{agenda}/meetings/:id", to: "rubylode_agenda#show", as: :project_rubylode_agenda_meeting
post "#{agenda}/meetings", to: "rubylode_agenda_meetings#create", as: :project_rubylode_agenda_meetings
patch "#{agenda}/meetings/:id", to: "rubylode_agenda_meetings#update"
post "#{agenda}/meetings/:id/close", to: "rubylode_agenda_meetings#close", as: :close_project_rubylode_agenda_meeting

post "#{agenda}/meetings/:meeting_id/topics", to: "rubylode_agenda_topics#create",
                                              as: :project_rubylode_agenda_meeting_topics
post "#{agenda}/meetings/:meeting_id/topics/reorder", to: "rubylode_agenda_topics#reorder",
                                                      as: :reorder_project_rubylode_agenda_meeting_topics
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
