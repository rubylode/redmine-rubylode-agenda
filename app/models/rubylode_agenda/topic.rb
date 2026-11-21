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
  class Topic < ActiveRecord::Base
    include Revisioned

    self.table_name = "rubylode_agenda_topics"

    belongs_to :meeting, class_name: "RubylodeAgenda::Meeting", inverse_of: :topics
    belongs_to :owner, class_name: "User", optional: true
    has_many :lines, class_name: "RubylodeAgenda::Line", foreign_key: :topic_id, inverse_of: :topic

    validates :title, presence: true, length: { maximum: 255 }
    before_validation :take_the_last_position, on: :create

    scope :active, -> { where(deleted_at: nil) }
    scope :in_order, -> { order(:position, :id) }

    def deleted?
      deleted_at.present?
    end

    # Marks the topic and its lines deleted and answers the lines that changed.
    def soft_delete!
      transaction do
        removed_lines = lines.active.to_a
        removed_lines.each { |line| line.update!(deleted_at: Time.current) }
        update!(deleted_at: Time.current)
        removed_lines
      end
    end

    # Rewrites the positions of the meeting's topics in the order given; unknown ids are ignored and topics not named
    # keep their relative order after the named ones. Answers the topics whose position changed.
    def self.reorder!(meeting, ids)
      topics = meeting.topics.active.in_order.to_a
      named = ids.filter_map { |id| topics.find { |topic| topic.id == id.to_i } }.uniq
      ordered = named + (topics - named)
      transaction do
        ordered.each_with_index.filter_map do |topic, index|
          topic.position = index + 1
          next unless topic.position_changed?

          topic.save!
          topic
        end
      end
    end

    private

    def take_the_last_position
      return if position.to_i.positive? || meeting.nil?

      self.position = meeting.topics.active.maximum(:position).to_i + 1
    end
  end
end
