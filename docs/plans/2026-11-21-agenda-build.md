# Rubylode Agenda: build plan

The design is `docs/specs/2026-11-21-agenda-design.md`. This file fixes what the design left to the builder, so that every slice builds on the same shapes.

## Tables

All tables are prefixed `rubylode_agenda_`. Models live in the `RubylodeAgenda` module.

| Table | Columns |
|---|---|
| `meetings` | `project_id`, `held_on` (date), `period_start` (date), `period_end` (date), `closed_at`, `closed_by_id`, `revision` (integer, default 0), timestamps |
| `topics` | `meeting_id`, `position`, `title`, `owner_id` (user), `issue_id`, `revision`, `lock_version`, `deleted_at`, timestamps |
| `lines` | `topic_id`, `meeting_id`, `position`, `depth` (integer 0 to 2, default 0), `text` (up to 2000 characters, line breaks kept), `issue_id`, `done` (boolean), `parked_at`, `carried_from_id` (line), `carried_count` (integer, default 0), `edited_at`, `revision`, `lock_version`, `deleted_at`, timestamps |
| `snapshots` | `meeting_id` (unique), `percent` (decimal, null without Progress), `stages` (JSON text), `numbers` (JSON text), `taken_at`, `taken_by_id` |
| `project_settings` | `project_id` (unique), `query_id`, `kpi_url`, `progress_url` |

- A topic or line is never destroyed while its meeting exists: deleting sets `deleted_at`, so other pages learn of it.
- `lock_version` is Rails optimistic locking. A stale save answers 409 with the current record.
- `meetings.revision` is the change counter. Every create, update, reorder, delete, park or unpark of a topic or line increments it in the same transaction (one atomic `UPDATE ... SET revision = revision + 1`, then read it back) and stamps the new number on the changed record's `revision`. The polling request asks for records with `revision` greater than the number it last saw. Time stamps are not used for this.
- `lines.edited_at` is set when a line's text changes after it was created. `carried_count` is the source line's count plus one.
- Positions are plain integers, rewritten for the whole container on reorder (last write wins). A line made right after another moves the lines below it down by one; those moves change only `position` and `revision`, not `lock_version`, so nobody typing in a moved line meets a conflict.
- `lines.depth` makes sub-points within the topic's flat order. A line's parent is the nearest line above it with a smaller depth. A written depth is cut to one below the line above (0 for the first line); a depth outside 0 to 2 answers 422. `Line.shown_depths` closes gaps at reading, and the page does the same after every change it applies; neither writes.

## Rules

- One open meeting per project (`closed_at` null). Starting the next one closes the open one, then creates a meeting held today with `period_start` = the previous meeting's `held_on` and `period_end` = today. The first meeting's period starts seven days before.
- Carry-over at creation copies, per topic of the previous meeting, lines that are not deleted, not parked and unfinished: a note that is not done, or a line whose ticket is open. A topic with no such line is not copied. A copied topic keeps title, owner and ticket.
- A closed meeting's topics and lines stay editable; its period and its snapshot do not change.
- Parked: `parked_at` set. Parked lines are not shown in the agenda and not carried. The project's parked list is every parked, not deleted line of the project's meetings. Bringing one back moves it into the open meeting, under a topic with the same title as the one it left (created at the end if missing), and clears `parked_at`.
- Quiet line: carried (`carried_from_id` set), `edited_at` empty, and no ticket or a ticket whose `updated_on` is before the start of the meeting's `period_start` day. Quiet lines fold; all others show. `quiet` is worked out on every read and never stored; each line record carries it.
- Carry-over copies `depth`. Unpark sets it to 0. Reorder cuts the depth of each moved line to what its new place allows.
- The quick-create form takes its parent and version from the parent line's ticket when the viewer may see it, else from the topic's ticket. The first line of the text is the subject and the rest the description.
- Starting a meeting locks the project row first (`Project.lock.find`), so two requests starting one at once run one after the other and the second sees the first one's meeting.

## Requests

All under `projects/:project_id/agenda`. Reading needs `view_rubylode_agenda`, everything else `manage_rubylode_agenda`. Both are project permissions of the module `rubylode_agenda`.

| Request | Does |
|---|---|
| `GET /` | The open meeting, else the latest, else an empty state with "Start the first meeting" |
| `GET /meetings/:id` | That meeting |
| `POST /meetings` | Start the next meeting |
| `PATCH /meetings/:id` | Change `held_on` and the period (open meetings only for the period) |
| `POST /meetings/:id/close` | Close it and store the snapshot |
| `GET /meetings/:id/changes?since=N` | JSON: `revision`, and the topics and lines changed after N |
| `POST /meetings/:meeting_id/topics`, `PATCH /topics/:id`, `DELETE /topics/:id` | Topic |
| `POST /meetings/:meeting_id/topics/reorder` | `ids[]` in the new order |
| `POST /topics/:topic_id/lines`, `PATCH /lines/:id`, `DELETE /lines/:id` | Line. `POST` takes `text`, and optionally `after_id` (made right below that line) and `depth`; `PATCH` takes `text`, `done`, `issue_id` and `depth` with `lock_version` |
| `POST /topics/:topic_id/lines/reorder` | `ids[]` in the new order; a line from another topic moves here |
| `POST /lines/:id/park`, `POST /lines/:id/unpark` | Park and bring back |
| `GET /lines/:id/issue/new` | The quick-create form for a line (HTML fragment), filled in from the topic's ticket and owner; needs the Add issues permission |
| `GET /lines/:id/issue` | The linked ticket opened in place (HTML fragment) |
| `POST /lines/:id/issue` | Create a ticket from the line and link it |
| `POST /lines/:id/notes` | Add a note to the linked ticket |
| `GET /settings`, `PATCH /settings` | The scope query and the two links |

Every write answers JSON: `{ "meeting_id": N, "revision": N, "topics": [...], "lines": [...] }` with the records it changed, in the same shape as the polling request. The polling answer also holds `meeting_closed`. Each record is `{ "id", "topic_id" (lines), "position", "depth" (lines), "lock_version", "deleted", "parked" (lines), "quiet" (lines), "html" }`, where `html` is the server-rendered row, or null for a deleted record. Park and unpark also answer `parked_html`, the project's parked list, which sits outside any topic. Unpark also answers `meeting_path`, the open meeting the line moved into, which may not be the page the person is on, and the topic it made, if any, in `topics`. The page has one function that applies such an answer, used for its own writes and for polled changes alike. Errors: 409 for a stale save (body holds the current record in the same envelope), 422 with messages for a failed validation or an unpark with no open meeting, 403 without permission, 404 for a record of another project.

## Page

Server-rendered ERB. One Stimulus controller in `assets/javascripts/rubylode_agenda.js`, loaded as a module the way Progress and To-do load theirs (Redmine 7 ships Stimulus; no build step, no new package). Requests use `fetch` with the CSRF token from the page's meta tag. Dragging is native HTML5 drag and drop on a handle, as in To-do. Rows carry `data-` attributes (line id, lock version); the controller binds by targets and actions. Line fields are text areas that grow with their text. In a line Enter is a line break, Shift+Enter saves and opens a new item below at the same depth (a row of the page only, made by `POST` with `after_id` when it is finished or left with text), Tab and Shift+Tab change the depth where allowed, Ctrl+Enter opens the ticket form, Escape cancels. The numbering of points and sub-points is CSS counters. One menu element (`role="menu"`) serves every row, opened from a row button or a right click, and is rendered only for people who may edit. The script never replaces a field that has focus: a polled change to that record waits until the field is left.

Layout B: agenda left, sidebar right, stacking under about 900px. Every rule sits under `.rubylode-agenda`, classes are `.rubylode-agenda-*`, and every colour and size is a `--rubylode-agenda-*` custom property with its default in `:where(:root)`, as in Progress (`docs/theming.md` there).

## Conventions

Follow Progress: migrations `db/migrate/00N_name.rb` on `ActiveRecord::Migration[7.2]` with explicit index names; models in `app/models/rubylode_agenda/` with an explicit `self.table_name`; controllers with `menu_item`, `before_action :find_project, :authorize`; top-level locale keys for `project_module_*`, `permission_*` and `label_*`, everything else under `rubylode_agenda:`; English only.

## Sidebar

Plain Ruby objects in `RubylodeAgenda`, each given the project, the viewer and the meeting:

- `Scope`: the relation of tickets that count. `Issue.visible(viewer)` in the project and its subprojects, narrowed by the saved query of the project settings when one is set and the viewer may see it.
- `ClosedIssues`: tickets in the scope with `closed_on` inside the period (start of `period_start` day to end of `period_end` day) and a closed status now. Grouped by version.
- `Numbers`: the six KPIs (the per-person table is never stored: a snapshot keeps the other five, and the table is counted again for each viewer). Closed, opened (`created_on` in the period), still open, average days from creation to close of those closed in the period, overdue (`due_date` before today for an open meeting, before `held_on` for a closed one, among open tickets), closed per person (current assignee).
- `ProgressReading`: percent and stages through `RubylodeProgress::ProjectProgress` when that constant is defined, else nothing. Stages are kept as `version_id`, `done` and `total` only; the name is looked up for the viewer when shown, and a version the viewer may not see shows as "Another stage".
- `Snapshot`: written once when the meeting closes, with the numbers above as seen by the person closing. A closed meeting's sidebar reads counts from its snapshot; the closed-ticket list is always a live query under the viewer's own visibility. "Before" values come from the previous meeting's snapshot.

## Tests

Integration tests through the requests above, on Redmine's own fixtures, with the clock fixed where a period or a snapshot is involved. Expected values are literals. Run one file with `bin/test test/integration/<file>`, the suite with `bin/test`.

Browser checklist per slice (run by hand in two windows) lives in `docs/plans/agenda-browser-checklist.md`. Start the demo with `ruby bin/demo up` (http://127.0.0.1:3021) and sign in as `alex` in one window and `sam` in the other, both password `password1234`; `reader` has only the view permission. The demo has a closed meeting from eight days ago and an open one with carried lines, active and folded, and one parked line.
