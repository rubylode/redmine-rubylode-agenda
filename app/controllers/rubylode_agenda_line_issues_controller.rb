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

    render_envelope(@line.meeting_id, lines: [@line])
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

  private

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
