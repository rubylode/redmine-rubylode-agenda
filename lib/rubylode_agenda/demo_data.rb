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

require "active_support/testing/time_helpers"

module RubylodeAgenda
  # Demo data for the throwaway Redmine in docker-compose.yml (bin/demo), also run by
  # `rake redmine_rubylode_agenda:demo`. Everything is made up.
  #
  # One project, "Demo project", with two versions and twenty tickets of different ages, and a first agenda held eight
  # days ago and closed, so it has a snapshot. The next agenda is started through Agenda.start_next, so carry-over
  # runs: some carried lines are active (their ticket changed today) and some are folded. The past is made with
  # travel_to, so every timestamp (created, closed, held, parked) falls on the day the story says.
  # Safe to run twice: it does nothing when the project exists.
  module DemoData
    PASSWORD = "password1234".freeze
    LOGINS = %w[alex sam reader].freeze
    PROJECT_NAME = "Demo project".freeze
    PROJECT_IDENTIFIER = "demo".freeze
    FIRST_AGENDA_DAYS_AGO = 8
    MODULES = %w[issue_tracking rubylode_agenda].freeze
    READER_ROLE_NAME = "Agenda reader".freeze
    AGENDA_PERMISSIONS = %i[view_rubylode_agenda manage_rubylode_agenda].freeze
    PEOPLE = [
      ["alex", "Alex", "Rivers"], ["sam", "Sam", "Marsh"], ["reader", "Riley", "Reed"]
    ].freeze

    module_function

    # Returns :built, or :already_loaded when the project is there already.
    def build
      return :already_loaded if Project.exists?(identifier: PROJECT_IDENTIFIER)

      previous_user = User.current
      ActiveRecord::Base.transaction { Builder.new.build }
      :built
    ensure
      User.current = previous_user
    end

    # The work of one build, kept in an object so the helpers share what was made so far.
    class Builder
      include ActiveSupport::Testing::TimeHelpers

      def build
        Redmine::DefaultData::Loader.load("en") if Tracker.none?
        prepare_redmine
        create_people
        create_project
        create_versions
        create_tickets
        create_subproject
        create_subproject
        create_scope_query
        choose_settings
        hold_first_agenda
        close_ticket_after_the_agenda
        start_next_agenda
      end

      private

      def prepare_redmine
        Setting.default_language = "en"
        Setting.notified_events = [] # no mail from the demo
        User.where(admin: true).update_all(must_change_passwd: false)
        @manager_role = Role.find_by!(name: "Manager")
        @manager_role.add_permission!(*AGENDA_PERMISSIONS)
        @reader_role = Role.find_by(name: READER_ROLE_NAME) ||
                       Role.create!(name: READER_ROLE_NAME, permissions: %i[view_issues view_rubylode_agenda],
                                    issues_visibility: "default", users_visibility: "all")
        @closed_status = IssueStatus.where(is_closed: true).first!
        @open_status = IssueStatus.where(is_closed: false).order(:position).first!
        @priority = IssuePriority.default || IssuePriority.first!
      end

      def create_people
        @people = PEOPLE.to_h do |login, firstname, lastname|
          user = User.new(login: login, firstname: firstname, lastname: lastname, mail: "#{login}@example.com",
                          language: "en", must_change_passwd: false)
          user.password = user.password_confirmation = PASSWORD
          user.save!
          [login, user]
        end
        @alex = @people.fetch("alex")
        @sam = @people.fetch("sam")
        User.current = @alex
      end

      def create_project
        @project = Project.new(name: PROJECT_NAME, identifier: PROJECT_IDENTIFIER, is_public: false,
                               description: "A made-up project to try the agenda in.",
                               enabled_module_names: MODULES)
        @project.trackers = Tracker.all
        @project.save!
        Member.create!(project: @project, principal: @alex, roles: [@manager_role])
        Member.create!(project: @project, principal: @sam, roles: [@manager_role])
        Member.create!(project: @project, principal: @people.fetch("reader"), roles: [@reader_role])
      end

      def create_versions
        @release = Version.create!(project: @project, name: "Release 1", effective_date: Date.current + 14, status: "open")
        @backlog = Version.create!(project: @project, name: "Backlog", status: "open")
      end

      # Each ticket is made on the day it was "created" (travel_to), so created_on and updated_on come out right.
      # `closed_days_ago` is set with update_columns on top, as the spec of the story needs a close date of its own.
      def make_ticket(subject, version:, created_days_ago:, assignee: @alex, author: @alex, due_in: nil,
                      closed_days_ago: nil, private_ticket: false, project: @project)
        issue = nil
        travel_to(created_days_ago.days.ago.change(hour: 9)) do
          issue = Issue.new(project: project, tracker: Tracker.first, author: author, subject: subject,
                            fixed_version: version, assigned_to: assignee, priority: @priority,
                            status: closed_days_ago ? @closed_status : @open_status, is_private: private_ticket)
          issue.due_date = Date.current + due_in if due_in
          issue.save!
        end
        if closed_days_ago
          moment = closed_days_ago.days.ago.change(hour: 15)
          # Not update_columns: it adds the lock version to its condition, and saving a ticket has already raised
          # the stored one, so the write would silently change nothing.
          Issue.where(id: issue.id).update_all(closed_on: moment, updated_on: moment)
        end
        issue
      end

      def create_tickets
        @tickets = {}
        # Closed in the last week.
        make_ticket("Publish the release notes", version: @release, created_days_ago: 20, closed_days_ago: 1)
        make_ticket("Fix the export of the report", version: @release, created_days_ago: 21, closed_days_ago: 3, assignee: @sam)
        make_ticket("Update the install guide", version: @release, created_days_ago: 18, closed_days_ago: 5)
        make_ticket("Remove the unused settings page", version: @backlog, created_days_ago: 40, closed_days_ago: 2, assignee: @sam)
        # Created in the last week.
        make_ticket("Add a search box to the list", version: @release, created_days_ago: 1, assignee: @sam)
        make_ticket("Show the owner on the board", version: @release, created_days_ago: 2)
        make_ticket("Check the new colours", version: @release, created_days_ago: 4, assignee: @sam, author: @sam)
        make_ticket("Write the demo script", version: @release, created_days_ago: 6, author: @sam)
        # Open and overdue.
        make_ticket("Review the contract wording", version: @release, created_days_ago: 30, due_in: -5)
        make_ticket("Send the invoices", version: @release, created_days_ago: 28, due_in: -10, assignee: @sam)
        make_ticket("Renew the certificate", version: @release, created_days_ago: 35, due_in: -2)
        # Old tickets that three agenda lines point at; not touched since before the first agenda.
        @tickets[:first_open] = make_ticket("Decide the release date", version: @release, created_days_ago: 25, due_in: 14)
        @tickets[:second_open] = make_ticket("Plan the training session", version: @release, created_days_ago: 24,
                                             assignee: @sam, due_in: 10)
        @tickets[:third_open] = make_ticket("Collect feedback from the pilot group", version: @release, created_days_ago: 22)
        @tickets[:closed_later] = make_ticket("Order the printed handouts", version: @release, created_days_ago: 26)
        # Old and untouched in the backlog.
        ["Support a second language", "Add a dark theme", "Offer a mobile layout", "Export to a spreadsheet",
         "Allow tags on tickets", "Show a yearly summary"].each_with_index do |subject, index|
          make_ticket(subject, version: @backlog, created_days_ago: 90 + (index * 10), assignee: nil)
        end
        make_ticket("Budget notes for next year", version: @release, created_days_ago: 3, private_ticket: true)
      end

      # A small subproject with a few closed tickets, so the sidebar counts closed tickets per project.
      def create_subproject
        website = Project.new(name: "Demo website", identifier: "#{PROJECT_IDENTIFIER}-website", is_public: false,
                              parent_id: @project.id, inherit_members: true, enabled_module_names: %w[issue_tracking])
        website.trackers = Tracker.all
        website.save!
        launch = Version.create!(project: website, name: "Website launch", status: "open")
        make_ticket("Replace the photos on the home page", version: launch, created_days_ago: 12, closed_days_ago: 2, project: website)
        make_ticket("Fix the contact form", version: launch, created_days_ago: 9, closed_days_ago: 4, assignee: @sam, project: website)
        make_ticket("Write the privacy page", version: launch, created_days_ago: 5, project: website)
      end

      def create_scope_query
        @query = IssueQuery.new(name: "Without the backlog", project: @project, user: @alex,
                                visibility: Query::VISIBILITY_PUBLIC)
        @query.add_filter("fixed_version_id", "!", [@backlog.id.to_s])
        @query.save!
      end

      def choose_settings
        ProjectSetting.for(@project).update!(query_id: @query.id, kpi_url: "https://example.com/kpi-sheet",
                                             progress_url: "https://example.com/progress")
      end

      # Topics and lines are written on the day of the agenda, and the agenda is closed that afternoon.
      def hold_first_agenda
        morning = FIRST_AGENDA_DAYS_AGO.days.ago.change(hour: 10)
        travel_to(morning) do
          @first_agenda = Agenda.start_next(project: @project, user: @alex)
          status_topic = add_topic("Release 1 status", owner: @alex)
          review_topic = add_topic("Open tickets review", ticket: @tickets.fetch(:first_open))
          notes_topic = add_topic("Planning notes")
          add_line(status_topic, "Confirm the release date with the team")
          add_line(status_topic, "Agree the scope of Release 1", done: true)
          add_line(status_topic, @tickets.fetch(:first_open).subject, ticket: @tickets.fetch(:first_open))
          add_line(status_topic, @tickets.fetch(:second_open).subject, ticket: @tickets.fetch(:second_open))
          add_line(review_topic, @tickets.fetch(:closed_later).subject, ticket: @tickets.fetch(:closed_later))
          add_line(review_topic, "Check the overdue list")
          add_line(review_topic, @tickets.fetch(:third_open).subject, ticket: @tickets.fetch(:third_open))
          add_line(review_topic, "Send the notes to everyone", done: true)
          add_line(notes_topic, "Ask how big the backlog should be").park!
          add_line(notes_topic, "Look at the older tickets again")
        end
        travel_to(FIRST_AGENDA_DAYS_AGO.days.ago.change(hour: 11)) { @first_agenda.close!(@alex) }
      end

      def add_topic(title, owner: nil, ticket: nil)
        @first_agenda.topics.create!(title: title, owner_id: owner&.id, issue_id: ticket&.id)
      end

      def add_line(topic, text, done: false, ticket: nil)
        topic.lines.create!(agenda: topic.agenda, text: text, done: done, issue_id: ticket&.id)
      end

      # The handouts were printed, and the ticket closed three days after the agenda.
      def close_ticket_after_the_agenda
        moment = 3.days.ago.change(hour: 14)
        Issue.where(id: @tickets.fetch(:closed_later).id)
             .update_all(status_id: @closed_status.id, closed_on: moment, updated_on: moment)
      end

      # Starts the next agenda through the plugin, so carry-over runs, then adds one new line and changes one carried
      # line's ticket today, which takes that line out of the fold.
      def start_next_agenda
        agenda = Agenda.start_next(project: @project, user: @alex)
        status_topic = agenda.topics.active.find_by!(title: "Release 1 status")
        status_topic.lines.create!(agenda: agenda, text: "Book a room for the training session")
        ticket = Issue.find(@tickets.fetch(:second_open).id)
        ticket.init_journal(@sam, "The trainer can only do the second week.")
        ticket.save!
      end
    end
  end
end
