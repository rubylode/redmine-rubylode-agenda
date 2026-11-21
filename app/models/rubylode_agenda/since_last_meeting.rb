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

module RubylodeAgenda
  # What the sidebar shows for one meeting. An open meeting is computed live; a closed one reads its counts and its
  # progress from the snapshot taken when it closed (or live, for a meeting closed before snapshots existed). The
  # closed-ticket list and the closed-per-person table are always live queries under the viewer's own visibility. "Before" is the previous meeting's
  # snapshot, when there is one.
  class SinceLastMeeting
    CLOSED_LIST_LIMIT = 10

    StageRow = Struct.new(:name, :before, :after, keyword_init: true)

    attr_reader :meeting

    def initialize(project:, viewer:, meeting:)
      @project = project
      @viewer = viewer
      @meeting = meeting
    end

    def from_snapshot?
      !meeting.open? && !snapshot.nil?
    end

    def snapshot
      meeting.snapshot
    end

    def as_of
      snapshot.taken_at.to_date if from_snapshot?
    end

    def previous_snapshot
      return @previous_snapshot if defined?(@previous_snapshot)

      @previous_snapshot = meeting.previous&.snapshot
    end

    def progress_after
      value = from_snapshot? ? snapshot.percent : reading.percent
      value&.round
    end

    def progress_before
      previous_snapshot&.percent&.round
    end

    def progress_available?
      !progress_after.nil?
    end

    # Points gained since the previous meeting, nil when either end is missing.
    def progress_change
      progress_after - progress_before if progress_after && progress_before
    end

    def stage_rows
      @stage_rows ||= begin
        before_by_version = (previous_snapshot&.stages || []).index_by { |stage| stage["version_id"] }
        after_stages.map do |stage|
          StageRow.new(name: stage["name"], before: before_by_version[stage["version_id"]], after: stage)
        end
      end
    end

    def numbers
      @numbers ||= from_snapshot? ? snapshot.numbers : live_numbers
    end

    # The previous meeting's stored numbers; empty when it has no snapshot.
    def previous_numbers
      previous_snapshot&.numbers || {}
    end

    # Always live under the viewer's own visibility, for an open meeting and a closed one alike.
    def closed_per_person
      @closed_per_person ||= Numbers.new(project: @project, viewer: @viewer, meeting: meeting).closed_per_person
    end

    def closed_issues
      @closed_issues ||= ClosedIssues.new(project: @project, viewer: @viewer, meeting: meeting)
    end

    private

    def reading
      @reading ||= ProgressReading.new(project: @project, viewer: @viewer, meeting: meeting)
    end

    def after_stages
      (from_snapshot? ? snapshot.stages : reading.stages) || []
    end

    def live_numbers
      Numbers.new(project: @project, viewer: @viewer, meeting: meeting).to_h
    end
  end
end
