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
    belongs_to :agenda, class_name: "RubylodeAgenda::Agenda", inverse_of: :lines
    belongs_to :carried_from, class_name: "RubylodeAgenda::Line", optional: true

    # A line is a point (0), a sub-point (1) or a bullet under a sub-point (2).
    MAXIMUM_DEPTH = 2
    MAXIMUM_TEXT_LENGTH = 2000

    validates :text, presence: true, length: { maximum: MAXIMUM_TEXT_LENGTH }
    validates :depth, inclusion: { in: 0..MAXIMUM_DEPTH }
    validate :topic_belongs_to_the_agenda
    before_validation :take_the_last_position, on: :create
    before_save :stamp_edited_time

    scope :active, -> { where(deleted_at: nil) }
    scope :in_order, -> { order(:position, :id) }
    scope :shown, -> { active.where(parked_at: nil) }
    # What the next agenda carries: a note that is not done, or a line whose ticket is still open. A line whose ticket
    # is closed is finished, whatever its done flag says. Deleted and parked lines are never carried.
    scope :carryable, lambda {
      open_tickets = ::Issue.joins(:status).where(issue_statuses: { is_closed: false }).select(:id)
      shown.where(issue_id: nil, done: false).or(shown.where(issue_id: open_tickets))
    }

    # Every parked line of the project's agendas, the most recently parked first.
    def self.parked_for(project)
      active.joins(:agenda).where(rubylode_agenda_agendas: { project_id: project.id }).where.not(parked_at: nil)
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

      issue.nil? || issue.updated_on < agenda.period_start.in_time_zone
    end

    def park!
      update!(parked_at: Time.current)
    end

    # Brings a parked line into the open agenda, under the topic there with the title of the one it left; the topic is
    # made at the end when it is missing. Answers nil when the project has no open agenda, else the agenda and the
    # topic made (nil when one already existed).
    def unpark!
      open_agenda = Agenda.where(project_id: agenda.project_id, closed_at: nil).newest_first.first
      return nil unless open_agenda

      transaction do
        origin = topic
        target = open_agenda.topics.active.find_by(title: origin.title)
        made = target.nil?
        owner_id = owner_still_on_the_project(origin.owner_id, open_agenda)
        target ||= open_agenda.topics.create!(title: origin.title, owner_id: owner_id, issue_id: origin.issue_id)
        self.agenda_id = open_agenda.id
        self.topic_id = target.id
        self.position = target.lines.shown.maximum(:position).to_i + 1
        self.parked_at = nil
        self.depth = 0
        save!
        Unparked.new(open_agenda, made ? target : nil)
      end
    end

    Unparked = Struct.new(:agenda, :made_topic)

    # A topic made again takes the old owner only while that owner is still on the project.
    def owner_still_on_the_project(user_id, open_agenda)
      return nil unless user_id

      user_id if Project.find(open_agenda.project_id).users.active.exists?(id: user_id)
    end
    private :owner_still_on_the_project

    # Takes the typed text, line breaks and all. A text that is only "#123" links that ticket and takes its subject.
    # Answers false with the reason on the line when the ticket may not be linked.
    def assign_text(raw, viewer)
      number = TicketLink.ticket_number_alone(raw)
      if number
        return false unless assign_ticket(number, viewer)

        self.text = issue.subject
      else
        self.text = raw.to_s.gsub(/\r\n?/, "\n").strip
      end
      true
    end

    # The first line of the text names a ticket made from it; the rest describes it.
    def ticket_subject
      text.to_s.lines.first.to_s.strip.first(255)
    end

    def ticket_description
      text.to_s.lines.drop(1).join.strip
    end

    # Takes the depth asked for. A depth outside 0 to 2 is refused; a depth deeper than the place allows (one below the
    # line above, and 0 for the first line of the topic) is made the deepest allowed, so the person's indent still lands.
    def assign_depth(raw)
      requested = Integer(raw.to_s, exception: false)
      unless requested&.between?(0, MAXIMUM_DEPTH)
        errors.add(:depth, :inclusion)
        return false
      end

      self.depth = [requested, deepest_allowed].min
      true
    end

    # One below the line above this one in the topic, as the page shows it; 0 for the first line.
    def deepest_allowed
      others = topic.lines.shown.in_order.to_a.reject { |line| line.id == id }
      above = others.select { |line| comes_before?(line) }.last
      return 0 unless above

      [self.class.shown_depths(others).fetch(above.id) + 1, MAXIMUM_DEPTH].min
    end

    # The depth each line shows at, in the order given: its own depth, but never more than one below the line shown above
    # it. A gap (a parent deleted, parked, moved or left behind by carry-over) is closed here, at reading, and never
    # written back. Answers a hash from line id to depth.
    def self.shown_depths(lines)
      above = -1
      lines.to_h do |line|
        shown = line.depth.to_i.clamp(0, [above + 1, MAXIMUM_DEPTH].min)
        above = shown
        [line.id, shown]
      end
    end

    # The depth this line shows at among the rows it is shown with: the topic's open lines, or the fold of quiet ones,
    # which starts again at 0 so that a folded line never appears under a line it does not belong to.
    def shown_depth
      return 0 if topic.nil? || deleted? || parked?

      quiet_lines, other_lines = topic.lines.shown.includes(:issue, :agenda).in_order.partition(&:quiet?)
      sequence = quiet_lines.any? { |line| line.id == id } ? quiet_lines : other_lines
      self.class.shown_depths(sequence).fetch(id, 0)
    end

    # The nearest line above in the topic with a smaller depth than this one shows at; nil for a line at depth 0.
    def parent_line
      lines = topic.lines.shown.in_order.to_a
      depths = self.class.shown_depths(lines)
      own = depths.fetch(id, 0)
      lines.take_while { |line| line.id != id }.reverse.find { |line| depths.fetch(line.id) < own }
    end

    # Where a ticket made from this line takes its parent and version: the ticket of the parent line when the viewer may
    # see it, else the topic's.
    def ticket_source(viewer)
      parent_line&.visible_issue(viewer) || topic.visible_issue(viewer)
    end

    # Puts this new line right after the given line of the topic. The lines below move down one; only their position and
    # revision change, so somebody typing in one of them is not sent into a conflict. Answers the lines moved.
    def make_room_after!(above)
      self.position = above.position + 1
      topic.lines.active.where(position: position..).in_order.to_a.each do |line|
        line.update_columns(position: line.position + 1, revision: agenda.bump_revision!)
      end
    end

    def soft_delete!
      update!(deleted_at: Time.current)
    end

    # Puts the named lines of the topic in the order given and changes nothing else. Named lines already in the topic
    # share out the positions they hold now, so the lines not named (the folded ones) keep theirs and are not saved. A
    # named line from another topic of the same agenda takes the place after the named line before it in the request,
    # or the first place, and only the lines from there on move up by one. Answers the lines changed.
    def self.reorder!(topic, ids)
      siblings = topic.lines.active.in_order.to_a
      incoming = topic.agenda.lines.active.where(id: ids).where.not(topic_id: topic.id).to_a
      pool = siblings + incoming
      named = ids.filter_map { |id| pool.find { |line| line.id == id.to_i } }.uniq
      native = named & siblings
      positions = native.map(&:position).sort
      native.each_with_index { |line, index| line.position = positions[index] }
      (named - native).each { |line| place_incoming(topic, line, named, siblings) }
      keep_moved_depths_in_reach(siblings)
      transaction do
        siblings.filter_map do |line|
          next unless line.topic_id_changed? || line.position_changed? || line.depth_changed?

          line.save!
          line
        end
      end
    end

    def self.place_incoming(topic, line, named, siblings)
      before = named[0...named.index(line)].last
      line.topic_id = topic.id
      line.position = before ? before.position + 1 : [siblings.map(&:position).min.to_i, 1].max
      siblings.each { |sibling| sibling.position += 1 if sibling.position >= line.position }
      siblings << line
    end
    private_class_method :place_incoming

    # A moved line keeps its depth as far as its new place allows: at most one below the line now above it. Lines that
    # did not move are left as they are; the page closes any gap when it shows them.
    def self.keep_moved_depths_in_reach(siblings)
      above = -1
      siblings.select { |line| line.parked_at.nil? }.sort_by { |line| [line.position, line.id] }.each do |line|
        allowed = [above + 1, MAXIMUM_DEPTH].min
        line.depth = allowed if line.depth > allowed && (line.topic_id_changed? || line.position_changed?)
        above = [line.depth, allowed].min
      end
    end
    private_class_method :keep_moved_depths_in_reach

    private

    def comes_before?(line)
      ([line.position, line.id] <=> [position.to_i, id || Float::INFINITY]).negative?
    end

    def take_the_last_position
      return if position.to_i.positive? || topic.nil?

      self.position = topic.lines.active.maximum(:position).to_i + 1
    end

    def stamp_edited_time
      self.edited_at = Time.current if persisted? && will_save_change_to_text?
    end

    def topic_belongs_to_the_agenda
      errors.add(:topic_id, :invalid) if topic && topic.agenda_id != agenda_id
    end
  end
end
