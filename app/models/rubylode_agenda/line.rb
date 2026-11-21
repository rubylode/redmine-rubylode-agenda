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
  class Line < ActiveRecord::Base
    include Revisioned
    include TicketLink

    self.table_name = "rubylode_agenda_lines"

    belongs_to :topic, class_name: "RubylodeAgenda::Topic", inverse_of: :lines
    belongs_to :meeting, class_name: "RubylodeAgenda::Meeting", inverse_of: :lines
    belongs_to :carried_from, class_name: "RubylodeAgenda::Line", optional: true

    validates :text, presence: true
    validate :topic_belongs_to_the_meeting
    before_validation :take_the_last_position, on: :create
    before_save :stamp_edited_time

    scope :active, -> { where(deleted_at: nil) }
    scope :in_order, -> { order(:position, :id) }
    scope :shown, -> { active.where(parked_at: nil) }
    # What the next meeting carries: a note that is not done, or a line whose ticket is still open. A line whose ticket
    # is closed is finished, whatever its done flag says. Deleted and parked lines are never carried.
    scope :carryable, lambda {
      open_tickets = ::Issue.joins(:status).where(issue_statuses: { is_closed: false }).select(:id)
      shown.where(issue_id: nil, done: false).or(shown.where(issue_id: open_tickets))
    }

    # Every parked line of the project's meetings, the most recently parked first.
    def self.parked_for(project)
      active.joins(:meeting).where(rubylode_agenda_meetings: { project_id: project.id }).where.not(parked_at: nil)
            .includes(:topic, :issue).order(parked_at: :desc, id: :desc)
    end

    def deleted?
      deleted_at.present?
    end

    def parked?
      parked_at.present?
    end

    # Carried, never touched, and with no ticket that moved since the period began: nothing to say about it this time.
    def quiet?
      return false if carried_from_id.nil? || edited_at.present?

      issue.nil? || issue.updated_on < meeting.period_start.in_time_zone
    end

    def park!
      update!(parked_at: Time.current)
    end

    # Brings a parked line into the open meeting, under the topic there with the title of the one it left; the topic is
    # made at the end when it is missing. Answers nil when the project has no open meeting, else the meeting and the
    # topic made (nil when one already existed).
    def unpark!
      open_meeting = Meeting.where(project_id: meeting.project_id, closed_at: nil).newest_first.first
      return nil unless open_meeting

      transaction do
        origin = topic
        target = open_meeting.topics.active.find_by(title: origin.title)
        made = target.nil?
        owner_id = owner_still_on_the_project(origin.owner_id, open_meeting)
        target ||= open_meeting.topics.create!(title: origin.title, owner_id: owner_id, issue_id: origin.issue_id)
        self.meeting_id = open_meeting.id
        self.topic_id = target.id
        self.position = target.lines.shown.maximum(:position).to_i + 1
        self.parked_at = nil
        save!
        Unparked.new(open_meeting, made ? target : nil)
      end
    end

    Unparked = Struct.new(:meeting, :made_topic)

    # A topic made again takes the old owner only while that owner is still on the project.
    def owner_still_on_the_project(user_id, open_meeting)
      return nil unless user_id

      user_id if Project.find(open_meeting.project_id).users.active.exists?(id: user_id)
    end
    private :owner_still_on_the_project

    # Takes the typed text. A text that is only "#123" links that ticket and takes its subject. Answers false with the
    # reason on the line when the ticket may not be linked.
    def assign_text(raw, viewer)
      number = TicketLink.ticket_number_alone(raw)
      if number
        return false unless assign_ticket(number, viewer)

        self.text = issue.subject
      else
        self.text = raw.to_s.strip
      end
      true
    end

    def soft_delete!
      update!(deleted_at: Time.current)
    end

    # Rewrites the positions of the topic's lines in the order given. A named line from another topic of the same
    # meeting moves here. Lines not named keep their relative order after the named ones. Answers the lines changed.
    def self.reorder!(topic, ids)
      siblings = topic.lines.active.in_order.to_a
      incoming = topic.meeting.lines.active.where(id: ids).to_a
      pool = (siblings + incoming).uniq
      named = ids.filter_map { |id| pool.find { |line| line.id == id.to_i } }.uniq
      ordered = named + (siblings - named)
      transaction do
        ordered.each_with_index.filter_map do |line, index|
          line.topic_id = topic.id
          line.position = index + 1
          next unless line.topic_id_changed? || line.position_changed?

          line.save!
          line
        end
      end
    end

    private

    def take_the_last_position
      return if position.to_i.positive? || topic.nil?

      self.position = topic.lines.active.maximum(:position).to_i + 1
    end

    def stamp_edited_time
      self.edited_at = Time.current if persisted? && will_save_change_to_text?
    end

    def topic_belongs_to_the_meeting
      errors.add(:topic_id, :invalid) if topic && topic.meeting_id != meeting_id
    end
  end
end
