# Rubylode Agenda for Redmine

<p><img src="docs/thumbnail.png" alt="Rubylode Agenda plugin" width="160"></p>

TL;DR: a dated meeting page for a [Redmine](https://www.redmine.org) project. The agenda sits next to what changed since the last meeting: progress before and after, the tickets that were closed, and a few numbers. Any agenda line can become a ticket.

Not released yet.

## What it does

Each project keeps dated meetings. A meeting is a numbered list of topics, each with an owner, and lettered lines under
every topic. Type a line and press Enter to add it, edit it where it stands, tick it done, or drag it to a new place or
another topic. Starting the next meeting closes the open one and carries the notes that are not done into the new one.
The project can also keep a link to its KPI sheet and one to its progress page, shown under the agenda.

Several people can type at once: a save made from an out-of-date copy of a line is refused and the current text shown.

## Enabling it

1. Needs Redmine 7.0 or newer. Copy the plugin to `plugins/redmine_rubylode_agenda` and run `bundle exec rake redmine:plugins:migrate RAILS_ENV=production`.
2. In a project, open Settings, Modules and tick "Rubylode Agenda".
3. Under Administration, Roles and permissions, give a role "View the agenda" to read and "Edit the agenda" to change.
