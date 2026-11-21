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
    # What the next meeting carries: a note that is not finished, deleted or parked.
    scope :carryable, -> { active.where(done: false, parked_at: nil, issue_id: nil) }

    def deleted?
      deleted_at.present?
    end

    def parked?
      parked_at.present?
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
