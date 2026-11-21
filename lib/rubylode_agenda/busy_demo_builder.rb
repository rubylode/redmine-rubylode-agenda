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

require_relative "demo_data"

module RubylodeAgenda
  # A second, busy demo project for the throwaway Redmine in docker-compose.yml, run by
  # `rake redmine_rubylode_agenda:demo_busy` (bin/demo seed-busy). Everything is made up.
  #
  # "Lighthouse" holds a thousand tickets: a long backlog nobody has touched, and five release versions with tickets
  # closed over the past ten weeks, open ones with recent activity, new and overdue ones. Tickets go in with bulk
  # inserts and their dates are set by hand, so a thousand take seconds. Ten weekly meetings follow, made the way the
  # small demo makes its two: nine are closed on their own day under travel_to (so each has a real snapshot) and the
  # tenth is started today through Meeting.start_next, so lines are carried from week to week by the plugin itself.
  # Deterministic: a fixed random seed. Safe to run twice: it does nothing when the project exists.
  class BusyDemoBuilder < DemoData::Builder
    PROJECT_NAME = "Lighthouse".freeze
    PROJECT_IDENTIFIER = "lighthouse".freeze
    RANDOM_SEED = 20_261_121
    MODULES = (DemoData::MODULES + %w[time_tracking]).freeze
    BACKLOG_COUNT = 620
    # Tickets closed per week, the first number being the last seven days, the last the week of the first meeting.
    CLOSED_PER_WEEK = [20, 28, 22, 35, 18, 30, 26, 24, 20, 27].freeze
    ACTIVE_OPEN_COUNT = 90
    OVERDUE_COUNT = 25
    NEW_THIS_WEEK_COUNT = 40
    PRIVATE_COUNT = 8
    PARENT_WITH_TWO_SUBTASKS = 12
    PARENT_WITH_ONE_SUBTASK = 12
    PAST_MEETING_COUNT = 9
    PARKED_PER_MEETING = [2, 2, 1, 2, 2, 1, 2, 1, 2].freeze
    RELEASE_NAMES = ["Release 4.1", "Release 4.2", "Release 4.3", "Release 4.4", "Release 4.5"].freeze
    EXTRA_PEOPLE = [
      ["jordan", "Jordan", "Ellis"], ["taylor", "Taylor", "Brooks"], ["morgan", "Morgan", "Hale"],
      ["casey", "Casey", "Lane"], ["robin", "Robin", "Frost"], ["quinn", "Quinn", "Archer"],
      ["avery", "Avery", "Stone"], ["drew", "Drew", "Mason"]
    ].freeze
    DEVELOPER_ROLE_NAME = "Developer".freeze

    VERBS = %w[Fix Update Review Add Remove Check Write Rework Test Document Merge Rename Split Simplify Move].freeze
    ADJECTIVES = %w[weekly shared old new main second default hidden slow narrow wide short monthly].freeze
    NOUNS = ["report", "export", "dashboard", "search box", "login page", "settings page", "email text", "import",
             "filter", "price list", "calendar", "upload form", "help page", "sort order", "summary", "label"].freeze
    NOTE_TEXTS = ["Waiting for an answer from the team.", "Checked it again; still happens on the second try.",
                  "Moved to the next release.", "A first draft is attached to the shared folder.",
                  "Needs a short call before it can go on.", "Looks fine to me, please have a look.",
                  "Split the work in two parts.", "Asked for a screenshot of the problem.",
                  "Done on my side, ready to be checked.", "Postponed until the numbers are in."].freeze
    TIME_COMMENTS = ["Reading and testing", "Call about the details", "First version", "Checking the result",
                     "Writing it up"].freeze
    MEETING_VERBS = %w[Confirm Send Book Agree Share Prepare Update Collect Draft Check].freeze
    MEETING_OBJECTS = ["the release checklist", "the support rota", "the budget sheet", "the demo script",
                       "the test report", "the vendor contract", "the install guide", "the training dates",
                       "the survey results", "the roadmap draft", "the status report", "the access list"].freeze

    # Topics every meeting draws from; the first two are owned, the next two point at a ticket.
    TOPICS = [
      { title: "Release 4.5 status", owner_login: "alex" },
      { title: "Open tickets review", ticket: :first_topic_ticket },
      { title: "Backlog grooming", ticket: :second_topic_ticket },
      { title: "Supplies and orders", owner_login: "sam" },
      { title: "Team notes" },
      { title: "Questions for next week" }
    ].freeze
    # Notes that are never finished, written in the given meeting (1 is the oldest) and carried ever since. A line with
    # a `ticket_index` points at an old, untouched backlog ticket.
    STUCK_LINES = [
      { meeting: 1, topic: "Supplies and orders", text: "Decide who owns the vendor contract" },
      { meeting: 2, topic: "Team notes", text: "Agree a naming scheme for the releases" },
      { meeting: 2, topic: "Backlog grooming", text: "Revisit the shared calendar request", ticket_index: 0 },
      { meeting: 3, topic: "Supplies and orders", text: "Ask finance about the licence renewal" },
      { meeting: 4, topic: "Release 4.5 status", text: "Find a date for the training day" },
      { meeting: 4, topic: "Backlog grooming", text: "Decide on the old import tool", ticket_index: 1 },
      { meeting: 5, topic: "Team notes", text: "Clarify who approves the changes" },
      { meeting: 5, topic: "Team notes", text: "Look at the support rota" },
      { meeting: 5, topic: "Backlog grooming", text: "Clear the oldest requests", ticket_index: 2 },
      { meeting: 6, topic: "Questions for next week", text: "Write down the handover steps" },
      { meeting: 6, topic: "Backlog grooming", text: "Check the old export format" },
      { meeting: 7, topic: "Questions for next week", text: "Collect questions for the vendor" },
      { meeting: 7, topic: "Open tickets review", text: "Rethink the printing option", ticket_index: 3 },
      { meeting: 8, topic: "Team notes", text: "Review the meeting length" }
    ].freeze
    ACTIVE_LINE_TICKET_COUNT = 8
    FIRST_ACTIVE_LINES_MEETING = 8
    CURRENT_NEW_NOTE_COUNT = 8
    CURRENT_NEW_TICKET_LINE_COUNT = 2

    # Returns :built, or :already_loaded when the project is there already. The small demo comes first (its people and
    # roles are reused), unless it is loaded already.
    def self.build_once
      return :already_loaded if Project.exists?(identifier: PROJECT_IDENTIFIER)

      previous_user = User.current
      DemoData.build
      ActiveRecord::Base.transaction { new.build }
      :built
    ensure
      User.current = previous_user
    end

    def build
      @random = Random.new(RANDOM_SEED)
      @today = Date.current
      @now = Time.current
      prepare_redmine
      load_people
      create_project
      create_versions
      insert_tickets
      make_subtasks
      insert_notes_and_time
      create_scope_query
      choose_settings
      hold_past_meetings
      start_current_meeting
    end

    private

    def load_people
      @people = DemoData::PEOPLE.to_h { |login, *| [login, User.find_by!(login: login)] }
      @alex = @people.fetch("alex")
      @sam = @people.fetch("sam")
      @developer_role = Role.find_by!(name: DEVELOPER_ROLE_NAME)
      EXTRA_PEOPLE.each do |login, firstname, lastname|
        user = User.new(login: login, firstname: firstname, lastname: lastname, mail: "#{login}@example.com",
                        language: "en", must_change_passwd: false)
        user.password = user.password_confirmation = DemoData::PASSWORD
        user.save!
        @people[login] = user
      end
      @workers = @people.values_at(*EXTRA_PEOPLE.map(&:first)) + [@alex, @sam]
      User.current = @alex
    end

    def create_project
      @project = Project.new(name: PROJECT_NAME, identifier: PROJECT_IDENTIFIER, is_public: false,
                             description: "A made-up project with a long backlog, to try the agenda on a busy tracker.",
                             enabled_module_names: MODULES)
      @project.trackers = Tracker.all
      @project.save!
      Member.create!(project: @project, principal: @alex, roles: [@manager_role])
      Member.create!(project: @project, principal: @sam, roles: [@manager_role])
      Member.create!(project: @project, principal: @people.fetch("reader"), roles: [@reader_role])
      EXTRA_PEOPLE.each { |login, *| Member.create!(project: @project, principal: @people.fetch(login), roles: [@developer_role]) }
    end

    def create_versions
      @backlog = Version.create!(project: @project, name: "Backlog", status: "open")
      @releases = RELEASE_NAMES.each_with_index.map do |name, index|
        Version.create!(project: @project, name: name, effective_date: @today + ((index - 2) * 30),
                        status: index.zero? ? "closed" : "open")
      end
    end

    # ---- tickets ----

    def insert_tickets
      @drafts = backlog_drafts + closed_drafts + active_open_drafts + new_drafts
      rows = @drafts.map { |draft| draft.fetch(:row) }
      rows.each_slice(250) { |slice| Issue.insert_all(slice, record_timestamps: false) }
      ids = Issue.where(project_id: @project.id).order(:id).pluck(:id)
      @drafts.zip(ids) { |draft, id| draft[:id] = id }
      Issue.where(project_id: @project.id).update_all("root_id = id")
      @ids_by_kind = @drafts.group_by { |draft| draft.fetch(:kind) }.transform_values { |group| group.map { |draft| draft.fetch(:id) } }
      @draft_by_id = @drafts.to_h { |draft| [draft.fetch(:id), draft] }
      @first_topic_ticket, @second_topic_ticket = @ids_by_kind.fetch(:active_open).values_at(20, 21)
    end

    def draft(kind, version:, created_on:, updated_on:, status:, closed_on: nil, due_date: nil, assignee: nil,
              is_private: false)
      subject = "#{VERBS.sample(random: @random)} the #{ADJECTIVES.sample(random: @random)} #{NOUNS.sample(random: @random)}"
      row = {
        project_id: @project.id, tracker_id: @trackers_for_tickets.sample(random: @random).id, subject: subject,
        description: nil, status_id: status.id, priority_id: random_priority.id, author_id: @workers.sample(random: @random).id,
        assigned_to_id: assignee&.id, fixed_version_id: version.id, category_id: nil, due_date: due_date, start_date: nil,
        estimated_hours: nil, done_ratio: status.is_closed? ? 100 : 0, is_private: is_private, lock_version: 0,
        parent_id: nil, root_id: nil, lft: 1, rgt: 2, created_on: created_on, updated_on: updated_on, closed_on: closed_on
      }
      { kind: kind, row: row, subject: subject, created_on: created_on, updated_on: updated_on, closed_on: closed_on }
    end

    def random_priority
      @priorities ||= IssuePriority.order(:position).to_a
      weights = [2, 6, 3, 1, 1].first(@priorities.size)
      @priorities[weighted_index(weights)]
    end

    def weighted_index(weights)
      roll = @random.rand(weights.sum)
      weights.each_with_index { |weight, index| return index if (roll -= weight).negative? }
      weights.size - 1
    end

    def moment_on(date, from_hour: 8, to_hour: 17)
      [date.in_time_zone + @random.rand((from_hour * 3600)..(to_hour * 3600)).seconds, @now - 60].min
    end

    def assignee_for_closed
      @closed_pool ||= @workers.each_with_index.flat_map { |person, index| [person] * (@workers.size - index) }
      @closed_pool.sample(random: @random)
    end

    def open_status
      [@statuses_by_name.fetch("New"), @statuses_by_name.fetch("In Progress"), @statuses_by_name.fetch("Feedback"),
       @statuses_by_name.fetch("Resolved")][weighted_index([4, 4, 2, 1])]
    end

    def backlog_drafts
      @trackers_for_tickets = Tracker.all.to_a
      @statuses_by_name = IssueStatus.all.index_by(&:name)
      overdue_indexes = (0...BACKLOG_COUNT).to_a.sample(110, random: @random)
      Array.new(BACKLOG_COUNT) do |index|
        created_on = moment_on(@today - @random.rand(90..900))
        status = @random.rand < 0.85 ? @statuses_by_name.fetch("New") : @statuses_by_name.fetch("Feedback")
        due_date = @today - @random.rand(20..400) if overdue_indexes.include?(index)
        draft(:backlog, version: @backlog, created_on: created_on, updated_on: created_on, status: status,
                        due_date: due_date, assignee: (@random.rand < 0.7 ? @workers.sample(random: @random) : nil))
      end
    end

    def closed_drafts
      CLOSED_PER_WEEK.each_with_index.flat_map do |count, week|
        release = @releases[[[(9 - week) / 2, 0].max, 4].min]
        Array.new(count) do
          closed_on = moment_on(@today - ((7 * week) + @random.rand(0..6)))
          created_on = moment_on((closed_on - @random.rand(2..60).days).to_date)
          status = @statuses_by_name.fetch(@random.rand < 0.92 ? "Closed" : "Rejected")
          draft(:closed, version: release, created_on: created_on, updated_on: closed_on, closed_on: closed_on,
                         status: status, assignee: assignee_for_closed).merge(week: week)
        end
      end
    end

    # Open for a while, with activity in the last two weeks. The first ones changed in the last five days (the agenda
    # points at them), the next ones are overdue, a few are private.
    def active_open_drafts
      overdue_from = 30
      Array.new(ACTIVE_OPEN_COUNT) do |index|
        created_on = moment_on(@today - @random.rand(14..100))
        updated_days_ago = index < 30 ? @random.rand(0..4) : @random.rand(0..13)
        updated_on = [moment_on(@today - updated_days_ago), created_on].max
        due_date = if (overdue_from...(overdue_from + OVERDUE_COUNT)).cover?(index)
                     @today - @random.rand(1..45)
                   elsif @random.rand < 0.5
                     @today + @random.rand(3..60)
                   end
        private_ticket = index >= (ACTIVE_OPEN_COUNT - PRIVATE_COUNT)
        draft(:active_open, version: @releases[1 + weighted_index([1, 3, 3, 3])], created_on: created_on,
                            updated_on: updated_on, status: open_status, due_date: due_date, is_private: private_ticket,
                            assignee: (@random.rand < 0.88 ? @workers.sample(random: @random) : nil))
      end
    end

    def new_drafts
      Array.new(NEW_THIS_WEEK_COUNT) do
        created_on = moment_on(@today - @random.rand(0..6))
        draft(:new_this_week, version: @releases[3 + @random.rand(0..1)], created_on: created_on, updated_on: created_on,
                              status: @statuses_by_name.fetch("New"),
                              due_date: (@today + @random.rand(5..45) if @random.rand < 0.4),
                              assignee: (@random.rand < 0.8 ? @workers.sample(random: @random) : nil))
      end
    end

    # Nested set columns by hand: a parent spans its children, each child sits inside it.
    def make_subtasks
      parents = @ids_by_kind.fetch(:active_open).first(PARENT_WITH_TWO_SUBTASKS + PARENT_WITH_ONE_SUBTASK)
      children = @ids_by_kind.fetch(:new_this_week).dup
      parents.each_with_index do |parent_id, index|
        child_ids = children.shift(index < PARENT_WITH_TWO_SUBTASKS ? 2 : 1)
        Issue.where(id: parent_id).update_all(root_id: parent_id, lft: 1, rgt: 2 + (2 * child_ids.size))
        child_ids.each_with_index do |child_id, position|
          Issue.where(id: child_id).update_all(parent_id: parent_id, root_id: parent_id, lft: 2 + (2 * position),
                                               rgt: 3 + (2 * position))
        end
      end
    end

    # Notes and logged time: the tickets the agenda points at get some for certain, the rest at random. A note falls
    # between the creation and the last change of its ticket.
    def insert_notes_and_time
      pointed_at = @ids_by_kind.fetch(:backlog).first(4) + @ids_by_kind.fetch(:active_open).first(ACTIVE_LINE_TICKET_COUNT)
      journal_rows = []
      time_rows = []
      @drafts.each do |entry|
        pointed = pointed_at.include?(entry.fetch(:id))
        kind = entry.fetch(:kind)
        journal_rows.concat(note_rows(entry)) if pointed || (kind == :backlog ? @random.rand < 0.03 : @random.rand < 0.18)
        time_rows.concat(time_rows_for(entry)) if kind != :backlog && (pointed || @random.rand < 0.35)
      end
      Journal.insert_all(journal_rows, record_timestamps: false) if journal_rows.any?
      TimeEntry.insert_all(time_rows, record_timestamps: false) if time_rows.any?
    end

    def note_rows(entry)
      count = @random.rand(1..3)
      Array.new(count) do
        span = [(entry.fetch(:updated_on) - entry.fetch(:created_on)).to_i, 0].max
        { journalized_id: entry.fetch(:id), journalized_type: "Issue", user_id: @workers.sample(random: @random).id,
          notes: NOTE_TEXTS.sample(random: @random), private_notes: false, updated_on: nil, updated_by_id: nil,
          created_on: entry.fetch(:created_on) + @random.rand(0..span).seconds }
      end
    end

    def time_rows_for(entry)
      @activity ||= TimeEntryActivity.order(:position).first!
      Array.new(@random.rand(1..3)) do
        spent_on = [entry.fetch(:created_on).to_date + @random.rand(0..10), @today].min
        person = @workers.sample(random: @random)
        { project_id: @project.id, user_id: person.id, author_id: person.id, issue_id: entry.fetch(:id),
          hours: (@random.rand(1..16) * 0.25), comments: TIME_COMMENTS.sample(random: @random), activity_id: @activity.id,
          spent_on: spent_on, tyear: spent_on.year, tmonth: spent_on.month, tweek: spent_on.cweek,
          created_on: spent_on.in_time_zone + 15.hours, updated_on: spent_on.in_time_zone + 15.hours }
      end
    end

    # ---- the saved query and the settings ----

    def create_scope_query
      @query = IssueQuery.new(name: "Current work", project: @project, user: @alex, visibility: Query::VISIBILITY_PUBLIC)
      @query.filters = {} # a new query starts with the filter "open tickets only", which would hide every closed ticket
      @query.add_filter("fixed_version_id", "!", [@backlog.id.to_s])
      @query.save!
    end

    def choose_settings
      ProjectSetting.for(@project).update!(query_id: @query.id, kpi_url: "https://example.com/kpi-sheet",
                                           progress_url: "https://example.com/progress")
    end

    # ---- meetings ----

    # Nine weekly meetings, held 9 to 1 weeks ago. Each is started on its day (so the lines of the one before are
    # carried by the plugin) and closed that afternoon, which takes its snapshot.
    def hold_past_meetings
      @closed_ticket_cursor = Hash.new(0)
      PAST_MEETING_COUNT.times do |index|
        number = index + 1
        held_on = @today - (7 * (PAST_MEETING_COUNT + 1 - number))
        meeting = nil
        travel_to(held_on.in_time_zone.change(hour: 10)) do
          meeting = Meeting.start_next(project: @project, user: @alex)
          write_past_meeting(meeting, number)
        end
        travel_to(held_on.in_time_zone.change(hour: 16)) { meeting.close!(@alex) }
      end
    end

    def write_past_meeting(meeting, number)
      STUCK_LINES.select { |stuck| stuck.fetch(:meeting) == number }.each do |stuck|
        ticket_id = stuck[:ticket_index] && @ids_by_kind.fetch(:backlog).fetch(stuck.fetch(:ticket_index))
        add_line(meeting, stuck.fetch(:topic), stuck.fetch(:text), ticket_id: ticket_id)
      end
      write_filler_lines(meeting, number)
      return if number < FIRST_ACTIVE_LINES_MEETING

      first = (number - FIRST_ACTIVE_LINES_MEETING) * (ACTIVE_LINE_TICKET_COUNT / 2)
      @ids_by_kind.fetch(:active_open).slice(first, ACTIVE_LINE_TICKET_COUNT / 2).each do |ticket_id|
        add_line(meeting, "Open tickets review", @draft_by_id.fetch(ticket_id).fetch(:subject), ticket_id: ticket_id)
      end
    end

    # One line in each topic: a few done, a few parked, the rest about tickets closed in the meeting's week.
    def write_filler_lines(meeting, number)
      titles = TOPICS.map { |topic| topic.fetch(:title) }
      titles = titles.first(5) if number.even?
      parked_count = PARKED_PER_MEETING.fetch(number - 1)
      kinds = ([:parked] * parked_count) + ([:done] * 3) + ([:closed_ticket] * 3)
      titles.rotate(number % titles.size).zip(kinds).each do |title, kind|
        case kind
        when :parked then add_line(meeting, title, made_up_text).park!
        when :done then add_line(meeting, title, made_up_text, done: true)
        else
          ticket_id = next_closed_ticket(10 - number)
          add_line(meeting, title, @draft_by_id.fetch(ticket_id).fetch(:subject), ticket_id: ticket_id)
        end
      end
    end

    def next_closed_ticket(week)
      @closed_by_week ||= @drafts.select { |entry| entry.fetch(:kind) == :closed }.group_by { |entry| entry.fetch(:week) }
      entry = @closed_by_week.fetch(week).fetch(@closed_ticket_cursor[week])
      @closed_ticket_cursor[week] += 1
      entry.fetch(:id)
    end

    def made_up_text
      @used_texts ||= []
      loop do
        text = "#{MEETING_VERBS.sample(random: @random)} #{MEETING_OBJECTS.sample(random: @random)}"
        next if @used_texts.include?(text)

        @used_texts << text
        return text
      end
    end

    def topic_for(meeting, title)
      meeting.topics.active.find_by(title: title) || begin
        definition = TOPICS.find { |topic| topic.fetch(:title) == title }
        owner = definition[:owner_login] && @people.fetch(definition.fetch(:owner_login))
        ticket_id = definition[:ticket] && instance_variable_get("@#{definition.fetch(:ticket)}")
        meeting.topics.create!(title: title, owner_id: owner&.id, issue_id: ticket_id)
      end
    end

    def add_line(meeting, title, text, done: false, ticket_id: nil)
      topic_for(meeting, title).lines.create!(meeting: meeting, text: text, done: done, issue_id: ticket_id)
    end

    # Started today through the plugin, so the carry-over runs for real. New notes and two lines about new tickets are
    # added, and two of the carried lines are reworded, which takes them out of the fold.
    def start_current_meeting
      meeting = Meeting.start_next(project: @project, user: @alex)
      titles = TOPICS.map { |topic| topic.fetch(:title) }
      CURRENT_NEW_NOTE_COUNT.times do |index|
        add_line(meeting, titles.fetch(index % titles.size), made_up_text, done: index < 2)
      end
      @ids_by_kind.fetch(:new_this_week).first(CURRENT_NEW_TICKET_LINE_COUNT).each do |ticket_id|
        add_line(meeting, "Release 4.5 status", @draft_by_id.fetch(ticket_id).fetch(:subject), ticket_id: ticket_id)
      end
      reworded = meeting.lines.active.where(text: ["Look at the support rota", "Find a date for the training day"])
      reworded.each { |line| line.update!(text: "#{line.text} with the whole team") }
    end
  end
end
