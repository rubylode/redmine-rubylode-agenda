# Rubylode Agenda: design

Status: approved, 2026-11-21. The designer's calls were confirmed the same day, with three additions: a scope, parked lines and folded quiet lines.

## Intent and why

A team that meets every week (sometimes every two weeks, when a meeting is missed) keeps its agenda in a shared document: dated sections, numbered topics with an owner as the header, lettered sub-points, and links to a KPI sheet and to the project's progress page. Running that meeting means switching between the document, the tracker and a spreadsheet, and the document knows nothing about the tickets it talks about.

Rubylode Agenda moves the meeting into Redmine. One page per meeting shows the agenda beside what changed since the previous meeting: how far the project moved (for example 34% to 51%), how many tickets were closed and which ones, and a few simple numbers. Any agenda line can become a ticket, or point at one, without leaving the page. The aim is a page that is as quick to type in as the document, and better to read because the tickets are live.

## Goals

- One dated meeting record per project, with free-text topics and lettered sub-points (the "hybrid" model: any line can stay a note, link to an existing ticket, or become a new ticket).
- A sidebar of what changed between the previous meeting and this one: progress before and after, tickets closed (count and list), tickets opened and still open, and a few KPIs.
- The period runs from the previous meeting's date to this meeting's date by default, so a missed week gives a two-week period with no extra work. The dates can be edited.
- Create a ticket from a line in two keystrokes (Ctrl+Enter), with the parent, tracker, assignee and version filled from the topic (or, for a sub-point, from its parent line's ticket).
- Click a linked line to expand the ticket in place: latest note, subtasks, time logged, open or add a note.
- Starting a meeting copies the previous meeting's unfinished lines forward, so open items carry over.
- Works without the Progress plugin (the percentage is simply not shown).
- Stays manageable in a project with hundreds of open tickets: nothing that was discussed falls off, yet the page keeps the eye on this week's and recently worked items (see "Keeping a meeting manageable").

## Non-goals

- No automatic drafting or summarising in the first version. It can be added later as a button on this same page.
- No minutes by email, no attendee list, no calendar events, no timers.
- No replacement for the To-do plugin or the Roadmap; this is a record of meetings, not a work queue.
- No import of old documents.
- No editing the numbers of a closed meeting after the fact (see Snapshots).

## Anti-goals

- Slower to type in than the shared document. If adding a line takes more than a line and a key, the design has failed.
- A page that sends people elsewhere to do the work. Reading, adding a note and creating a ticket stay on the page.
- A second, competing list of tickets. Tickets live in Redmine; the agenda only points at them.

## Constraints

- Redmine 7.0 or newer (Progress requires 7.0; the skeleton's 5.1 floor is wrong and must change).
- Plugin id `redmine_rubylode_agenda`, display name "Rubylode Agenda", menu tab "Agenda", project module label "Rubylode Agenda".
- Public repository: nothing in the code, docs or commits names a person or a client.
- Everything is a Redmine project module with its own permissions; ticket creation respects the viewer's own `add_issues` permission and the project's trackers and workflow.
- Tickets, versions and users shown must respect the viewer's visibility (private issues, subproject rules).
- No new gem and no new JavaScript package: use what Redmine already ships (jQuery, jQuery UI sortable for drag reordering, its own ticket-number autocomplete). A block editor such as Editor.js was considered and rejected: it saves the page as one blob, which breaks per-line records, ticket links, carry-over and two people typing at once. A text-syncing library (Yjs with a Ruby server gem) is the route to Google-Docs-style live editing and is deferred until polling proves too slow.
- Rubylode conventions: tests first for business logic, Minitest, server-rendered HTML with a little Stimulus-style JavaScript, strings in the locale file, the same layout and theming approach as the sibling plugins (see Projects and Beszel).

## Approaches considered

- **A. Its own plugin (chosen).** Own tables for meetings, topics, lines and snapshots. Reads the percentage from Progress when it is installed. Own closed-ticket query. Creates tickets itself. Most new code; nothing else has to change, and it ships on its own.
- **B. Spread across To-do, Progress and Stats.** Less new code, but one page needs three plugins at matching versions, each release touches three repositories, and the hybrid topic model does not fit To-do's list of ticket lines.
- **C. Start with automatic drafting of the agenda.** Most appealing, but it sits on the same screen, snapshots and queries as A and adds a service dependency before the basic screen works. Deferred as an optional layer on A.

Chosen: A. It keeps the meeting record in one plugin that ships alone, and the hybrid topic model has a natural home in its own tables.

## Decided

Decided by the owner in conversation:

- The hybrid topic model (a dated record with free-text topics and sub-points; any line can be or link to a real ticket).
- Layout B: the agenda on the left, a "since the last meeting" sidebar on the right (stacks on a narrow screen), closed to the shared document. Closed tickets are listed in the sidebar, not folded into topics. Later refined into a document with a side rail (see "Page layout").
- The meeting page, linked KPI sheet and progress page: the project can store two links shown at the bottom of the agenda.
- Period defaults to previous meeting to this meeting.
- Two people will type in the agenda during the meeting, so simultaneous editing is a requirement (see "Simultaneous editing").
- The meeting counts the tickets of subprojects the viewer can see, the same as the Progress percentage does.
- The record of one meeting is called an agenda inside the plugin (tables, models, routes, code); people still read "meeting" where the event is meant ("Meeting of 11/21/2026", "Start next meeting").
- One meeting series per project. Every meeting follows the previous one. A series column can be added later if it is ever needed.

Calls of the designer, confirmed by the owner:

- **Carry-over.** A new meeting copies unfinished lines (notes not marked done, and lines linked to open tickets) from the previous meeting. A topic with nothing unfinished is not copied. Parked lines are not copied.
- **Life of a meeting.** A meeting is open or closed. At most one is open per project. "Start next meeting" closes the open one first, then opens a new one dated today. A meeting can also be closed by its own button. After closing, the agenda text can still be corrected; the stored numbers (snapshots, KPIs) are frozen.
- **Snapshots.** Closing a meeting stores the project's progress percentage, stage counts, and the KPI numbers below, with the time they were taken, shown in the sidebar as "as of <date>". A meeting's "before" is the previous meeting's closing snapshot. While a meeting is open its "after" is computed live. The first meeting of a project has no "before": its sidebar shows the current percentage only, and its period starts seven days before the meeting unless edited, so the counts and the closed list still work. Only meetings from now on have snapshots.
- **Who a snapshot is taken as.** As the user who closes the meeting, and only aggregate numbers are stored (never ticket lists), so a private ticket can at most nudge a count. Everyone who may view the page sees the stored numbers.
- **KPIs in the sidebar** (all six, all counted inside the scope): tickets closed in the period; tickets opened in the period; every ticket still open in the project (visible to the viewer); average days from creation to close for those closed in the period; overdue count; closed per person. "Closed per person" counts the assignee at the moment of the report, not who pressed Close. "Overdue" is as of now while the meeting is open and as of the meeting date once it is closed. The previous period's value shown beside the average and the overdue count is the one stored in the previous meeting's closing snapshot.
- **Quick-create defaults.** Parent and version come from the topic's linked ticket when it has one; the assignee is the topic's owner when it has one; the tracker is the project's first tracker. All can be changed in the small form, and the form remembers the last tracker chosen in the browser.
- **Percentage.** Read through `RubylodeProgress::ProjectProgress.new(project:, viewer:).percent` when that class exists; the stage breakdown through `stages`.
- **Closed tickets** are those whose closed date (`issues.closed_on`) falls in the period and that are closed now. A ticket closed in the period and reopened since does not count.
- **Releases.** A 0.x release after each usable slice, so the plugin is used in real meetings while the rest is built; 1.0.0 when the sidebar and the KPIs are in.

## Keeping a meeting manageable

A project can have hundreds of open tickets, most of them backlog. Nobody should have to skip them by hand every week, and nothing that was discussed should silently disappear. Three mechanisms:

- **Scope.** The project's agenda settings pick one saved issue query (for example "everything except version Backlog and status On hold"). Every count and list in the sidebar is taken inside that query, with the period applied on top. Without a chosen query, everything the viewer can see in the project and its subprojects counts. The Progress percentage is not narrowed by the scope; it stays the project's own number.
- **Quiet lines fold.** Under each topic, new lines and carried lines with activity since the previous meeting (the linked ticket was updated or got a note, or the line's text was edited) show in full. Carried lines with no activity fold into one row ("3 carried, no change") that opens with a click. Every carried line shows how many meetings it has been carried.
- **Parked lines.** One key or click parks a line: it leaves the agenda and is no longer carried forward. Parked lines sit in a collapsed "Parked" list for the project, from which a line can be brought back into the open meeting. Parking is the agenda's own backlog.

## Simultaneous editing

Two people type at the same time. The design is built around that:

- Every line and topic is its own record, saved by itself when the person presses Enter or leaves the field. Two people editing different lines never touch each other.
- Each record carries a version number. Saving an out-of-date line is refused and the person sees the newer text and decides, so nobody's typing is overwritten silently.
- Everyone's page fetches changes made by others every few seconds (a small polling request that returns only what changed since its last call) and merges them in without disturbing the field being typed in. Order changes and new lines appear in place.
- No push connection (no websockets) is required in the first version; it can replace the polling later without changing the records.

## Editing lines

Decided by the owner after trying the first build in the demo:

- **Keys.** In a line, Enter is a line break inside the same item. Shift+Enter saves the item and opens a new one right below it, in the same topic and at the same depth, with the cursor in it. Ctrl+Enter (Cmd+Enter) makes a ticket from the line. Escape leaves without saving. Backspace in an empty item that was never saved removes it and puts the cursor at the end of the item above. ArrowUp with the caret at the very start of a field, and ArrowDown at its very end, move to the item above or below; anywhere else they move the caret inside the item. The "add a line" field works the same way: Shift+Enter saves and the field is ready for the next one. Topic titles stay one line: Enter saves a title.
- **Wrapping.** A line is a text area of one row that grows with its text: it wraps, keeps the line breaks typed, and never scrolls sideways or inside. Someone who may only read sees the same text with its line breaks. A line holds up to 2000 characters. A ticket's badge, the "carried" label and the row's buttons stay on the first text line.
- **Sub-points.** Tab in a line makes it a sub-point, Shift+Tab moves it back. A line has a depth of 0, 1 or 2, stored on the line, in the topic's one flat order: a line's parent is the nearest line above it with a smaller depth. A line may be at most one level below the line above it; the first line of a topic is always at 0. The server enforces this when a depth is written, and the page closes any gap when it shows the lines (a parent deleted, parked, moved or left behind by carry-over) without writing anything. Where a line cannot go deeper, or is already at 0, Tab and Shift+Tab move the focus as usual, so keyboard users are never trapped. Depth 0 is lettered (a, b, c), depth 1 numbered (i, ii, iii) under its parent, depth 2 has a bullet; the numbering is computed by the page's CSS counters and never stored. Depth is saved like any other field of a line (lock version, revision, envelope, conflict). Carry-over copies the depth, and quiet lines keep it inside the fold, which starts again at depth 0. Bringing back a parked line puts it at 0. A dragged line keeps its depth as far as its new place allows. Indenting never creates anything in Redmine.
- **Tickets from sub-points.** The ticket form for a sub-point offers the ticket of its parent line as the parent and takes the version from it, when the person may see that ticket; otherwise the topic's ticket, as before. The first line of an item is the subject and the rest the description. A line that is only `#123` still links ticket 123.
- **The menu.** Each line has one small menu button, shown when pointed at or reached with the keyboard and always on a touch screen. A right click on the row opens the same menu at the pointer. It holds: Make a ticket (Ctrl+Enter), or Open the ticket and Show ticket details when the line has one; Indent (Tab); Outdent (Shift+Tab); Move up; Move down; Park (Alt+P); Delete. Entries that do not apply are greyed out, not hidden. Only people who may edit the agenda get the menu. A right click in a field with text selected, or with Shift held, gives the browser's own menu. The menu is one element for the page with menu roles, opens with the focus on the first entry that applies, moves with the arrow keys and closes on Escape (back to the row), a click elsewhere or a scroll. Move up and down use the reorder request. The menu replaces the separate Park and Delete buttons. Topics have the same menu with Move up, Move down and Delete (with the usual confirmation).

## Ticket actions in the menu

Decided by the owner in the second round. The line menu is the place to turn a line into a ticket, tie tickets together as parent and child, and change a ticket. Redmine's own rules decide every action: safe attributes, workflow, role permissions, required fields and journals. The agenda adds no permission beyond "Edit the agenda", which is needed to see the menu at all. An entry the person may not use is greyed out.

- A line without a ticket: Make a ticket; Make a child ticket of… (the same form, with the parent field focused and the picker under it); Link a ticket… (a picker; the line keeps its text).
- A line with a ticket: Show ticket details; Open the ticket; Change the ticket… (status from the transitions the workflow allows this person, assignee, priority, version, due date, percent done when it is typed by hand, and an optional note, saved as one journaled change; fields the person may not change are left out); Make it a child of…; Make it the parent of… (the person must be allowed to change the other ticket); Remove the parent; Unlink the ticket (the line keeps its text; nothing changes in Redmine).
- The picker takes `#123` or a number and lists the tickets already linked on the meeting's lines and topics that the person may see, filtered by number or subject while typing. There is no search across the tracker. The server looks up whatever comes back: a hidden ticket and a missing one get the same "not found" answer.
- A changed ticket redraws every row of the meeting that shows it, here and in other windows.
- Indenting still does nothing in Redmine. When a line with a ticket sits under a line with a ticket, "Make it a child of…" offers the parent line's ticket first.
- A menu action waits for the line's own text save to finish, so typing and then choosing an entry never ends in a conflict.
- Topics keep their menu of Move up, Move down and Delete; the ticket actions are on lines only.

## Several tickets at once

Decided by the owner in the third round: an easy way to turn selected lines into tickets and subtickets, assigned to the right people and projects.

- "Make tickets" in the header (for people who may edit the agenda and add tickets somewhere) switches the open agenda into selecting: a selection box in front of every line without a ticket (the done box is hidden meanwhile), "Select all in this topic" on each topic, Shift+click for a range, and a bar at the bottom with "N selected", "Review and create" and "Cancel". Escape cancels. The topic menu's "Make tickets from this topic…" and the line menu's "Select for tickets" enter the same state with those lines selected. Lines with a ticket are shown but cannot be selected.
- The review is one table, one row per selected line in agenda order, indented as on the agenda: subject (first line; the rest becomes the description), project, tracker, assignee, version, parent. Defaults: the parent is the ticket made from the parent line when that line is selected too, else the parent line's ticket the person may see, else the topic's ticket, else none; the project is the agenda's, chosen from the projects where the person may add tickets (the agenda's first); the tracker is the first the person may create in that project; the assignee is the topic's owner when assignable there. Changing a row's project brings that project's choices. "Set for all rows" covers project, tracker and assignee.
- One request makes them all, parents first, each through Redmine's rules for the acting person, in one transaction: one refused row and nothing is made, and the review comes back with each refused row marked with Redmine's messages and everything entered kept. On success the lines are linked, other windows follow, the selecting ends and a notice lists the tickets made. A line that got a ticket meanwhile (or changed since the review) is refused on its row.
- At most 50 lines at a time. The review says how many tickets will be made and that Redmine notifies as usual. Nothing is made before the create button.

## Page layout

A document with a side rail: three columns on a wide screen. On the left, a topic rail of about 210 to 250 pixels. In the middle, the agenda, which takes the rest. On the right, the "Since the last meeting" sidebar, about 300 to 380 pixels. Below about 1100 pixels the rail becomes a wrapping row of links above the agenda; below about 900 pixels everything is one column (rail, agenda, sidebar). The page never scrolls sideways.

- The header row: "Meeting of <date>", an "open" pill (or "Closed on <date>"), the period and "Change dates" on the left; the meeting switcher and the Start next and Close meeting buttons on the right.
- The rail: one link per topic with its number, its title and two badges (fifth round): the active lines, filled in the accent tint, and, only when lines are folded, the carried lines with no change, outlined and lighter; equal widths so they line up, an empty slot where there is no second badge, and a tooltip of the plugin's own (CSS from a data attribute) saying "2 active lines" or "3 carried lines with no change". The link's accessible name says it in words. No legend. A link scrolls to its topic (smoothly, unless the person asked for reduced motion), and the topic in view is marked. On a wide screen the rail stays in view while the agenda scrolls. Under the topics: "Parked (N)", which opens the parked list, and the KPI sheet, Progress page and Agenda settings links, each only when it shows; these links appear nowhere else. A reader gets the rail too; a project without a meeting has none.
- The rail is drawn by the server on load and built again by the page from its topic sections after every change it applies, so it has one source and follows other people's changes.
- The look follows Redmine's default theme through the plugin's own custom properties: a topic heading in bold at about 16 pixels with its ticket beside the title, the owner at the right and a 2-pixel rule in the theme's header blue; line rows with some padding, the label column in grey and a light tint under the pointer or the focus; the fold as a dashed, full-width button with a chevron; the sidebar as a tinted card with one progress bar in two parts (before, and gained since), the five numbers as tiles, closed per person as a compact two-column list. Grey text keeps at least 4.5:1 contrast.
- Buttons (third round): one primary per place, filled with the header blue and white text (Close meeting, or Start next meeting on a closed agenda; Create ticket; Save; Review and create); secondary ones white with a 1-pixel border (Make tickets, Change dates, Cancel, Show N more); row controls (menu button, drag handle, ticket arrow) always visible at reduced strength, full strength on the row's hover or focus, with a 28-pixel hit area (44 on touch). Every control has a focus ring.
- The menus come in groups divided by thin rules (ticket actions; indent and outdent; move; park; delete), with Delete last in the danger colour. The fifth number tile spans both columns of the sidebar's grid and draws a wider sparkline.
- Explanations (eighth round): every button, tile, section heading and row control carries a one- or two-sentence explanation of what it does or counts, drawn by the plugin's own CSS tooltip from `data-tooltip` (never `title`), below the control (above in the bottom bar), after a short delay on hover and at once on keyboard focus, and given to screen readers as `aria-description`.
- Closed per project or per category (seventh round): closed per person is hidden by default, because people should not be ranked unless a project chooses it; a project can turn it back on in its agenda settings, and then it shows after the new section, by name and without bars. In its place: closed per project when the project has a subproject the viewer may see (the project's own tickets, then each direct subproject with everything under it, in Redmine's order, empty ones muted), else closed per category (most first, "No category" last). Rows count exactly the Closed number's tickets, are counted for the viewer and never stored, and link to Redmine's list of their tickets: a subproject's own list with its subprojects, the project's list without them, the scope query carried by its filters; a row whose list cannot be built exactly stays unlinked.
- Drill-through (sixth round): every number tile, every row of closed per person and a "See all N in the issue list" link open Redmine's issue list of exactly the tickets behind the number, built by `RubylodeAgenda::IssueListLinks` from the same scope (the saved query without its status, the project with its subprojects, the period's whole days in the viewer's zone, the overdue day). A tile whose field the saved query also filters on is left unlinked. A closed agenda keeps the links with a note that the lists are live. In the narrow layout the rail's badge tooltips open above the badge (below in the first row).
- Sparklines (fourth round): each number tile has a small line of that number over the last meetings: the stored snapshots of the earlier closed agendas and the agenda shown (live while open), at most eight points, a missing value as a gap, nothing below two values. Inline SVG beside the number, scaled to its own range, a dot on the last point, no axis, fill or colour judgement; its label lists the values with their meeting dates.
- Nothing in a row or the rail carries a `title`: Redmine turns titles present at load into jQuery UI tooltips, which stay on the page when their element is dragged or replaced under the pointer.
- The sidebar (third round): a card with the heading, the "As of" note of a closed agenda, and the period; sections divided by a thin rule; number tiles with a large tabular number, the label under it and the previous value on its own line as "up from 21" or "down from 34.9" (colour repeats it, never replaces it); closed per person as a list with right-aligned counts and a faint proportional bar; closed tickets grouped by version, one line each, number then subject cut with an ellipsis and the full subject in its title. It stays in view on a wide screen while it is shorter than the window.

## Screen sketch (layout B)

Header: meeting switcher (dated), period (editable), "Start next meeting".

Left, the agenda: numbered topics with a header (an owner, a title, or a linked ticket), lettered lines under each, with numbered sub-points and bullets under those. A line shows its text and, when linked, the ticket number and status. Add line: type and Shift+Enter for a note, Ctrl+Enter for a ticket (a small inline form: subject, description, parent, tracker, assignee, version; Save creates the ticket and turns the line into a link). Add topic at the end. Links to the KPI sheet and progress page at the bottom.

Right, "since the last meeting": progress before and after with a bar and the change in points, per-stage before and after, closed count with opened and still-open, the KPI rows, then the list of closed tickets (number, subject, assignee, date), grouped by version, with "show more" past about ten.

## Left to the builder

- Table design and migrations, names, indexes. Rough shape: agendas, one per meeting (project, held on, period start and end, closed at), topics (agenda, position, title, optional owner, optional linked issue, lock version), lines (topic, position, text, optional linked issue, done flag, carried from, lock version), snapshots (meeting, percent, stage counts, KPI numbers, taken at, taken by).
- How position changes are stored so two people reordering at once stay sane.
- The polling request's shape and interval.
- Routes, controllers, permissions (a view permission and a manage permission), settings, the two links field.
- How inline editing and the quick-create form work technically (Turbo or small vanilla JavaScript), keyboard handling, ordering.
- The exact closed-ticket query, and how the saved query of the scope is combined with the period.
- What exactly counts as activity on a carried line, and where the "Parked" list sits on the page.
- The Docker run of the plugin tests, as the siblings do.

## Tests

One seam: the plugin's HTTP requests (the meeting page, saving a topic or line, the polling request, closing a meeting, creating a ticket from a line). Tests assert on the response and on what is stored, with the clock fixed where a period or a snapshot is involved. What only happens in the browser (keyboard handling, merging polled changes into the page) is checked by hand against a short checklist per slice, in the demo with two windows.

## Slices

Each is usable on its own and is built test first.

1. Meetings, topics and lines, without tickets; the Redmine 7.0 floor comes first. Release 0.2.0.
2. Two people typing at once: refused stale saves and polling.
3. Ticket links and quick-create; carry-over follows open tickets.
4. Folded quiet lines, the carried count, parked lines.
5. The sidebar: scope, period, closed list, progress before and after, snapshots.
6. The KPI rows. Release 1.0.0.

Slices 2, 3 and 5 need only slice 1; 4 needs 3; 6 needs 5.
