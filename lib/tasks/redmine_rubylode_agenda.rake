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

require_relative "../rubylode_agenda/demo_data"
require_relative "../rubylode_agenda/busy_demo_builder"

namespace :redmine_rubylode_agenda do
  desc "Build the demo project, people, tickets and meetings (does nothing when they are already there)"
  task demo: :environment do
    result = RubylodeAgenda::DemoData.build
    if result == :built
      puts "Demo built: project \"#{RubylodeAgenda::DemoData::PROJECT_NAME}\" at " \
           "/projects/#{RubylodeAgenda::DemoData::PROJECT_IDENTIFIER}/agenda."
    else
      puts "Demo data already loaded."
    end
    puts "Sign in with the password #{RubylodeAgenda::DemoData::PASSWORD} as one of: " \
         "#{RubylodeAgenda::DemoData::LOGINS.join(', ')} (reader can only look), or as admin / admin."
  end

  desc "Build the busy demo project Lighthouse (1000 tickets, ten meetings); does nothing when it is there already"
  task demo_busy: :environment do
    started = Time.now
    result = RubylodeAgenda::BusyDemoBuilder.build_once
    seconds = (Time.now - started).round(1)
    if result == :built
      puts "Lighthouse built in #{seconds} seconds: #{Issue.where(project: Project.find_by(identifier: 'lighthouse')).count} " \
           "tickets, at /projects/lighthouse/agenda."
    else
      puts "Lighthouse is already loaded."
    end
  end
end
