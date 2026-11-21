# Rubylode Agenda for Redmine

<p><img src="docs/thumbnail.png" alt="Rubylode Agenda plugin" width="160"></p>

[![tests](https://img.shields.io/github/actions/workflow/status/rubylode/redmine-rubylode-agenda/tests.yml?branch=main&label=tests)](https://github.com/rubylode/redmine-rubylode-agenda/actions/workflows/tests.yml)
[![security](https://img.shields.io/github/actions/workflow/status/rubylode/redmine-rubylode-agenda/security.yml?branch=main&label=security)](https://github.com/rubylode/redmine-rubylode-agenda/actions/workflows/security.yml)
[![license](https://img.shields.io/github/license/rubylode/redmine-rubylode-agenda)](https://github.com/rubylode/redmine-rubylode-agenda/blob/main/LICENSE)
![Redmine](https://img.shields.io/badge/Redmine-7.0-b22222)

TL;DR: a dated meeting page for each [Redmine](https://www.redmine.org) project. The agenda sits next to what changed
since the last meeting: progress before and after, the tickets that were closed, and a few numbers. Any agenda line can
point at a ticket or become one. Several people can edit the same meeting at once.

Not released yet. Needs Redmine 7.0 or newer. `docs/roadmap/ROADMAP.md` lists what is not done.

Contents:

- [What it does](#what-it-does)
- [Install](#install)
- [Enabling it](#enabling-it)
- [Settings](#settings)
- [Where it shows](#where-it-shows)
- [Restyling it](#restyling-it)
- [Troubleshooting](#troubleshooting)
- [Tests](#tests)
- [Releasing](#releasing)
- [License](#license)

## What it does

Each project keeps dated meetings. A meeting is a numbered list of topics. Each topic has a title, an owner and lettered
lines under it. The agenda is on the left. On the right is a sidebar headed "Since the last meeting".

### Topics and lines

- Type a topic in the box under the list and press Enter. Pick its owner from the project's members.
- Type a line under a topic and press Enter. It is saved and a new empty line opens below.
- Edit a line where it stands. Tick it when it is done. Delete it with the cross.
- Drag the handle to reorder topics or lines. A line can be dragged into another topic of the same meeting.
- Escape leaves a field without saving.

### Ticket links

- Type `#123` alone as a line or a topic title. It links ticket 123 and takes the ticket's subject.
- A linked line shows the ticket number and its status. When the ticket is closed, the line is struck through.
- Click the arrow beside the number to open the latest note, the subtasks and the time logged under the line. A form there
  adds a note to the ticket.
- Press Ctrl+Enter (Cmd+Enter on a Mac) in a line to make a ticket from it. The form is filled in from the topic: the
  parent and version from the topic's ticket, the assignee from its owner. Redmine's own permissions, trackers, workflow
  and required fields apply.
- A ticket the viewer may not see shows as plain text, with no number and no status.

### Carry-over, fold and parked

Starting the next meeting closes the open one. A new meeting is held today and its period runs from the previous
meeting's date. Lines are carried into it: notes that are not done, and lines whose ticket is still open. A line whose
ticket is closed is left behind. A topic with nothing to carry is left behind too.

A carried line shows how many times it has moved on ("carried 2x"). A carried line that nobody edited, and whose ticket has
not changed since the period began, is quiet. Quiet lines fold into one row, "N carried, no change". Open the row to see
them. Edit a folded line, or change its ticket, and it leaves the fold.

Press the Park button on a line, or Alt+P while typing in it, to take it off the agenda and out of carry-over. The
collapsed "Parked" list under the agenda holds every parked line of the project with the topic it left and the date.
"Bring back" moves it into the open meeting, under the topic with the same title (made again if missing).

### Two people at once

The page asks the server for other people's changes every few seconds. A line or topic changed by someone else is updated
on your page. The field you are typing in is never replaced. If you save a line that someone else saved first, the save is
refused and both texts are shown: "Keep mine" saves yours over theirs, "Take theirs" drops yours. When the meeting is
closed by someone else, a notice says so at the top. Parking or bringing back a line in another window shows "reload to
refresh" on the Parked heading.

### The sidebar

The sidebar covers the meeting's period, from the start of its first day to the end of its last day. It shows:

- Progress, before and after, with the stages, when the Progress plugin is installed. Without it the section is left out.
- Six numbers: closed, opened, still open, average days to close, overdue, and closed per person.
- The closed tickets, grouped by version. Ten are listed and "Show more" opens the rest.

The previous meeting's average days and overdue count show beside the current ones as "before". Overdue means open tickets
due before today while the meeting is open, and before the meeting's own date once it is closed. Closed per person uses
each ticket's assignee at the time the page is shown. It is never stored.

### Snapshots on close

Closing a meeting stores its progress and its numbers as the person who closed it saw them. The sidebar of a closed meeting
says "As of" that date and reads the stored values, so they stay the same when more tickets are closed later. Only counts
are stored, never ticket lists. The list of closed tickets and the closed-per-person table are always read live, under the
viewer's own visibility.

## Install

Needs Redmine 7.0 or newer.

1. Put the plugin folder in Redmine's `plugins/` directory, named `redmine_rubylode_agenda`:

       cd /path/to/redmine/plugins
       git clone https://github.com/rubylode/redmine-rubylode-agenda.git redmine_rubylode_agenda

2. Run `bundle exec rake redmine:plugins:migrate RAILS_ENV=production`. It adds five tables.
3. Restart Redmine.

To remove it, run `bundle exec rake redmine:plugins:migrate NAME=redmine_rubylode_agenda VERSION=0 RAILS_ENV=production`,
delete the folder and restart. This deletes every meeting.

## Enabling it

1. In the project, open Settings, Modules, and check "Rubylode Agenda".
2. In Administration, Roles and permissions, give a role the permissions under the module's name:
   - "View the agenda" opens the page and the ticket panels. It is enough for a reader.
   - "Edit the agenda" starts, edits and closes meetings, and changes topics, lines, parking and the agenda settings.
     Making a ticket from a line also needs Redmine's own "Add issues", and adding a note needs "Add notes".

The Agenda tab then appears in the project menu, after Roadmap.

## Settings

Open them with "Agenda settings" under the agenda. Only people with "Edit the agenda" see the link.

| Setting | Meaning |
|---|---|
| KPI sheet link | A web address shown as "KPI sheet" under the agenda. Empty shows no link. |
| Progress page link | A web address shown as "Progress page" under the agenda. Empty shows no link. |
| Tickets that count | A saved issue query of the project, or "Everything". The sidebar counts and lists only the tickets the query finds, in the project and its subprojects. |

The links must start with `http://` or `https://`.

The query only narrows the tickets counted in the sidebar. Progress is not narrowed by it. Only the query's filters are
used, never its sort or columns. A query the viewer may not see, or one that belongs to another project, is ignored.

The query's status filter is not used. A query saved in Redmine starts with "open tickets only", and the sidebar counts
open and closed tickets itself, so that filter is left out.

## Where it shows

- The project tab "Agenda", at `/projects/:id/agenda`. It opens the open meeting, or else the latest one. A project with no
  meeting says so and, for people who may edit, offers "Start the first meeting". The first meeting's period starts seven
  days before it.
- A meeting of its own, at `/projects/:id/agenda/meetings/:id`. A switcher above the agenda lists the meetings.
- "Change dates" in the header sets a meeting's date and period. The period of a closed meeting cannot be changed.
- The Progress plugin, if installed, supplies the progress percent and the stages. Without it everything else works.

## Restyling it

Every rule sits under `.rubylode-agenda`, every class starts with `rubylode-agenda-`, and every colour and size is a CSS
custom property named `--rubylode-agenda-...` with its default in `:where(:root)`. A theme overrides the properties.
The page stacks into one column below about 900 pixels.

## Troubleshooting

- The tab is missing: check that the module is enabled for the project and that your role has "View the agenda".
- You can read the agenda but cannot type: your role lacks "Edit the agenda".
- Ctrl+Enter opens nothing: you may not add issues to the project, or no tracker is open to you.
- A line shows no number or status: the ticket is not one you may see.
- The sidebar shows no progress: the Progress plugin is not installed.
- A number is lower than expected: the sidebar counts only what you may see, in the project and its subprojects.
- A changed plugin file does not show: Redmine caches code in production. Restart it.

## Tests

    bin/test                                              all unit and integration tests
    bin/test test/integration/plugin_registered_test.rb   one file

They run in a Redmine 7 image with its test gems (`docker/test.Dockerfile`).

### Try it

A throwaway Redmine 7 with the plugin mounted and made-up data runs from this folder:

    ruby bin/demo up         start it and load the demo data; Redmine is on http://127.0.0.1:3021
    ruby bin/demo seed-busy  add the busy project "Lighthouse" (about a second; does nothing when it is there)
    ruby bin/demo restart    pick up a change to the plugin (it runs in production mode)
    ruby bin/demo down       stop it, keep the data
    ruby bin/demo reset      stop it and wipe the data

The project "Demo project" has twenty tickets, a saved query used as the scope, a closed meeting held eight days ago and the
next meeting started from it, so there are carried lines, folded lines and a parked line. Sign in as `alex` or `sam` with
the password `password1234` in two browser windows, or as `reader`, who may only look. The administrator is admin / admin.
`ruby bin/demo seed-busy` adds a second project, "Lighthouse", with 1000 tickets (620 of them an old backlog), ten weekly
meetings and a saved query that leaves the backlog out, to see the meeting page on a long list of tickets. The data is throwaway; never run the demo task against a real tracker. `docs/plans/agenda-browser-checklist.md` lists what
to try by hand.

## Releasing

Push a `vX.Y.Z` tag whose version matches `version` in `init.rb` and has an entry in `CHANGELOG.md`. CI runs the tests, builds
`redmine_rubylode_agenda-X.Y.Z.zip` and publishes the GitHub release with the changelog entry as its notes. The archive holds
only what Redmine needs: `bin/`, `docs/`, `test/`, `docker/`, `lib/tasks` and the demo data are left out of it.

## License

GNU General Public License, version 2 or (at your option) any later version, the same as Redmine. See `LICENSE`.

Copyright (C) 2026  Nick Gorbikoff

No warranty, as the GPL says. The agenda adds its own tables. It changes your tickets only through what you do on its page,
and that goes through Redmine's own rules. Try it on a copy of your tracker first.
