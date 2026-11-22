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

# Builds the tickets, agendas and the Progress stand-in the sidebar tests need. Every date is written out by the test.
module RubylodeAgendaSidebarHelpers
  CLOSED_STATUS_ID = 5

  # The same shape as RubylodeProgress::ProjectProgress: built with project:, viewer:, answering percent and stages.
  # A test sets what the next readings say through the class attributes.
  class ProgressStandIn
    Stage = Struct.new(:version, :number, :steps, :state, keyword_init: true) do
      def step_count = steps.size
      def done_step_count = steps.count(&:done?)
    end
    Step = Struct.new(:done?)

    class << self
      attr_accessor :percent, :stages
    end

    def self.stage(version, done:, total:, state: :current)
      steps = Array.new(total) { |index| Step.new(index < done) }
      Stage.new(version: version, number: 1, steps: steps, state: state)
    end

    def initialize(project:, viewer:, settings: nil, focused_stage_id: nil)
      @project = project
      @viewer = viewer
    end

    def percent = self.class.percent

    def stages = self.class.stages
  end

  def define_progress_stand_in(percent:, stages: [])
    ProgressStandIn.percent = percent
    ProgressStandIn.stages = stages
    Object.const_set(:RubylodeProgress, Module.new) unless defined?(::RubylodeProgress)
    ::RubylodeProgress.const_set(:ProjectProgress, ProgressStandIn) unless defined?(::RubylodeProgress::ProjectProgress)
  end

  def remove_progress_stand_in
    Object.send(:remove_const, :RubylodeProgress) if defined?(::RubylodeProgress)
  end

  def build_ticket(project: @project, subject: "Ticket", closed: false, created_on: nil, closed_on: nil, due_date: nil,
                   assigned_to_id: nil, version: nil, is_private: false)
    tracker = Tracker.find(1)
    project.trackers << tracker unless project.trackers.include?(tracker)
    project.enable_module!(:issue_tracking)
    issue = Issue.generate!(project: project, tracker: tracker, subject: subject, author: User.find(2))
    columns = { is_private: is_private, assigned_to_id: assigned_to_id, fixed_version_id: version&.id, due_date: due_date,
                closed_on: closed_on }
    columns[:status_id] = CLOSED_STATUS_ID if closed
    columns[:created_on] = created_on if created_on
    issue.update_columns(columns)
    issue
  end

  def build_version(name, project: @project)
    Version.create!(project: project, name: name)
  end

  def create_agenda(held_on:, period_start:, period_end:, closed_at: nil)
    RubylodeAgenda::Agenda.create!(project_id: @project.id, held_on: held_on, period_start: period_start,
                                    period_end: period_end, closed_at: closed_at, closed_by_id: (2 if closed_at))
  end

  def sidebar_number(key)
    css_select("aside.rubylode-agenda-sidebar .rubylode-agenda-number[data-kpi='#{key}'] .rubylode-agenda-number-value").first&.text&.strip
  end

  def sidebar_previous_number(key)
    css_select("aside.rubylode-agenda-sidebar .rubylode-agenda-number[data-kpi='#{key}'] .rubylode-agenda-number-previous").first&.text&.strip
  end

  def closed_issue_ids_in_sidebar
    css_select("aside.rubylode-agenda-sidebar li.rubylode-agenda-closed-issue").map { |item| item["data-issue-id"].to_i }
  end

  def close_agenda(agenda)
    post agendas_path("/#{agenda.id}/close")
    assert_response :redirect
  end
end

class RubylodeAgendaSidebarTest < RubylodeAgendaIntegrationTest
  include RubylodeAgendaSidebarHelpers

  fixtures :trackers, :projects_trackers, :issue_statuses, :enumerations, :workflows, :queries, :versions

  def setup
    super
    Issue.delete_all
    Version.where(project_id: 1).delete_all
  end

  def teardown
    remove_progress_stand_in
    super
  end
end
