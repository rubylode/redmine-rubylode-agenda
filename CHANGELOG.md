# Changelog

## [Unreleased]

### Added

- A project module "Rubylode Agenda" with two permissions, View the agenda and Edit the agenda, and an Agenda tab after the roadmap.
- Meetings: start the first or the next one, change its date and period, close it. Starting the next meeting closes the open one and carries over the notes that are not done.
- Numbered topics with an owner and lettered lines under them: add a line by typing and pressing Enter, edit in place, tick done, delete, drag to reorder, and drag a line into another topic.
- Every change of a topic or line raises the meeting's revision, and a save made from an out-of-date copy is refused with the current version.
- Two people can edit one meeting at once: the page fetches others' changes every few seconds, never replaces a field being typed in, and offers "Keep mine" or "Take theirs" when a save meets a newer text.
- Two links per project, to a KPI sheet and a progress page, set on the agenda settings page and shown under the agenda.

- Ticket links: link a line or a topic to a ticket by number, or type `#123` alone as a line's text. A linked line shows the ticket number, its status and, when the ticket is closed, strikes through. A ticket the viewer may not see shows as plain text. Clicking the arrow beside the number opens the latest note, the subtasks, the time logged and a form to add a note.
- Quick-create: Ctrl+Enter in a line opens a small form that makes a ticket from the line, with the parent and version from the topic's ticket and the assignee from the topic's owner, and links it. It follows the viewer's own permissions, trackers and workflow, and remembers the last tracker chosen.
- Starting the next meeting also carries lines whose ticket is still open, and leaves behind lines whose ticket is closed.

- Quiet lines fold: under each topic, carried lines that were not edited and whose ticket (if any) has not changed since the period began collapse into one row "N carried, no change". Every carried line shows how many meetings it has been carried.
- Parked lines: park a line to take it off the agenda and out of carry-over. A collapsed "Parked" list under the agenda shows each with the topic it left and the date, and Bring back puts it under the topic of the same title in the open meeting, made again if missing.

### Changed

- Redmine 7.0 or newer is required.
- The global Agenda page and the plugin setting are gone; the agenda lives in each project.
