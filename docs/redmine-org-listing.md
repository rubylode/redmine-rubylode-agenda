# Listing on www.redmine.org

The text to paste at www.redmine.org, Plugins, New plugin. Redmine's "Check for updates" asks that directory about every installed plugin, so the listing must carry the same name, author and version as the plugin.

| Field | Value |
|---|---|
| Name | Rubylode Agenda |
| Short description | A dated meeting page for each project: topics and lines edited by several people at once, ticket links, carry-over, and the tickets closed since the last meeting with a few numbers |
| Homepage | https://github.com/rubylode/redmine-rubylode-agenda |
| Compatible with | Redmine 7.0.x |
| License | GNU General Public License, version 2 or (at your option) any later version |
| Author | Rubylode |

## Notes for this version

Version 0.1.0 is the first release. Each project gets an Agenda tab with dated meetings: numbered topics with an owner and lines under them, edited in place by several people at once. A line can hold several text lines and sub-points, link a ticket or become one, alone or many at once, and its menu changes the ticket. Starting the next meeting carries over what is not done; quiet carried lines fold and a line can be parked. A "Since the last meeting" card shows closed, opened, still open, average days to close, overdue and closed per person, each linked to the issue list. Needs Redmine 7.0 or newer. It adds five tables, so run the migrate command. Install and settings are described in the README at https://github.com/rubylode/redmine-rubylode-agenda.

## File to upload

`redmine_rubylode_agenda-0.1.0.zip`, the file the GitHub release workflow publishes when a `v0.1.0` tag is pushed. Upload the same file that is attached to the GitHub release.

## Checking the result

The name, author and version in the listing must match what the plugin registers (`Rubylode Agenda`, `Rubylode`, `0.1.0`). When they do, Administration, Plugins, Check for updates shows:

- a green tick: the installed version is the latest one listed on redmine.org;
- an amber warning: redmine.org lists a newer version than the installed one;
- a grey question mark: the plugin is not found, so the name or the listing needs a look.

The answer comes only from the redmine.org directory. Nothing in the plugin can change it, and it stays grey until the listing exists.
