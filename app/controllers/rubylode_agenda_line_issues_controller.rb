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

# The ticket behind a line: opened in place, given a note, or made from the line. Redmine's own rules decide what the
# person may do to the ticket; the agenda permission only lets them reach this page.
class RubylodeAgendaLineIssuesController < RubylodeAgendaBaseController
  before_action :find_line

  def show
    @issue = visible_ticket or return render_404
    render_fragment
  end

  def new
    return deny_access unless User.current.allowed_to?(:add_issues, @project)

    @ticket_source = @line.ticket_source(User.current)
    @draft = Issue.new(project: @project, author: User.current)
    @trackers = @draft.allowed_target_trackers(User.current)
    return deny_access if @trackers.empty?

    @draft.tracker = @trackers.first
    @assignees = @project.assignable_users(@draft.tracker)
    @versions = @draft.assignable_versions
    @candidates = RubylodeAgenda::TicketPicker.new(agenda: @line.agenda, viewer: User.current).candidates
    @owner_id = @line.topic.owner_id if @assignees.any? { |user| user.id == @line.topic.owner_id }
    @version_id = @ticket_source&.fixed_version_id if @versions.any? { |version| version.id == @ticket_source&.fixed_version_id }
    render partial: "rubylode_agenda_line_issues/new", formats: [:html], layout: false
  end

  def create
    return deny_access unless User.current.allowed_to?(:add_issues, @project)
    return render_message(:already_linked) if @line.issue_id

    ticket = Issue.new(project: @project, author: User.current)
    return render_message(:tracker_not_offered) unless assign_ticket_attributes(ticket)

    Issue.transaction do
      raise ActiveRecord::Rollback unless ticket.save

      @line.lock_version = params[:lock_version] if params[:lock_version].present?
      @line.update!(issue_id: ticket.id)
    end
    return render_failure(ticket) if ticket.new_record?

    render_envelope(@line.agenda_id, lines: [@line])
  end

  def notes
    @issue = visible_ticket or return render_404
    return deny_access unless @issue.notes_addable?(User.current)

    text = params[:notes].to_s.strip
    return render_message(:note_blank) if text.empty?

    @issue.init_journal(User.current)
    attributes = { "notes" => text }
    attributes["private_notes"] = params[:private_notes] if params.key?(:private_notes)
    @issue.safe_attributes = attributes
    return render_failure(@issue) unless @issue.save

    render_fragment
  end

  # The fields of a ticket the change form may offer. Which of them it does offer is Redmine's call: a field the person
  # may not change (no permission, read-only by workflow, derived percent done) is not a safe attribute and is left out.
  CHANGEABLE_FIELDS = %w[status_id assigned_to_id priority_id fixed_version_id due_date done_ratio].freeze

  def edit
    @issue = visible_ticket or return render_404
    return deny_access unless @issue.editable?(User.current)

    @fields = changeable_fields(@issue)
    render partial: "rubylode_agenda_line_issues/change", formats: [:html], layout: false
  end

  # One request, one journal: init_journal and safe_attributes, so Redmine records and mails the change as on its own form.
  def update
    issue = visible_ticket or return render_404
    return deny_access unless issue.editable?(User.current)

    issue.init_journal(User.current)
    issue.safe_attributes = params.permit(*CHANGEABLE_FIELDS, :notes).to_h
    return render_failure(issue) unless issue.save

    render_ticket_rows(issue)
  end

  # The small form with the ticket field and the tickets of this agenda to pick from. purpose: link (a line without a
  # ticket), child (make the line's ticket a child of the one picked) or parent (make it the parent of the one picked).
  def picker
    @purpose = %w[link child parent].include?(params[:purpose]) ? params[:purpose] : "link"
    own = visible_ticket
    return render_404 if own.nil? && @purpose != "link"

    @candidates = RubylodeAgenda::TicketPicker.new(agenda: @line.agenda, viewer: User.current, except: own).candidates
    preselected = @line.parent_line&.visible_issue(User.current) if @purpose == "child"
    @preselected = preselected if preselected && preselected != own
    @action_path = picker_action_path(@purpose)
    render partial: "rubylode_agenda_line_issues/picker", formats: [:html], layout: false
  end

  # Links the picked ticket, with the same rule as typing its number: only a ticket the person may see. The line keeps
  # its own text.
  def link
    ticket = picked_ticket or return render_message(:not_found)

    @line.lock_version = params[:lock_version] if params[:lock_version].present?
    @line.update!(issue_id: ticket.id)
    render_envelope(@line.agenda_id, lines: [@line])
  end

  # Makes the line's ticket a child of the ticket picked.
  def parent
    issue = visible_ticket or return render_404
    ticket = picked_ticket or return render_message(:not_found)
    return deny_access unless issue.safe_attribute?("parent_issue_id", User.current)

    change_parent(issue, ticket.id)
  end

  def remove_parent
    issue = visible_ticket or return render_404
    return deny_access unless issue.safe_attribute?("parent_issue_id", User.current)

    change_parent(issue, nil)
  end

  # Makes the ticket picked a child of the line's ticket: the person must be allowed to change the picked one.
  def children
    issue = visible_ticket or return render_404
    ticket = picked_ticket or return render_message(:not_found)
    return deny_access unless ticket.safe_attribute?("parent_issue_id", User.current)

    change_parent(ticket, issue.id)
  end

  private

  def changeable_fields(issue)
    CHANGEABLE_FIELDS.select do |field|
      issue.safe_attribute?(field, User.current) && (field != "done_ratio" || Issue.use_field_for_done_ratio?)
    end
  end

  def picked_ticket
    RubylodeAgenda::TicketPicker.find(params[:ticket], User.current)
  end

  def picker_action_path(purpose)
    case purpose
    when "child" then project_rubylode_agenda_line_issue_parent_path(@project, @line)
    when "parent" then project_rubylode_agenda_line_issue_children_path(@project, @line)
    else project_rubylode_agenda_line_link_path(@project, @line)
    end
  end

  # The parent goes through safe_attributes too, so Redmine checks the subtask permission, visibility, the projects
  # and loops, and answers with its own message when it refuses.
  def change_parent(ticket, parent_id)
    ticket.init_journal(User.current)
    ticket.safe_attributes = { "parent_issue_id" => parent_id.to_s }
    return render_failure(ticket) unless ticket.save

    render_ticket_rows(@line.issue)
  end

  # A ticket changed, not a line: every row of this agenda that shows the ticket is stamped with a new revision (its
  # lock version stays, so nobody typing in it meets a conflict) and drawn again, here and, through polling, elsewhere.
  def render_ticket_rows(issue)
    agenda = @line.agenda
    topics = agenda.topics.active.where(issue_id: issue.id).to_a
    lines = agenda.lines.active.where(issue_id: issue.id).in_order.to_a
    (topics + lines).each { |record| record.update_columns(revision: agenda.bump_revision!) }
    render_envelope(agenda.id, topics: topics, lines: lines)
  end

  def find_line
    @line = project_lines.active.find(params[:id])
  end

  def visible_ticket
    @line.visible_issue(User.current)
  end

  def render_fragment
    @latest_note = @issue.visible_journals_with_index(User.current).reverse.find { |journal| journal.notes.present? }
    @subtasks = Issue.visible(User.current).where(parent_id: @issue.id).includes(:status).order(:id)
    @time_logged = TimeEntry.visible(User.current).where(issue_id: @issue.id).sum(:hours) if may_view_time?
    @may_add_note = @issue.notes_addable?(User.current)
    render :show, formats: [:html], layout: false
  end

  def may_view_time?
    User.current.allowed_to?(:view_time_entries, @issue.project)
  end

  def render_message(key)
    render json: { errors: [l("rubylode_agenda.tickets.errors.#{key}")] }, status: :unprocessable_entity
  end

  # The form's own values win; a value that was not sent at all falls back to the line and the topic: the first line of
  # the text is the subject and the rest the description; the parent line's ticket (or else the topic's) gives the parent
  # and the version; the topic's owner the assignee. Everything goes through safe_attributes, so the tracker's workflow,
  # the permissions and the required fields apply as on Redmine's own form. Answers false when the tracker is not allowed.
  def assign_ticket_attributes(ticket)
    source = @line.ticket_source(User.current)
    allowed = ticket.allowed_target_trackers(User.current)
    tracker = params[:tracker_id].present? ? allowed.find { |entry| entry.id == params[:tracker_id].to_i } : allowed.first
    return false unless tracker

    ticket.tracker = tracker
    ticket.status = tracker.default_status
    ticket.priority = IssuePriority.default || IssuePriority.active.first
    ticket.safe_attributes = {
      "subject" => params[:subject].to_s.strip.presence || @line.ticket_subject,
      "description" => given_or(:description) { @line.ticket_description.presence },
      "parent_issue_id" => given_or(:parent_issue_id) { source&.id },
      "fixed_version_id" => given_or(:fixed_version_id) { source&.fixed_version_id },
      "assigned_to_id" => given_or(:assigned_to_id) { @line.topic.owner_id }
    }
    true
  end

  def given_or(key)
    params.key?(key) ? params[key].presence : yield
  end
end
