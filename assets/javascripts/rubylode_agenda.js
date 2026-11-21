/* Rubylode Agenda: the meeting page.
 * Copyright (C) 2026  Nick Gorbikoff. GPL v2 or later, as the rest of the plugin.
 *
 * A Stimulus controller on the application Redmine 7 starts. Every write is one request that answers
 * { revision, topics, lines }, each record with its server-rendered row; applyEnvelope is the one function that puts
 * such an answer on the page, so a later polling request can use it unchanged. It never replaces a field that has
 * focus. Events are delegated from the controller's element, so rows that arrive later need no binding. Dragging is
 * the browser's own, started from a handle. Line fields are text areas that grow with their text; a line's depth
 * (0 lettered, 1 numbered, 2 a bullet) is stored on the server and the depth it shows at is worked out again here
 * after every change, so a gap left by another window never shows a child deeper than its place allows. One menu
 * element serves every row.
 */
import { Controller } from "@hotwired/stimulus"
import { application } from "controllers/application"

const DRAGGED_CLASS = "rubylode-agenda-dragged"
const MAXIMUM_DEPTH = 2
const LINE_ROWS = "[data-line-id], [data-draft]"
const LINE_FIELDS = "[data-field=line-text], [data-field=line-draft]"

class RubylodeAgendaController extends Controller {
  static targets = ["topics", "status", "notice", "broughtBack", "broughtBackLink", "menu"]
  static values = {
    conflictMessage: String, failureMessage: String, blankMessage: String,
    changesUrl: String, meetingId: Number, revision: Number, meetingClosed: Boolean,
    conflictTheirs: String, conflictKeepMine: String, conflictTakeTheirs: String
  }

  connect() {
    this.drag = null
    this.menuFor = null
    this.startChanges()
    this.onWindowResize = () => window.requestAnimationFrame(() => this.growWithin(this.element))
    this.onToggle = (event) => this.growWithin(event.target)
    this.onPointerDown = (event) => this.pointerDown(event)
    this.onScroll = () => this.closeMenu({ restoreFocus: false })
    window.addEventListener("resize", this.onWindowResize)
    this.element.addEventListener("toggle", this.onToggle, true) // a fold opened: its text areas can be measured now
    document.addEventListener("pointerdown", this.onPointerDown, true)
    window.addEventListener("scroll", this.onScroll, true)
    this.growWithin(this.element)
  }

  disconnect() {
    this.stopChanges()
    window.removeEventListener("resize", this.onWindowResize)
    this.element.removeEventListener("toggle", this.onToggle, true)
    document.removeEventListener("pointerdown", this.onPointerDown, true)
    window.removeEventListener("scroll", this.onScroll, true)
  }

  goToMeeting(event) {
    window.location.href = event.target.value
  }

  // ---- the one function that applies an answer

  applyEnvelope(envelope, { force = false } = {}) {
    if (this.fromAnotherMeeting(envelope)) return
    const containers = new Set()
    const freshRows = []
    for (const record of envelope.topics || []) this.applyTopic(record, force, containers, freshRows)
    for (const record of envelope.lines || []) this.applyLine(record, force, containers, freshRows)
    containers.forEach((container) => {
      if (!container.isConnected) return
      this.sortContainer(container)
      if (container !== this.topicsTarget) this.normaliseDepths(container)
    })
    freshRows.forEach((row) => this.growWithin(row))
    if (envelope.meeting_closed) this.showClosedNotice()
    if (!envelope.parked_html && this.touchesParkedList(envelope.lines || [])) this.markParkedStale()
  }

  // The answer to bringing a parked line back comes from the open meeting, which is not the one this page shows: its
  // rows and revision are not this page's.
  fromAnotherMeeting(envelope) {
    return envelope.meeting_id !== undefined && this.meetingIdValue !== 0 && envelope.meeting_id !== this.meetingIdValue
  }

  // ---- simultaneous editing: polling, waiting changes, conflicts

  startChanges() {
    this.queued = new Map()
    this.lastRevision = this.revisionValue
    this.failedPolls = 0
    this.polling = false
    this.closedAtLoad = this.meetingClosedValue
    this.onFieldEntered = (event) => this.fieldEntered(event)
    this.onFieldLeft = (event) => this.fieldLeft(event)
    this.onConflictClick = (event) => this.conflictClicked(event)
    this.onVisibilityChange = () => this.visibilityChanged()
    this.element.addEventListener("focusin", this.onFieldEntered)
    this.element.addEventListener("focusout", this.onFieldLeft)
    this.element.addEventListener("click", this.onConflictClick)
    document.addEventListener("visibilitychange", this.onVisibilityChange)
    if (this.changesUrlValue) this.scheduleChanges()
  }

  stopChanges() {
    clearTimeout(this.pollTimer)
    this.element.removeEventListener("focusin", this.onFieldEntered)
    this.element.removeEventListener("focusout", this.onFieldLeft)
    this.element.removeEventListener("click", this.onConflictClick)
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
  }

  scheduleChanges() {
    clearTimeout(this.pollTimer)
    if (document.hidden) return
    this.pollTimer = setTimeout(() => this.fetchChanges(), this.failedPolls >= 3 ? 15000 : 4000)
  }

  visibilityChanged() {
    if (!this.changesUrlValue) return
    if (document.hidden) return clearTimeout(this.pollTimer)
    clearTimeout(this.pollTimer)
    this.fetchChanges()
  }

  async fetchChanges() {
    if (this.polling || document.hidden) return
    this.polling = true
    try {
      const response = await fetch(`${this.changesUrlValue}?since=${this.lastRevision}`, {
        credentials: "same-origin",
        headers: { Accept: "application/json" }
      })
      if (!response.ok) throw new Error(`changes answered ${response.status}`)
      const envelope = await response.json()
      this.failedPolls = 0
      this.applyEnvelope(envelope)
      if (envelope.revision > this.lastRevision) this.lastRevision = envelope.revision
    } catch (error) {
      this.failedPolls += 1
    } finally {
      this.polling = false
      this.scheduleChanges()
    }
  }

  // The answer to the page's own write moves the last seen revision only when nothing else happened in between:
  // the revision rose by exactly the number of records the write changed. Otherwise the next poll delivers the
  // records again, which is harmless, and nobody else's change is skipped.
  noteOwnWrite(envelope) {
    if (this.fromAnotherMeeting(envelope)) return
    const changed = (envelope.topics || []).length + (envelope.lines || []).length
    if (envelope.revision === this.lastRevision + changed) this.lastRevision = envelope.revision
  }

  // The answer to the page's own write may wait for focus to leave its row, but the row's lock version and position
  // move at once: the person's next save of the same row must carry the version this write produced.
  acknowledgeQueuedOwnWrite(envelope) {
    const records = [...(envelope.topics || []).map((record) => ({ key: `topic:${record.id}`, selector: `[data-topic-id="${record.id}"]`, record })),
                     ...(envelope.lines || []).map((record) => ({ key: `line:${record.id}`, selector: `[data-line-id="${record.id}"]`, record }))]
    for (const { key, selector, record } of records) {
      if (this.queued.get(key) !== record) continue
      const row = this.element.querySelector(selector)
      if (!row || Number(row.dataset.lockVersion) >= record.lock_version) continue
      row.dataset.lockVersion = record.lock_version
      row.dataset.position = record.position
    }
  }

  showClosedNotice() {
    if (this.closedAtLoad || !this.hasNoticeTarget) return
    this.noticeTarget.hidden = false
  }

  // A record already on the page at this version needs no second application.
  alreadyApplied(row, record) {
    return Number(row.dataset.lockVersion) === record.lock_version &&
      Number(row.dataset.position) === record.position &&
      (record.topic_id === undefined || Number(row.dataset.topicId) === record.topic_id)
  }

  // A field with focus, or one showing a conflict, is not replaced under the person's hands.
  isBusy(element) {
    return element.contains(document.activeElement) || element.querySelector(".rubylode-agenda-conflict") !== null
  }

  // The part of a row a field belongs to: a topic's header, or the line itself.
  fieldScope(field) {
    return field.closest(".rubylode-agenda-topic-header") || field.closest("[data-line-id]")
  }

  fieldEntered(event) {
    if (event.target.matches?.("input[type=text], textarea")) event.target.dataset.focusValue = event.target.value
  }

  // Leaving a field applies what waited for it, unless the person typed in it: then their save decides, and a stale
  // one ends in the conflict choice.
  fieldLeft(event) {
    if (event.target.dataset?.field === "line-draft") return this.draftLeft(event)
    const scope = this.fieldScope(event.target)
    if (!scope || (event.relatedTarget && scope.contains(event.relatedTarget))) return
    const field = event.target
    if (field.dataset.focusValue !== undefined && field.value !== field.dataset.focusValue) return
    delete field.dataset.focusValue
    this.applyQueued(scope.closest("[data-line-id], [data-topic-id]"))
  }

  applyQueued(row) {
    const key = row.dataset.lineId ? `line:${row.dataset.lineId}` : `topic:${row.dataset.topicId}`
    const record = this.queued.get(key)
    if (!record) return
    this.queued.delete(key)
    // A newer version already on the row (the page's own later save) is not overwritten by an older waiting record. A
    // record at the row's own version was acknowledged early, so only its look is still to be applied.
    const rowVersion = Number(row.dataset.lockVersion)
    if (rowVersion > record.lock_version) return
    this.applyEnvelope(row.dataset.lineId ? { lines: [record] } : { topics: [record] }, { force: rowVersion === record.lock_version })
  }

  // A stale text save: the typed text stays in the field, the stored text is shown beside it, and the person chooses.
  showConflict(input, envelope) {
    const record = (envelope.lines || [])[0] || (envelope.topics || [])[0]
    const theirs = this.parseRow(record?.html)?.querySelector(`[data-field=${input.dataset.field}]`)
    if (!theirs) {
      this.applyEnvelope(envelope, { force: true })
      return this.showStatus(this.conflictMessageValue)
    }
    this.showStatus("")
    const scope = this.fieldScope(input)
    scope.querySelector(".rubylode-agenda-conflict")?.remove()
    const box = document.createElement("div")
    box.className = "rubylode-agenda-conflict"
    box.setAttribute("role", "alert")
    box.dataset.lockVersion = record.lock_version
    const label = document.createElement("span")
    label.className = "rubylode-agenda-conflict-label"
    label.textContent = this.conflictTheirsValue
    const text = document.createElement("span")
    text.className = "rubylode-agenda-conflict-text"
    text.textContent = theirs.value ?? theirs.textContent
    box.append(label, text, this.conflictButton("keep-mine", this.conflictKeepMineValue),
               this.conflictButton("take-theirs", this.conflictTakeTheirsValue))
    scope.append(box)
  }

  conflictButton(choice, caption) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "rubylode-agenda-conflict-choice"
    button.dataset.conflictChoice = choice
    button.textContent = caption
    return button
  }

  conflictClicked(event) {
    const button = event.target.closest?.("[data-conflict-choice]")
    if (!button) return
    const box = button.closest(".rubylode-agenda-conflict")
    const scope = box.parentElement
    const row = scope.closest("[data-line-id], [data-topic-id]")
    const input = scope.querySelector("[data-field=line-text], [data-field=topic-title]")
    row.dataset.lockVersion = box.dataset.lockVersion
    if (button.dataset.conflictChoice === "take-theirs") {
      input.value = box.querySelector(".rubylode-agenda-conflict-text").textContent
      input.dataset.original = input.value
      this.grow(input)
      box.remove()
      this.applyQueued(row)
    } else {
      box.remove()
      this.saveText(input)
    }
  }

  applyTopic(record, force, containers, freshRows) {
    const row = this.topicsTarget.querySelector(`:scope > [data-topic-id="${record.id}"]`)
    if (record.deleted) {
      this.queued.delete(`topic:${record.id}`)
      return row?.remove()
    }
    const fresh = this.parseRow(record.html)
    if (!fresh) return
    if (!row) {
      this.topicsTarget.append(fresh)
      freshRows.push(fresh)
    } else {
      if (!force && this.alreadyApplied(row, record)) return
      const header = row.querySelector(":scope > .rubylode-agenda-topic-header")
      // A header being typed in, or showing a conflict, keeps its record waiting until it is left.
      if (!force && this.isBusy(header)) return this.queued.set(`topic:${record.id}`, record)
      row.dataset.position = record.position
      row.dataset.lockVersion = record.lock_version
      // The lines are applied from their own records, so only the header is swapped.
      header.replaceWith(fresh.querySelector(":scope > .rubylode-agenda-topic-header"))
    }
    this.queued.delete(`topic:${record.id}`)
    containers.add(this.topicsTarget)
  }

  applyLine(record, force, containers, freshRows) {
    let row = this.element.querySelector(`[data-line-id="${record.id}"]`)
    // The list a row leaves needs its depths worked out again too: its children may now sit under another line.
    if (row?.parentElement) containers.add(row.parentElement)
    if (record.deleted || record.parked) {
      this.queued.delete(`line:${record.id}`)
      return row?.remove()
    }
    const container = this.element.querySelector(`[data-lines-for="${record.topic_id}"]`)
    if (!container) return row?.remove()
    const fresh = this.parseRow(record.html)
    if (!fresh) return
    if (!row) {
      row = fresh
    } else {
      if (!force && this.alreadyApplied(row, record)) return
      if (!force && this.isBusy(row)) return this.queued.set(`line:${record.id}`, record)
      row.replaceWith(fresh)
      row = fresh
    }
    this.queued.delete(`line:${record.id}`)
    freshRows.push(row)
    // A quiet line belongs in its topic's fold when the page has one; a fold is never made here.
    const target = (row.dataset.quiet === "true" && container.querySelector(":scope > .rubylode-agenda-quiet .rubylode-agenda-quiet-lines")) || container
    if (row.parentElement !== target) target.append(row)
    containers.add(target)
  }

  parseRow(html) {
    if (!html) return null
    const template = document.createElement("template")
    template.innerHTML = html.trim()
    return template.content.firstElementChild
  }

  // Rows are kept in the order of their position; a row is only moved when the order is wrong, because moving a
  // field drops its focus.
  sortContainer(container) {
    const rows = [...container.children]
    const key = (row) => [Number(row.dataset.position), Number(row.dataset.lineId || row.dataset.topicId)]
    const sorted = [...rows].sort((a, b) => key(a)[0] - key(b)[0] || key(a)[1] - key(b)[1])
    if (sorted.every((row, index) => row === rows[index])) return
    const focused = document.activeElement
    sorted.forEach((row) => container.append(row))
    if (focused && document.activeElement !== focused) focused.focus()
  }

  // ---- requests

  async send(method, path, body, { onConflict } = {}) {
    let response
    try {
      response = await fetch(path, {
        method,
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content || ""
        },
        body: body ? JSON.stringify(body) : undefined
      })
    } catch (error) {
      this.showStatus(this.failureMessageValue)
      return null
    }
    let envelope = null
    try { envelope = await response.json() } catch (error) { /* not JSON */ }
    if (response.ok && envelope) {
      this.showStatus("")
      this.noteOwnWrite(envelope)
      this.applyEnvelope(envelope)
      this.acknowledgeQueuedOwnWrite(envelope)
      return envelope
    }
    if (response.status === 409 && envelope && onConflict) {
      onConflict(envelope)
    } else if (response.status === 409 && envelope) {
      this.applyEnvelope(envelope, { force: true })
      this.showStatus(this.conflictMessageValue)
    } else if (response.status === 422 && envelope?.errors) {
      this.showStatus(envelope.errors.join(" "))
    } else {
      this.showStatus(this.failureMessageValue)
    }
    return null
  }

  showStatus(message) {
    this.statusTarget.textContent = message
    this.statusTarget.hidden = message === ""
  }

  // ---- typing and ticking
  //
  // In a line, Enter is a line break inside the item and Shift+Enter finishes it and opens a new item below, at the same
  // depth. Tab and Shift+Tab change the depth when the place allows it, and otherwise move the focus as usual. ArrowUp at
  // the very start and ArrowDown at the very end of a field move to the item above or below. A topic title is one line:
  // Enter saves it.

  keydown(event) {
    if (event.target.closest?.("[role=menu]")) return this.menuKey(event)
    const field = event.target.dataset?.field
    if (!field || event.isComposing) return
    const input = event.target
    const inLine = field === "line-text" || field === "line-draft"
    const bare = !event.ctrlKey && !event.metaKey && !event.altKey
    if (event.key === "Enter" && bare) {
      if (field === "topic-new") { event.preventDefault(); this.createTopic(input) }
      else if (field === "topic-title") { event.preventDefault(); this.saveText(input); input.blur() }
      else if (event.shiftKey) this.finishItem(event, input, field)
      // A plain Enter in a line is the text area's own line break.
    } else if (event.key === "Tab" && inLine && bare) {
      if (this.changeDepth(input, event.shiftKey ? -1 : 1)) event.preventDefault()
    } else if (event.key === "Backspace" && field === "line-draft" && input.value === "" && bare && !event.shiftKey) {
      event.preventDefault()
      this.removeDraft(input.closest("[data-draft]"), { focusAbove: true })
    } else if ((event.key === "ArrowUp" || event.key === "ArrowDown") && (inLine || field === "line-new")) {
      this.moveBetweenItems(event, input)
    } else if (event.altKey && event.code === "KeyP" && field === "line-text") {
      event.preventDefault()
      this.park(input.closest("[data-line-id]"))
    } else if (event.key === "Escape" && field === "line-draft") {
      this.removeDraft(input.closest("[data-draft]"), { focusAbove: true })
    } else if (event.key === "Escape" && input.dataset.original !== undefined) {
      input.value = input.dataset.original
      this.grow(input)
      input.blur()
    }
  }

  // Shift+Enter: the field's text is saved and the next item opens.
  finishItem(event, input, field) {
    event.preventDefault()
    if (field === "line-new") return this.createLine(input)
    if (field === "line-draft") return this.saveDraft(input, { then: "next" })
    const row = input.closest("[data-line-id]")
    if (input.value.trim() === "") return // a blank line is not saved; the message says why when the field is left
    this.saveText(input)
    this.openDraftAfter(row)
  }

  input(event) {
    this.grow(event.target)
  }

  change(event) {
    const field = event.target.dataset?.field
    if (field === "line-text" || field === "topic-title") this.saveText(event.target)
    else if (field === "line-done") this.saveDone(event.target)
    else if (field === "topic-owner") this.saveOwner(event.target)
  }

  click(event) {
    const entry = event.target.closest?.("[data-menu-action]")
    if (entry && !entry.disabled) this.runMenuAction(entry.dataset.menuAction)
  }

  async createLine(input) {
    const text = input.value.trim()
    if (text === "") return
    input.disabled = true
    const envelope = await this.send("POST", input.dataset.createPath, { text })
    input.disabled = false
    if (envelope) input.value = ""
    this.grow(input)
    input.focus() // the empty line below the new one is the next place to type
  }

  async createTopic(input) {
    const title = input.value.trim()
    if (title === "") return
    input.disabled = true
    const envelope = await this.send("POST", input.dataset.createPath, { title })
    input.disabled = false
    if (!envelope) return input.focus()
    input.value = ""
    this.topicsTarget.querySelector(`[data-topic-id="${envelope.topics[0].id}"] [data-field=line-new]`)?.focus()
  }

  saveText(input) {
    const row = input.closest("[data-line-id], [data-topic-id]")
    const text = input.value.trim()
    if (text === input.dataset.original) return
    if (text === "") {
      input.value = input.dataset.original
      this.grow(input)
      return this.showStatus(this.blankMessageValue)
    }
    const previous = input.dataset.original
    input.dataset.original = text
    const key = input.dataset.field === "line-text" ? "text" : "title"
    const body = { [key]: text, lock_version: row.dataset.lockVersion }
    this.send("PATCH", row.dataset.updatePath, body, { onConflict: (envelope) => this.showConflict(input, envelope) }).then((envelope) => {
      if (!envelope) input.dataset.original = previous
    })
  }

  saveDone(checkbox) {
    const row = checkbox.closest("[data-line-id]")
    row.classList.toggle("rubylode-agenda-line-done", checkbox.checked)
    this.send("PATCH", row.dataset.updatePath, { done: checkbox.checked ? "1" : "0", lock_version: row.dataset.lockVersion })
  }

  saveOwner(select) {
    const row = select.closest("[data-topic-id]")
    this.send("PATCH", row.dataset.updatePath, { owner_id: select.value, lock_version: row.dataset.lockVersion })
  }

  // ArrowUp with the caret at the very start, or ArrowDown at the very end, moves to the item above or below, so the
  // caret still moves freely inside an item of several lines.
  moveBetweenItems(event, input) {
    if (event.shiftKey || event.altKey || event.ctrlKey || event.metaKey) return
    const up = event.key === "ArrowUp"
    const length = input.value.length
    const atStart = input.selectionStart === 0 && input.selectionEnd === 0
    const atEnd = input.selectionStart === length && input.selectionEnd === length
    if (up ? !atStart : !atEnd) return
    const fields = [...this.topicsTarget.querySelectorAll(`${LINE_FIELDS}, [data-field=line-new]`)]
      .filter((element) => element.offsetParent !== null) // a closed fold's lines are skipped
    const next = fields[fields.indexOf(input) + (up ? -1 : 1)]
    if (!next) return
    event.preventDefault()
    this.focusField(next, up ? "end" : "start")
  }

  focusField(field, where = "end") {
    if (!field) return
    field.focus({ preventScroll: false })
    const caret = where === "end" ? field.value.length : 0
    try { field.setSelectionRange(caret, caret) } catch (error) { /* not a text field */ }
  }

  // ---- growing text areas

  // A line's text area is as tall as its text: no inner scroll bar and no sideways scrolling. A hidden one (in a closed
  // fold) cannot be measured and is grown when the fold opens.
  grow(field) {
    if (!field?.matches?.("textarea.rubylode-agenda-line-text") || field.offsetParent === null) return
    field.style.height = "auto"
    field.style.height = `${field.scrollHeight + field.offsetHeight - field.clientHeight}px`
  }

  // Many fields at once are measured in one pass, so a long agenda lays out three times, not three times per line.
  growWithin(element) {
    const fields = [...(element?.querySelectorAll?.("textarea.rubylode-agenda-line-text") || [])]
      .filter((field) => field.offsetParent !== null)
    fields.forEach((field) => { field.style.height = "auto" })
    const heights = fields.map((field) => field.scrollHeight + field.offsetHeight - field.clientHeight)
    fields.forEach((field, index) => { field.style.height = `${heights[index]}px` })
  }

  // ---- sub-points

  // The depth a row shows at, from its class (the server's reading, or the last one made here).
  shownDepth(row) {
    return Number(row.className.match(/rubylode-agenda-depth-(\d)/)?.[1] || 0)
  }

  showDepth(row, depth) {
    for (let level = 0; level <= MAXIMUM_DEPTH; level += 1) row.classList.toggle(`rubylode-agenda-depth-${level}`, level === depth)
  }

  // Each row shows its stored depth, but never more than one below the row shown above it; the first row is at 0. The
  // fold of quiet lines is a list of its own and starts again at 0. Nothing is saved here.
  normaliseDepths(container) {
    let above = -1
    for (const row of container.children) {
      if (!row.matches(LINE_ROWS)) continue
      const shown = Math.max(0, Math.min(Number(row.dataset.depth) || 0, above + 1, MAXIMUM_DEPTH))
      this.showDepth(row, shown)
      above = shown
    }
  }

  lineRowBeside(row, step) {
    let sibling = step < 0 ? row.previousElementSibling : row.nextElementSibling
    while (sibling && !sibling.matches(LINE_ROWS)) sibling = step < 0 ? sibling.previousElementSibling : sibling.nextElementSibling
    return sibling
  }

  deepestAllowed(row) {
    const above = this.lineRowBeside(row, -1)
    return above ? Math.min(this.shownDepth(above) + 1, MAXIMUM_DEPTH) : 0
  }

  // Answers false when the depth cannot change, so Tab keeps its usual meaning and nobody is trapped in the list.
  changeDepth(input, step) {
    const row = input.closest(LINE_ROWS)
    if (!row) return false
    const wanted = this.shownDepth(row) + step
    if (wanted < 0 || wanted > this.deepestAllowed(row)) return false
    const previousDepth = row.dataset.depth
    row.dataset.depth = wanted
    this.normaliseDepths(row.parentElement)
    if (row.dataset.lineId) this.saveDepth(row, wanted, previousDepth)
    return true
  }

  // The depth goes through the same write as the text, with the lock version; text typed and not yet saved goes along,
  // so the two never race each other.
  saveDepth(row, depth, previousDepth) {
    const field = row.querySelector("[data-field=line-text]")
    const body = { depth, lock_version: row.dataset.lockVersion }
    const text = field?.value.trim()
    const previousText = field?.dataset.original
    if (field && text !== "" && text !== previousText) {
      body.text = text
      field.dataset.original = text
    }
    const onConflict = field && body.text ? (envelope) => this.showConflict(field, envelope) : undefined
    this.send("PATCH", row.dataset.updatePath, body, { onConflict }).then((envelope) => {
      if (envelope || !row.isConnected) return
      row.dataset.depth = previousDepth
      this.normaliseDepths(row.parentElement)
      if (field && body.text) field.dataset.original = previousText
    })
  }

  // ---- new items opened below a line

  // A new item right below a line, at its depth: a row of its own that is saved when it is finished (Shift+Enter) or
  // left with text in it, and dropped when it is left empty, on Escape, or on Backspace while empty.
  openDraftAfter(row, depth = this.shownDepth(row)) {
    const createField = row.closest(".rubylode-agenda-topic")?.querySelector("[data-field=line-new]")
    if (!createField) return
    const draft = document.createElement("li")
    draft.className = "rubylode-agenda-line rubylode-agenda-line-draft"
    draft.dataset.draft = ""
    draft.dataset.depth = depth
    draft.dataset.afterId = row.dataset.lineId
    draft.dataset.position = Number(row.dataset.position) + 0.5
    for (const selector of ["[data-field=line-handle]", "[data-field=line-done]"]) {
      const placeholder = row.querySelector(selector)?.cloneNode(true)
      if (!placeholder) continue
      placeholder.removeAttribute("data-field")
      placeholder.removeAttribute("draggable")
      placeholder.setAttribute("aria-hidden", "true")
      if (placeholder.matches("input")) { placeholder.disabled = true; placeholder.checked = false; placeholder.tabIndex = -1 }
      placeholder.classList.add("rubylode-agenda-placeholder")
      draft.append(placeholder)
    }
    const field = document.createElement("textarea")
    field.className = "rubylode-agenda-line-text"
    field.rows = 1
    field.maxLength = createField.maxLength
    field.dataset.field = "line-draft"
    field.dataset.createPath = createField.dataset.createPath
    field.dataset.action = "keydown->rubylode-agenda#lineTicketKey"
    field.setAttribute("aria-label", createField.getAttribute("aria-label"))
    draft.append(field)
    row.after(draft)
    this.normaliseDepths(draft.parentElement)
    this.grow(field)
    field.focus()
  }

  // Saves a new item. then: "next" opens another item below the saved one, "form" opens the ticket form on it.
  async saveDraft(field, { then = null } = {}) {
    const draft = field.closest("[data-draft]")
    if (!draft || draft.dataset.saving) return
    const text = field.value.trim()
    if (text === "") return then === null ? this.removeDraft(draft) : undefined
    draft.dataset.saving = "true"
    field.readOnly = true
    const body = { text, depth: Number(draft.dataset.depth) || 0 }
    if (draft.dataset.afterId) body.after_id = draft.dataset.afterId
    const envelope = await this.send("POST", field.dataset.createPath, body)
    if (!envelope) {
      delete draft.dataset.saving
      field.readOnly = false
      if (then !== null) field.focus()
      return
    }
    const made = this.element.querySelector(`[data-line-id="${envelope.lines[0].id}"]`)
    const container = draft.parentElement
    draft.remove()
    if (container) this.normaliseDepths(container)
    if (!made) return
    if (then === "next") this.openDraftAfter(made, Number(made.dataset.depth) || 0)
    else if (then === "form") this.openTicketForm(made)
  }

  draftLeft(event) {
    const draft = event.target.closest("[data-draft]")
    if (!draft?.isConnected || draft.dataset.saving) return
    if (event.relatedTarget && draft.contains(event.relatedTarget)) return
    this.saveDraft(event.target)
  }

  removeDraft(draft, { focusAbove = false } = {}) {
    if (!draft?.isConnected) return
    const above = this.lineRowBeside(draft, -1)
    const container = draft.parentElement
    draft.dataset.saving = "true" // its own focusout must not try to save it
    draft.remove()
    this.normaliseDepths(container)
    if (focusAbove) this.focusField(above?.querySelector(LINE_FIELDS), "end")
  }

  // ---- the menu of a row
  //
  // One element serves every row: the row's menu button or a right click opens it for that row. A right click in a
  // field with text selected, or with Shift held, keeps the browser's own menu.

  openMenuFromButton(event) {
    const button = event.currentTarget
    const row = this.menuRow(button)
    if (!row) return
    const box = button.getBoundingClientRect()
    this.openMenu(row, box.left, box.bottom, button)
  }

  contextMenu(event) {
    if (!this.hasMenuTarget || event.shiftKey) return
    if (event.target.closest?.("[role=menu], a, .rubylode-agenda-line-detail, .rubylode-agenda-conflict")) return
    const row = this.menuRow(event.target)
    if (!row) return
    const field = event.target.closest("textarea, input[type=text]")
    if (field && field.selectionStart !== field.selectionEnd) return
    event.preventDefault()
    let { clientX: left, clientY: top } = event
    if (left === 0 && top === 0) ({ left, bottom: top } = row.getBoundingClientRect()) // opened from the keyboard
    this.openMenu(row, left, top, field || this.rowField(row))
  }

  // The row a menu belongs to: a line of the agenda, or a topic by its header. Answers null for anything else.
  menuRow(element) {
    const line = element.closest?.("[data-line-id]")
    if (line) return line.dataset.updatePath ? line : null
    const header = element.closest?.(".rubylode-agenda-topic-header")
    const topic = header?.closest("[data-topic-id]")
    return topic?.dataset.updatePath ? topic : null
  }

  rowField(row) {
    return row.dataset.lineId ? row.querySelector("[data-field=line-text]") : row.querySelector("[data-field=topic-title]")
  }

  findMenuRow() {
    if (!this.menuFor) return null
    const { kind, id } = this.menuFor
    return kind === "line" ? this.element.querySelector(`[data-line-id="${id}"]`) : this.topicsTarget.querySelector(`:scope > [data-topic-id="${id}"]`)
  }

  openMenu(row, left, top, returnTo) {
    if (!this.hasMenuTarget) return
    const menu = this.menuTarget
    const kind = row.dataset.lineId ? "line" : "topic"
    this.menuFor = { kind, id: row.dataset.lineId || row.dataset.topicId, returnTo }
    for (const entry of menu.querySelectorAll("[data-menu-action]")) {
      const applies = entry.dataset.menuRows === "any" || entry.dataset.menuRows === kind
      const state = applies ? this.menuEntryState(entry.dataset.menuAction, row, kind) : "hidden"
      entry.hidden = state === "hidden"
      entry.disabled = state === "disabled"
      entry.setAttribute("aria-disabled", String(state === "disabled"))
    }
    menu.hidden = false
    menu.style.left = "0px"
    menu.style.top = "0px"
    const { width, height } = menu.getBoundingClientRect()
    menu.style.left = `${Math.max(0, Math.min(left, window.innerWidth - width - 4))}px`
    menu.style.top = `${Math.max(0, Math.min(top, window.innerHeight - height - 4))}px`
    this.menuEntries()[0]?.focus({ preventScroll: true })
  }

  // "enabled", "disabled" (shown, but does not apply to this row now) or "hidden" (the other choice of a pair).
  menuEntryState(action, row, kind) {
    const enabled = (condition) => (condition ? "enabled" : "disabled")
    if (kind === "topic") {
      const topics = [...this.topicsTarget.children].filter((element) => element.dataset.topicId)
      const index = topics.indexOf(row)
      if (action === "move-up") return enabled(index > 0)
      if (action === "move-down") return enabled(index < topics.length - 1)
      return "enabled"
    }
    switch (action) {
      case "make-ticket": return row.dataset.ticketPath ? "hidden" : enabled(row.dataset.newTicketPath)
      case "open-ticket":
      case "show-ticket": return row.dataset.ticketPath ? "enabled" : "hidden"
      case "indent": return enabled(this.shownDepth(row) + 1 <= this.deepestAllowed(row))
      case "outdent": return enabled(this.shownDepth(row) > 0)
      case "move-up": return enabled(this.lineRowBeside(row, -1)?.dataset.lineId)
      case "move-down": return enabled(this.lineRowBeside(row, 1)?.dataset.lineId)
      default: return "enabled"
    }
  }

  menuEntries() {
    return [...this.menuTarget.querySelectorAll("[data-menu-action]")].filter((entry) => !entry.hidden && !entry.disabled)
  }

  menuKey(event) {
    const entries = this.menuEntries()
    const index = entries.indexOf(document.activeElement)
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      entries[(index + step + entries.length) % entries.length]?.focus({ preventScroll: true })
    } else if (event.key === "Home" || event.key === "End") {
      event.preventDefault()
      entries[event.key === "Home" ? 0 : entries.length - 1]?.focus({ preventScroll: true })
    } else if (event.key === "Escape" || event.key === "Tab") {
      event.preventDefault()
      this.closeMenu()
    }
  }

  closeMenu({ restoreFocus = true } = {}) {
    if (!this.hasMenuTarget || this.menuTarget.hidden) return
    this.menuTarget.hidden = true
    if (restoreFocus) this.restoreMenuFocus()
    this.menuFor = null
  }

  restoreMenuFocus() {
    const returnTo = this.menuFor?.returnTo
    const row = this.findMenuRow()
    const target = returnTo?.isConnected ? returnTo : row && this.rowField(row)
    target?.focus({ preventScroll: true })
  }

  pointerDown(event) {
    if (!this.hasMenuTarget || this.menuTarget.hidden || this.menuTarget.contains(event.target)) return
    this.closeMenu({ restoreFocus: false })
  }

  runMenuAction(action) {
    const row = this.findMenuRow()
    const kind = this.menuFor?.kind
    const keepsFocus = ["indent", "outdent", "move-up", "move-down"].includes(action)
    if (keepsFocus) this.closeMenu()
    else this.closeMenu({ restoreFocus: false })
    if (!row) return
    switch (action) {
      case "make-ticket": return this.openTicketForm(row)
      case "open-ticket": return window.open(row.dataset.issuePath, "_blank", "noopener")
      case "show-ticket": return row.querySelector(".rubylode-agenda-ticket-toggle")?.click()
      case "indent": return this.changeDepth(this.rowField(row), 1)
      case "outdent": return this.changeDepth(this.rowField(row), -1)
      case "move-up": return this.moveRow(row, kind, -1)
      case "move-down": return this.moveRow(row, kind, 1)
      case "park": return this.park(row)
      case "delete":
        if (kind === "topic" && !window.confirm(this.menuTarget.dataset.topicConfirm)) return
        return this.send("DELETE", row.dataset.updatePath)
    }
  }

  // Moves a row one place with the same request as dragging. Two lines named swap their places and nothing else moves;
  // topics are sent in their whole new order.
  moveRow(row, kind, step) {
    if (kind === "line") {
      const other = this.lineRowBeside(row, step)
      if (!other?.dataset.lineId) return
      const ids = step < 0 ? [row.dataset.lineId, other.dataset.lineId] : [other.dataset.lineId, row.dataset.lineId]
      return this.send("POST", row.closest("[data-lines-for]").dataset.reorderPath, { ids })
    }
    const topics = [...this.topicsTarget.children].filter((element) => element.dataset.topicId)
    const index = topics.indexOf(row)
    const other = topics[index + step]
    if (!other) return
    topics[index] = other
    topics[index + step] = row
    return this.send("POST", this.topicsTarget.dataset.reorderPath, { ids: topics.map((element) => element.dataset.topicId) })
  }

  // ---- dragging

  dragStart(event) {
    const handle = event.target.closest?.("[data-field=line-handle], [data-field=topic-handle]")
    if (!handle) return
    const row = handle.closest("[data-line-id], [data-topic-id]")
    this.drag = { row, kind: row.dataset.lineId ? "line" : "topic", parent: row.parentElement, next: row.nextElementSibling, dropped: false }
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", row.dataset.lineId || row.dataset.topicId)
    event.dataTransfer.setDragImage(row, 0, 0)
    row.classList.add(DRAGGED_CLASS)
  }

  dragOver(event) {
    if (!this.drag) return
    const container = this.dropContainer(event.target)
    if (!container) return
    event.preventDefault()
    const siblings = [...container.children].filter((row) => row !== this.drag.row)
    const following = siblings.find((row) => {
      const box = row.getBoundingClientRect()
      return event.clientY < box.top + box.height / 2
    })
    if (following) {
      if (this.drag.row.nextElementSibling !== following) container.insertBefore(this.drag.row, following)
    } else if (container.lastElementChild !== this.drag.row) {
      container.append(this.drag.row)
    }
  }

  dropContainer(target) {
    if (this.drag.kind === "topic") return this.topicsTarget
    return target.closest?.(".rubylode-agenda-topic")?.querySelector(":scope > [data-lines-for]")
  }

  async drop(event) {
    if (!this.drag) return
    event.preventDefault()
    this.drag.dropped = true
    const container = this.drag.row.parentElement
    const ids = [...container.children].map((row) => row.dataset.lineId || row.dataset.topicId).filter(Boolean) // the fold row names no line
    const envelope = await this.send("POST", container.dataset.reorderPath, { ids })
    if (!envelope) this.putBack()
  }

  dragEnd() {
    if (!this.drag) return
    this.drag.row.classList.remove(DRAGGED_CLASS)
    if (!this.drag.dropped) this.putBack()
    this.drag = null
  }

  putBack() {
    if (!this.drag) return
    this.drag.parent.insertBefore(this.drag.row, this.drag.next)
  }

  // ---- tickets, folding and parking. These are bound by data-action on the rows themselves.

  csrfToken() {
    return document.querySelector("meta[name=csrf-token]")?.content || ""
  }

  // A request whose answer is an HTML fragment, not an envelope. Answers the text, or null after showing why not.
  async fetchFragment(method, path, body) {
    let response
    try {
      response = await fetch(path, {
        method,
        credentials: "same-origin",
        headers: { Accept: "text/html", "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken() },
        body: body ? JSON.stringify(body) : undefined
      })
    } catch (error) {
      this.showStatus(this.failureMessageValue)
      return null
    }
    if (response.ok) {
      this.showStatus("")
      return response.text()
    }
    let errors = null
    try { errors = (await response.json()).errors } catch (error) { /* not JSON */ }
    this.showStatus(errors ? errors.join(" ") : this.failureMessageValue)
    return null
  }

  rowPanel(row, role) {
    return row.querySelector(`:scope > [data-role=${role}]`)
  }

  // The number-side toggle of a linked line: opens the ticket under the line, or closes it.
  async toggleTicket(event) {
    const button = event.currentTarget
    const row = button.closest("[data-line-id]")
    const panel = this.rowPanel(row, "ticket-detail")
    if (panel.childElementCount > 0) {
      panel.replaceChildren()
      button.setAttribute("aria-expanded", "false")
      return
    }
    const html = await this.fetchFragment("GET", row.dataset.ticketPath)
    if (html === null) return
    panel.innerHTML = html
    button.setAttribute("aria-expanded", "true")
  }

  async addNote(event) {
    event.preventDefault()
    const form = event.currentTarget
    const panel = form.closest("[data-role=ticket-detail]")
    const html = await this.fetchFragment("POST", form.action, { notes: form.elements.notes.value })
    if (html !== null) panel.innerHTML = html
  }

  // Ctrl+Enter (Cmd+Enter) in a line opens the ticket form under it; in the empty line or a new item it first makes the
  // line.
  lineTicketKey(event) {
    if (event.key !== "Enter" || !(event.ctrlKey || event.metaKey) || event.isComposing) return
    event.preventDefault()
    const field = event.target.dataset.field
    if (field === "line-new") this.createLineThenForm(event.target)
    else if (field === "line-draft") this.saveDraft(event.target, { then: "form" })
    else this.openTicketForm(event.target.closest("[data-line-id]"))
  }

  async createLineThenForm(input) {
    const text = input.value.trim()
    if (text === "") return
    input.disabled = true
    const envelope = await this.send("POST", input.dataset.createPath, { text })
    input.disabled = false
    if (!envelope) return input.focus()
    input.value = ""
    this.grow(input)
    const row = this.element.querySelector(`[data-line-id="${envelope.lines[0].id}"]`)
    if (row) this.openTicketForm(row)
  }

  async openTicketForm(row) {
    if (!row?.dataset.newTicketPath) return // already linked, or the person may not add tickets
    const panel = this.rowPanel(row, "ticket-form")
    if (panel.childElementCount > 0) return panel.querySelector("[name=subject]").focus()
    const html = await this.fetchFragment("GET", row.dataset.newTicketPath)
    if (html === null) return
    panel.innerHTML = html
    const form = panel.querySelector("form")
    // What is typed and not yet saved wins: its first line is the subject and the rest the description.
    const typed = row.querySelector("[data-field=line-text]")?.value.trim()
    if (typed) {
      const [subject, ...rest] = typed.split("\n")
      form.elements.subject.value = subject.trim()
      if (form.elements.description) form.elements.description.value = rest.join("\n").trim()
    }
    this.restoreTracker(form.elements.tracker_id)
    form.elements.subject.focus()
    form.elements.subject.select()
  }

  restoreTracker(select) {
    try {
      const remembered = window.localStorage.getItem("rubylodeAgendaLastTracker")
      if (remembered && [...select.options].some((option) => option.value === remembered)) select.value = remembered
    } catch (error) { /* storage is blocked: the first tracker stays */ }
  }

  rememberTracker(trackerId) {
    try { window.localStorage.setItem("rubylodeAgendaLastTracker", trackerId) } catch (error) { /* storage is blocked */ }
  }

  async createTicket(event) {
    event.preventDefault()
    const form = event.currentTarget
    const row = form.closest("[data-line-id]")
    const body = Object.fromEntries(new FormData(form))
    delete body.authenticity_token
    body.lock_version = row.dataset.lockVersion
    this.rememberTracker(body.tracker_id)
    const submit = form.querySelector("[type=submit]")
    submit.disabled = true
    const envelope = await this.send("POST", form.action, body)
    submit.disabled = false
    if (!envelope) return
    form.closest("[data-role=ticket-form]").replaceChildren()
    this.applyEnvelope(envelope, { force: true }) // the focus was in the form, so the first apply left the row alone
  }

  ticketFormKey(event) {
    if (event.key === "Escape") return this.closeTicketForm(event)
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey) && !event.isComposing) {
      event.preventDefault()
      event.currentTarget.requestSubmit()
    }
  }

  closeTicketForm(event) {
    const row = event.target.closest("[data-line-id]")
    this.rowPanel(row, "ticket-form").replaceChildren()
    row.querySelector("[data-field=line-text]")?.focus()
  }

  async park(row) {
    if (!row?.dataset.parkPath) return
    const envelope = await this.send("POST", row.dataset.parkPath, { lock_version: row.dataset.lockVersion })
    if (envelope) this.replaceParkedList(envelope.parked_html)
  }

  async unparkLine(event) {
    const envelope = await this.send("POST", event.currentTarget.dataset.unparkPath, {})
    if (!envelope) return
    this.replaceParkedList(envelope.parked_html)
    if (this.fromAnotherMeeting(envelope) && envelope.meeting_path && this.hasBroughtBackTarget) {
      this.broughtBackLinkTarget.href = envelope.meeting_path
      this.broughtBackTarget.hidden = false
    }
  }

  // A line that is parked, or that left the parked list, changes a list this page was not sent: say so, never guess it.
  touchesParkedList(records) {
    return records.some((record) => record.parked || this.element.querySelector(`[data-parked-line-id="${record.id}"]`))
  }

  markParkedStale() {
    const parkedList = this.element.querySelector(".rubylode-agenda-parked")
    if (!parkedList || parkedList.querySelector(".rubylode-agenda-parked-stale")) return
    const hint = document.createElement("span")
    hint.className = "rubylode-agenda-parked-stale"
    hint.textContent = ` (${parkedList.dataset.staleText})`
    parkedList.hidden = false
    parkedList.querySelector("summary").append(hint)
  }

  // The parked list is not a record, so the answer to parking carries it whole; whether it is open is kept.
  replaceParkedList(html) {
    const current = this.element.querySelector(".rubylode-agenda-parked")
    const fresh = this.parseRow(html)
    if (!current || !fresh) return
    fresh.open = current.open
    current.replaceWith(fresh)
  }
}

// The fold of quiet lines keeps its count true when a line leaves it (an edited line moves out into the list), and
// goes away when it is empty.
class RubylodeAgendaFoldController extends Controller {
  static targets = ["count"]

  connect() {
    this.observer = new MutationObserver(() => this.recount())
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer.disconnect()
  }

  recount() {
    const count = this.element.querySelectorAll("li[data-line-id]").length
    if (count === 0) return this.element.remove()
    if (this.countTarget.textContent !== String(count)) this.countTarget.textContent = count
  }
}

application.register("rubylode-agenda", RubylodeAgendaController)
application.register("rubylode-agenda-fold", RubylodeAgendaFoldController)
