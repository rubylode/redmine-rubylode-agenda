# Agenda browser checklist

Run by hand in the demo, once per slice. Anything the tests cannot see (focus, typing, merging polled changes) is checked here.

## Two windows

Open the same project's agenda in two browser windows, signed in as two people who may edit it. Call them window A and window B. Give the page about five seconds to catch up wherever a step says "wait".

1. **Different lines.** Add a topic with two lines. In A edit the first line, in B edit the second, leaving each field with Enter. Wait: both windows show both new texts, and neither window lost the text typed in it.
2. **Typing while someone else saves.** Click into a line in A and start typing without leaving it. In B change the same line and press Enter. Wait: A's field still holds what was typed and keeps focus. Leave the field in A without changing it further: it now shows B's text.
3. **The same line, two versions.** In A and B click into the same line and type different text in each. Press Enter in A, then in B. B shows A's text beside B's own with "Keep mine" and "Take theirs". Press "Take theirs": the field holds A's text. Repeat, and press "Keep mine": B's text is saved and appears in A after a wait.
4. **Reorder.** In A drag the last line of a topic to the top. Wait: B shows the new order. Drag a line from one topic into another in B: A follows.
5. **Delete.** In A delete a line that B is not in. Wait: it disappears from B. Delete a whole topic in B: it disappears from A.
6. **Delete under a cursor.** Click into a line in B, then delete that line in A. Wait: B drops the row; nothing else on B's page changes.
7. **Close the meeting.** In A press "Close meeting". Within a few seconds B shows "This meeting was closed" at the top of the agenda and still lets a line be edited.
8. **Hidden tab and a lost connection.** Switch window B to another tab for a minute while A adds a line; switch back: the line appears at once. Then stop the server or go offline for a minute and come back: the page catches up without a reload.
