# Rubylode Agenda roadmap

Goal: one meeting page per project, with the agenda topics beside what changed since the last meeting.

## Done

- [x] Design spec: the agenda on the left, what changed since the last meeting on the right (`docs/specs/2026-11-21-agenda-design.md`)
- [x] The meeting page: meetings, topics, lines, two people at once, ticket links, carry-over, fold and parked, the sidebar with its numbers and snapshots
- [x] Editing as an outline: several text lines per item, sub-points, a menu on every line, ticket actions, several tickets at once
- [x] The page layout with a topic rail, sparklines and links from the numbers to the issue list
- [x] Release 0.1.0, 2026-11-21 (`2f917f8`, tag `v0.1.0`)
- [x] Closed per project or per category in the sidebar; closed per person as an option, off by default
- [x] Release 1.0.0, 2026-11-21 (`bdba39e`, tag `v1.0.0`)
- [x] Standing links per project, tooltips that explain buttons and numbers, colours for status, age and the numbers
- [x] Release 1.1.0, 2026-11-22 (`68ba3f3`, tag `v1.1.0`): tagged, never published
- [x] Release 1.1.1, 2026-11-22 (`a6e8fba`, tag `v1.1.1`): everything of 1.1.0 plus the tooltips as short facts

## Next

1. Try by hand what no test covers: dragging, two windows at once, the narrow layouts (`docs/plans/agenda-browser-checklist.md`)
2. Run the suite on PostgreSQL and MySQL, and try two people starting or closing a meeting at the same moment there
3. Try the sidebar with Rubylode Progress installed
4. Marks for lines that are new or changed this week, and a switch that shows only those
5. A subproject the viewer may not see, with a visible project under it: its closed tickets count in the Closed number but in no row
