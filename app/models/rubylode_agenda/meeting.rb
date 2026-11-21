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
  class Meeting < ActiveRecord::Base
    self.table_name = "rubylode_agenda_meetings"

    FIRST_PERIOD_DAYS = 7

    belongs_to :project
    belongs_to :closed_by, class_name: "User", optional: true
    has_many :topics, class_name: "RubylodeAgenda::Topic", foreign_key: :meeting_id, inverse_of: :meeting
    has_many :lines, class_name: "RubylodeAgenda::Line", foreign_key: :meeting_id, inverse_of: :meeting

    validates :project_id, :held_on, :period_start, :period_end, presence: true
    validate :period_must_not_end_before_it_starts

    scope :newest_first, -> { order(held_on: :desc, id: :desc) }

    def self.current_for(project)
      where(project_id: project.id, closed_at: nil).newest_first.first || where(project_id: project.id).newest_first.first
    end

    # Closes whatever is open, then holds a new meeting today whose period runs from the previous meeting's date.
    def self.start_next(project:, user:, today: Date.current)
      transaction do
        previous = where(project_id: project.id).newest_first.first
        where(project_id: project.id, closed_at: nil).each { |open_meeting| open_meeting.close!(user) }
        period_start = previous ? [previous.held_on, today].min : today - FIRST_PERIOD_DAYS
        meeting = create!(project_id: project.id, held_on: today, period_start: period_start, period_end: today)
        CarryOver.new(from: previous, to: meeting).call if previous
        meeting
      end
    end

    def open?
      closed_at.nil?
    end

    def close!(user, at: Time.current)
      update!(closed_at: at, closed_by_id: user.id)
    end

    # One atomic increment, read back inside the caller's transaction.
    def bump_revision!
      self.class.where(id: id).update_all("revision = revision + 1")
      self.revision = self.class.where(id: id).pick(:revision)
      clear_attribute_changes([:revision])
      revision
    end

    private

    def period_must_not_end_before_it_starts
      return unless period_start && period_end && period_end < period_start

      errors.add(:period_end, :greater_than_start_date)
    end
  end
end
