# Rubylode Agenda roadmap

Goal: one meeting page per project, with the agenda topics beside what changed since the last meeting.

## Done

- [x] Design spec: the agenda on the left, what changed since the last meeting on the right (`docs/specs/2026-11-21-agenda-design.md`)
- [x] The meeting page: meetings, topics, lines, two people at once, ticket links, carry-over, fold and parked, the sidebar with its numbers and snapshots
- [x] Editing as an outline: several text lines per item, sub-points, a menu on every line, ticket actions, several tickets at once
- [x] The page layout with a topic rail, sparklines and links from the numbers to the issue list
- [x] Release 0.1.0, 2026-11-21 (`2f917f8`, tag `v0.1.0`)

## Next

1. Try by hand what no test covers: dragging, two windows at once, the narrow layouts (`docs/plans/agenda-browser-checklist.md`)
2. Run the suite on PostgreSQL and MySQL, and try two people starting or closing a meeting at the same moment there
3. Try the sidebar with Rubylode Progress installed
4. Tidy the changelog so the next entry lists only what changed since 0.1.0
5. Marks for lines that are new or changed this week, and a switch that shows only those
6. Release 1.0.0 once the page has been used for real meetings
