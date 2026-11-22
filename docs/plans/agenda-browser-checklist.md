# Agenda browser checklist

Run by hand in the demo, once per slice. Start it with `ruby bin/demo up` and open http://127.0.0.1:3021; sign in as `alex` and `sam` (password `password1234`, both may edit the agenda) and, to look without editing, as `reader`. The project is "Demo project". For a long backlog run `ruby bin/demo seed-busy` once and use the project "Lighthouse" (1000 tickets, ten weekly meetings, fifteen parked lines); the same steps apply there. Anything the tests cannot see (focus, typing, merging polled changes) is checked here.

## Two windows

Open the same project's agenda in two browser windows, signed in as two people who may edit it. Call them window A and window B. Give the page about five seconds to catch up wherever a step says "wait".

1. **Different lines.** Add a topic with two lines. In A edit the first line, in B edit the second, leaving each field with Shift+Enter. Wait: both windows show both new texts, and neither window lost the text typed in it.
2. **Typing while someone else saves.** Click into a line in A and start typing without leaving it. In B change the same line and press Shift+Enter. Wait: A's field still holds what was typed and keeps focus. Leave the field in A without changing it further: it now shows B's text.
3. **The same line, two versions.** In A and B click into the same line and type different text in each. Press Shift+Enter in A, then in B. B shows A's text beside B's own with "Keep mine" and "Take theirs". Press "Take theirs": the field holds A's text. Repeat, and press "Keep mine": B's text is saved and appears in A after a wait.
4. **Reorder.** In A drag the last line of a topic to the top. Wait: B shows the new order. Drag a line from one topic into another in B: A follows.
5. **Delete.** In A delete a line that B is not in. Wait: it disappears from B. Delete a whole topic in B: it disappears from A.
6. **Delete under a cursor.** Click into a line in B, then delete that line in A. Wait: B drops the row; nothing else on B's page changes.
7. **Close the meeting.** In A press "Close meeting". Within a few seconds B shows "This meeting was closed" at the top of the agenda and still lets a line be edited.
8. **Hidden tab and a lost connection.** Switch window B to another tab for a minute while A adds a line; switch back: the line appears at once. Then stop the server or go offline for a minute and come back: the page catches up without a reload.

## Tickets, folding and parking

Run by hand in two windows, in a project with the Agenda module on. Window A is a user who may edit the agenda and add tickets; window B is a user who may only view it.

1. In A, type `#` and the number of a ticket A can see as a new line and press Shift+Enter. The line takes the ticket's subject and shows the number, the status and a small arrow. Type the number of a ticket A cannot see: the status line says it cannot be linked and no line is added.
2. In A, click the arrow of that line: the latest note, the subtasks, the time logged (only if A may view time) and a note form open under the line. Type a note and press Add note: it becomes the latest note. Click the arrow again: the panel closes.
3. Close the ticket in another tab and reload A: the line's text is struck through and the status reads Closed. Make the ticket private so that B cannot see it and reload B: B sees the line's text with no number and no status.
4. In A, type a plain line, then press Ctrl+Enter (Cmd+Enter on a Mac): a small form opens under it with the subject filled in; under a topic that has a ticket and an owner, the parent, version and assignee are filled in too. Escape closes it. Open it again, choose another tracker and press Create ticket: the line now shows the new ticket's number. Open the form on a second line: the tracker chosen last time is selected.
5. Take the Add issues permission away from A's role and reload: Ctrl+Enter in a line opens nothing. Give it back and, in a tracker with a required custom field, create a ticket from the form: the message shows in the status line, the form stays open and the line stays unlinked.
6. Choose Park in a line's menu, or press Alt+P in its text: it leaves the agenda at once and appears in the collapsed "Parked" list under the agenda, with its topic and the date. Open the list, press Bring back: the line returns at the end of the topic of the same title in the open meeting. Park a line, start the next meeting (which has no topic of that title) and bring the line back: the topic is made at the end. Close the open meeting and press Bring back on another parked line: the status line says there is no open meeting.
7. Start the next meeting. A line whose ticket is open is carried with its number; a line whose ticket is closed is left behind; a parked line is not carried. Carried lines with no change sit in one row "N carried, no change"; click it and the lines open. Every carried line shows "carried 1x".
8. Edit the text of a folded line: it moves out of the fold, the count drops and an empty fold disappears. Add a note to the ticket of another folded line and reload: that line is out of the fold. With three lines shown and two folded, the folded ones continue the lettering (d, e), they do not restart at a.

## Editing lines

Run in one window as a user who may edit, then the last step as `reader`.

1. **Enter.** Click into a line and press Enter: the cursor goes to a new line inside the same item and the field grows. Type a second line, leave the field: the item is saved with both lines. Reload: both lines are still there.
2. **Shift+Enter.** In a line press Shift+Enter: the line is saved and a new empty item opens right below it, at the same depth, with the cursor in it. Type and press Shift+Enter again: it is saved and the next one opens. Press Backspace in the empty one: it disappears and the cursor is at the end of the item above. Press Shift+Enter in the "add a line" field: the line is added and the field is empty again; plain Enter there is a line break.
3. **Arrows.** In an item of three lines, ArrowUp and ArrowDown move the caret between its lines. From the very start, ArrowUp goes to the item above; from the very end, ArrowDown goes to the item below.
4. **Tab.** On the second line of a topic press Tab: it moves in and is numbered i. On the line below it press Tab: it becomes ii. Press Tab on it again: it becomes a bullet under i, the sub-point above it. Press Tab once more on a bullet: the focus moves on and nothing changes. Press Tab on the first line of a topic: the focus moves on. Reload: the depths are kept. Window B, if open, follows within a few seconds.
5. **Shift+Tab.** On a sub-point press Shift+Tab: it goes back to a lettered point and the letters after it move on. On a lettered point Shift+Tab moves the focus back as usual.
6. **Gaps.** Make a point with a sub-point and a bullet under it. Delete the sub-point: the bullet now shows as a sub-point, numbered i. Drag a sub-point to the top of its topic: it becomes a lettered point.
7. **A long item.** Paste a paragraph of several hundred characters into a line: it wraps over several rows, with no scroll bar and no sideways scrolling. Link a ticket to a long line: the badge, the "carried" label and the menu button sit on the first text line. Narrow the window: the item rewraps and the field fits its text.
8. **Right click.** Right click a line: the menu opens at the pointer with the shortcuts beside the entries. On the first line, Move up and Outdent are greyed out. On a line with a ticket, "Open the ticket" and "Show ticket details" take the place of "Make a ticket". Select a word in the field and right click it: the browser's own menu opens. Shift+right click: the browser's own menu. Right click a topic's header: Move up, Move down and Delete.
9. **The menu by keyboard.** Tab to a line's menu button and press Enter: the menu opens with the first entry focused. ArrowDown and ArrowUp move through the entries that apply, skipping greyed ones. Escape closes it and the focus is back on the row. Open it again and choose Move down: the line swaps with the one below. Open it, click elsewhere or scroll: it closes. On a touch screen the menu buttons show without hovering.
10. **Ticket from an item.** Give a lettered point a ticket, add a sub-point under it with two lines of text, press Ctrl+Enter in the sub-point: the subject is the first line, the description the second, and the parent is the point's ticket. Under a point without a ticket, the parent is the topic's ticket.
11. **Reader.** As `reader`, the items show with their line breaks and sub-point numbering. There are no menu buttons, and a right click gives the browser's own menu.

## Layout and the topic rail

Use "Lighthouse" for a long page.

1. **Wide (1300 pixels or more).** Three columns: rail, agenda, sidebar. Scroll the agenda: the rail stays in view, and the topic at the top of the window is marked in it. Click a topic in the rail: the page scrolls to it (smoothly, or at once with reduced motion turned on in the system). With more topics than the window holds, the rail scrolls on its own.
2. **Middle (about 1000 pixels).** The rail is a wrapping row of links above the agenda; the sidebar stays on the right. Nothing scrolls sideways.
3. **Narrow (about 600 pixels).** One column: rail, agenda, sidebar. Nothing scrolls sideways.
4. **Counts.** A topic with folded lines reads "N + M" in the rail. Edit a folded line: it leaves the fold and the count changes at once. In window B, add a line and delete a topic: window A's rail follows within a few seconds. Rename a topic: the rail follows when it is saved.
5. **Parked and links.** Park a line: "Parked (N)" appears or goes up in the rail. Click it: the page goes to the parked list and opens it. The KPI sheet, Progress page and Agenda settings links are in the rail and nowhere else. As `reader`, the rail shows without the settings link.
6. **Look.** The header reads "Meeting of <date>" with an "open" pill. Topic headings are bold with a blue rule; rows tint under the pointer; the fold is a dashed button whose chevron turns when open. The sidebar is a tinted card with a two-part progress bar and number tiles.

## Ticket actions

Run as `alex` on lines with and without tickets. Every form takes the focus when it opens, Escape closes it and returns to the line, and Ctrl+Enter (Cmd+Enter on a Mac) submits.

1. **Type, then act.** Type in a line and, without leaving it, choose Indent from its menu: the text is saved, the line moves in, and no conflict message shows.
2. **Make a child ticket of….** On a line without a ticket: the ticket form opens with the parent field focused and a list of the meeting's tickets under it. Type part of a subject: the list narrows. Pick one with the arrow keys and Enter, save: the new ticket's parent is the one picked.
3. **Link a ticket….** Pick a ticket from the list, or type its number: the line shows the ticket and keeps its text. Type the number of a ticket you may not see: "No ticket with that number was found" shows in the form.
4. **Change the ticket….** Only the statuses the workflow allows are offered. Change the status to a closed one and add a note: the line is struck through at once, window B follows within a few seconds, and the ticket's history in Redmine shows the change and the note.
5. **Make it a child of… / Make it the parent of….** Tie two tickets of the meeting together and check the parent in Redmine. Under a parent line with a ticket, "Make it a child of…" already holds that ticket. Try to make a ticket the parent of its own parent: Redmine's message shows in the form and nothing changes.
6. **Remove the parent, Unlink the ticket.** Remove the parent: it is gone in Redmine. Unlink: the line keeps its text, and the ticket's history in Redmine shows no change.
7. **Refused.** Take "Edit issues" and "Add notes" away from the role: "Change the ticket…" is greyed out. Take "Manage subtasks" away: the parent entries are greyed out. As `reader` there is no menu at all. On a Mac the shortcuts read Cmd.

## Several tickets at once

Run as `alex` on the demo project, then once as `reader`.

1. **Selecting.** Press "Make tickets": selection boxes appear in front of lines without a ticket, the done boxes are hidden, lines with a ticket have no box, and the bar at the bottom says "0 selected" with "Review and create" greyed out. Click a box, Shift+click a box further down: everything between is selected. "Select all in this topic" selects the topic's lines and opens its fold; pressing it again clears them. In window B, edit a selected line: it keeps its box and its tick in window A. Escape leaves selecting.
2. **From the menus.** "Make tickets from this topic…" in a topic's menu selects that topic's lines; "Select for tickets" in a line's menu selects that line.
3. **The limit.** On Lighthouse, select more than 50 lines: the bar says so and "Review and create" is greyed out.
4. **Review.** Select a point and a sub-point under it, and a line of another topic. The review lists them in agenda order, the sub-point indented, its parent "line 1.a"; the subject is the first line of each item and the rest the description. Change one row's project: its trackers, assignees and versions change. Use "Set for all rows" for the assignee: every row that offers that person takes it. The line under the heading says how many tickets will be made and that Redmine notifies as usual.
5. **Refused.** Empty one subject and create: nothing is made, that row is marked with Redmine's message, and the other rows keep what was entered. Fix it and create: the notice lists the tickets with links, the lines show their tickets, the sub-point's ticket is a child of the point's, and window B follows within a few seconds.
6. **Reader.** As `reader` there is no "Make tickets" button.

## Buttons and the sidebar card

Look at the demo project in Redmine's default theme, wide and narrow.

1. **Buttons.** In the header, "Close meeting" is filled blue with white text; "Start next meeting", "Make tickets" and "Change dates" are white with a border. On a closed agenda "Start next meeting" is the filled one. In the ticket form, the change form, the picker and the review, the create or save button is filled and Cancel is bordered. Tab through them: each shows a clear focus ring. A disabled "Review and create" (nothing selected) is grey but readable.
2. **Row controls.** The drag handle, the menu button and a ticket's arrow are always visible, grey; on the row under the pointer or with the focus they turn dark; over one of them it gets a border and a tint. On a phone or tablet they are larger (about 44 pixels).
3. **Sidebar.** The card has its heading and the period under it; on a closed agenda "As of <date>" sits right under the heading. Sections are divided by thin rules. Number tiles show a large number with the label under it; average days and overdue show "up from …" or "down from …" on a line of their own with a small triangle. Closed per person is a list with counts at the right and a faint bar behind each row. Closed tickets are grouped under small version headings, one line each, long subjects cut with "…" (hover shows the whole subject), and "Show N more" is a bordered button. Without the Progress plugin (the demo) the card starts with the number tiles and still looks complete.
4. **Sticky.** On a wide window with a short sidebar, scroll the agenda: the card stays at the top. With "Show N more" opened so the card is taller than the window, it scrolls with the page.

## Fourth round: tooltips, rail words, sparklines

1. **No stuck hints.** Point at a drag handle, a menu button and a ticket's arrow: no black tooltip appears. Drag a line by its handle and let go elsewhere; let window B change the line under your pointer: nothing stays floating over the fold row or the rail. A long closed-ticket subject in the sidebar still shows its full text on hover.
2. **Rail words.** A topic with folded lines reads "1 +2 carried" with the "+2 carried" smaller and grey; one without reads just its number; one with only folded lines reads "0 +4 carried". A screen reader names the link "Supplies and orders, 1 active line, 2 carried lines with no change". A long topic title is cut with "…" and the count stays on the same line. Edit a folded line: the rail changes at once to the same words.
3. **Sparklines.** On Lighthouse each of the five tiles has a small line beside its number, with a dot on the last point; the tiles are no taller than before. On the demo project, which has one closed meeting, the open meeting's tiles show a two-point line (that snapshot and today); with no closed meeting they show none and still look complete. A screen reader reads "Closed by meeting:" with the dates and values.

## Fifth round: badges, menu groups, tiles

1. **Rail badges.** Each topic has a filled badge with its active lines and, when lines are folded, an outlined lighter badge with the carried ones; the badges line up down the rail, also where a topic has no second badge. Point at a badge: a dark tooltip to its left says "2 active lines" or "3 carried lines with no change". Let window B change a line while you point at a badge, and drag a line: no tooltip stays behind. Tab to a rail link: the active badge's tooltip shows.
2. **Fold row.** "3 carried, no change" has a clear gap after the chevron, and the chevron sits in the middle of the line of text.
3. **Menu groups.** On a line with a ticket the menu is divided by thin rules into ticket actions, indent and outdent, move, park, and Delete last in red. ArrowDown and ArrowUp skip the rules. A topic's menu shows no stray rule at the top or bottom.
4. **Tiles.** The five number tiles leave no empty cell: Overdue spans the width under the other four, with a wider sparkline.

## Sixth round: numbers open the issue list

1. **Tiles.** Point at a number tile: its border turns blue and the pointer is a hand; Tab reaches each tile once with a focus ring. Click Closed, Opened, Still open, Average days and Overdue in turn: Redmine's issue list opens in the same tab and its count matches the tile. Click a name under "Closed per person" and "See all N in the issue list": the counts match too.
2. **Closed meeting.** Open a closed meeting: the card says "Lists show the tickets as they are now"; the links still work.
3. **Narrow tooltips.** Below about 1100 pixels, point at a rail badge: the tooltip opens above it (below it in the first row) and does not cover the topic's name.

## Seventh round: closed per project or category

1. **Per project.** On a project with a subproject (the demo project after a reset and `seed`), the card shows "Closed per project": the project first, then each subproject, an empty one in grey. The counts add up to Closed. Click each name: Redmine's list opens on that project (the subproject's list with its own subprojects) with the same count.
2. **Per category.** On a project without subprojects (Lighthouse), the card shows "Closed per category", most first, "No category" last; each name opens the list with the same count.
3. **Closed per person.** It is not shown. Turn on "Show closed per person" in the agenda settings: it appears after the per-project or per-category list, people in name order with no bars, and each name opens its list. Turn it off again.

## Eighth round: explanations

1. At a wide window, about 1000 pixels and about 600 pixels: point at Start next meeting, Close meeting, Make tickets, Change dates, the switcher, each number tile, each section heading, a drag handle, a menu button, a ticket arrow, a done box, the fold row and a rail link. After a short pause a dark note appears below (above in the selecting bar), does not cover the control and stays inside the window. Tab to the same controls: the note appears at once. Drag a line and let window B change a line under the pointer: no note stays behind.

## Ninth round: standing links

1. **Settings.** On the agenda settings page the links are rows of label, address, "Show as a button at the top" and Remove, with one empty row at the end. Add a link, move rows with the arrows, tick one for the top, Save: the rail lists them in that order, and the ticked one is a button in the header of every meeting, open or closed. Enter `javascript:alert(1)` as an address and Save: the row is marked, nothing is saved and everything typed stays. With script turned off, the existing rows still save and the empty row takes one new link.
2. **Rail.** A long label is cut with "…"; pointing at it shows the whole label. Each link opens in a new tab.
3. **Reader.** As `reader`, the links and the header button show; the settings page is refused.

## Sidebar

Run in one window, in a project with the Agenda module on and a meeting open.

1. Close a ticket in another tab and reload the agenda: the "Tickets closed" count in the sidebar goes up by one and the ticket is in the closed list.
2. Change the period's dates in the meeting header and save: the counts and the closed list follow the new period.
3. On the agenda settings page pick a saved issue query as the scope and save: the counts narrow to what the query matches.
4. Close the meeting: the sidebar says "As of" with that date, and the counts stay as they were when closing, even after another ticket is closed.
5. Start the next meeting: the sidebar shows the previous meeting's progress, average days to close and overdue count as "before", beside the current ones.
