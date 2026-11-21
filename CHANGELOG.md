# Changelog

## [Unreleased]

### Added

- A project module "Rubylode Agenda" with two permissions, View the agenda and Edit the agenda, and an Agenda tab after the roadmap.
- Meetings: start the first or the next one, change its date and period, close it. Starting the next meeting closes the open one and carries over the notes that are not done.
- Numbered topics with an owner and lettered lines under them: add a line by typing and pressing Enter, edit in place, tick done, delete, drag to reorder, and drag a line into another topic.
- Every change of a topic or line raises the meeting's revision, and a save made from an out-of-date copy is refused with the current version.
- Two people can edit one meeting at once: the page fetches others' changes every few seconds, never replaces a field being typed in, and offers "Keep mine" or "Take theirs" when a save meets a newer text.
- Two links per project, to a KPI sheet and a progress page, set on the agenda settings page and shown under the agenda.

### Changed

- Redmine 7.0 or newer is required.
- The global Agenda page and the plugin setting are gone; the agenda lives in each project.
