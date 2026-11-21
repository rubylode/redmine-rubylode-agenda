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

## Sidebar

Run in one window, in a project with the Agenda module on and a meeting open.

1. Close a ticket in another tab and reload the agenda: the "Tickets closed" count in the sidebar goes up by one and the ticket is in the closed list.
2. Change the period's dates in the meeting header and save: the counts and the closed list follow the new period.
3. On the agenda settings page pick a saved issue query as the scope and save: the counts narrow to what the query matches.
4. Close the meeting: the sidebar says "As of" with that date, and the counts stay as they were when closing, even after another ticket is closed.
5. Start the next meeting: the sidebar shows the previous meeting's progress, average days to close and overdue count as "before", beside the current ones.
