# Listing on www.redmine.org

The text to paste at www.redmine.org, Plugins, Rubylode Agenda. Redmine's "Check for updates" asks that directory about every installed plugin, so the listing must carry the same name, author and version as the plugin.

| Field | Value |
|---|---|
| Name | Rubylode Agenda |
| Short description | A dated meeting page for each project: topics and lines edited by several people at once, ticket links, carry-over, and the tickets closed since the last meeting with a few numbers |
| Homepage | https://github.com/rubylode/redmine-rubylode-agenda |
| Compatible with | Redmine 7.0.x |
| License | GNU General Public License, version 2 or (at your option) any later version |
| Author | Rubylode |

## Notes for this version

Version 1.1.1 adds standing links for each project (the call, a calendar, a roadmap document), shown on every meeting, with up to two as buttons at the top. Status, age and the numbers now have colours: status pills, carried chips that warm with age, a dot for new lines and number tiles in their own colours. Buttons and numbers whose effect is not obvious explain themselves in a tooltip. Coming from 1.0.0, run the migrate command: the two former link fields become entries of the list. Version 1.0.0 changed the card to count closed tickets per project or per category, with closed per person as an option that is off by default. Everything else is as in the first release: each project gets an Agenda tab with dated meetings, numbered topics with an owner and lines under them, edited in place by several people at once. A line can hold several text lines and sub-points, link a ticket or become one, alone or many at once, and its menu changes the ticket. Starting the next meeting carries over what is not done; quiet carried lines fold and a line can be parked. Needs Redmine 7.0 or newer. Install and settings are described in the README at https://github.com/rubylode/redmine-rubylode-agenda.

## File to upload

`redmine_rubylode_agenda-1.1.1.zip`, the file the GitHub release workflow publishes when a `v1.1.1` tag is pushed. Upload the same file that is attached to the GitHub release.

## Checking the result

The name, author and version in the listing must match what the plugin registers (`Rubylode Agenda`, `Rubylode`, `1.1.1`). When they do, Administration, Plugins, Check for updates shows:

- a green tick: the installed version is the latest one listed on redmine.org;
- an amber warning: redmine.org lists a newer version than the installed one;
- a grey question mark: the plugin is not found, so the name or the listing needs a look.

The answer comes only from the redmine.org directory. Nothing in the plugin can change it, and it stays grey until the listing exists.
