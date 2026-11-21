/* Rubylode Agenda: the meeting page.
 * Copyright (C) 2026  Nick Gorbikoff. GPL v2 or later, as the rest of the plugin.
 *
 * A Stimulus controller on the application Redmine 7 starts. Every write is one request that answers
 * { revision, topics, lines }, each record with its server-rendered row; applyEnvelope is the one function that puts
 * such an answer on the page, so a later polling request can use it unchanged. It never replaces a field that has
 * focus. Events are delegated from the controller's element, so rows that arrive later need no binding. Dragging is
 * the browser's own, started from a handle.
 */
import { Controller } from "@hotwired/stimulus"
import { application } from "controllers/application"

const DRAGGED_CLASS = "rubylode-agenda-dragged"

class RubylodeAgendaController extends Controller {
  static targets = ["topics", "status", "notice"]
  static values = {
    conflictMessage: String, failureMessage: String, blankMessage: String,
    changesUrl: String, revision: Number, meetingClosed: Boolean,
    conflictTheirs: String, conflictKeepMine: String, conflictTakeTheirs: String
  }

  connect() {
    this.drag = null
    this.startChanges()
  }

  disconnect() {
    this.stopChanges()
  }

  goToMeeting(event) {
    window.location.href = event.target.value
  }

  // ---- the one function that applies an answer

  applyEnvelope(envelope, { force = false } = {}) {
    const containers = new Set()
    for (const record of envelope.topics || []) this.applyTopic(record, force, containers)
    for (const record of envelope.lines || []) this.applyLine(record, force, containers)
    containers.forEach((container) => this.sortContainer(container))
    if (envelope.meeting_closed) this.showClosedNotice()
    if (!envelope.parked_html && this.touchesParkedList(envelope.lines || [])) this.markParkedStale()
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
    if (event.target.matches?.("input[type=text]")) event.target.dataset.focusValue = event.target.value
  }

  // Leaving a field applies what waited for it, unless the person typed in it: then their save decides, and a stale
  // one ends in the conflict choice.
  fieldLeft(event) {
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
    text.textContent = theirs.value
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
      box.remove()
      this.applyQueued(row)
    } else {
      box.remove()
      this.saveText(input)
    }
  }

  applyTopic(record, force, containers) {
    const row = this.topicsTarget.querySelector(`:scope > [data-topic-id="${record.id}"]`)
    if (record.deleted) {
      this.queued.delete(`topic:${record.id}`)
      return row?.remove()
    }
    const fresh = this.parseRow(record.html)
    if (!fresh) return
    if (!row) {
      this.topicsTarget.append(fresh)
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

  applyLine(record, force, containers) {
    let row = this.element.querySelector(`[data-line-id="${record.id}"]`)
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
    if (row.parentElement !== container) container.append(row)
    containers.add(container)
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

  keydown(event) {
    const field = event.target.dataset?.field
    if (!field || event.isComposing) return
    if (event.key === "Enter" && !event.ctrlKey && !event.metaKey) {
      if (field === "line-new") { event.preventDefault(); this.createLine(event.target) }
      else if (field === "topic-new") { event.preventDefault(); this.createTopic(event.target) }
      else if (field === "line-text" || field === "topic-title") { event.preventDefault(); this.saveText(event.target); this.focusAfter(event.target) }
    } else if (event.altKey && event.code === "KeyP" && field === "line-text") {
      event.preventDefault()
      this.park(event.target.closest("[data-line-id]")?.querySelector("[data-park-path]"))
    } else if (event.key === "Escape" && event.target.dataset.original !== undefined) {
      event.target.value = event.target.dataset.original
      event.target.blur()
    }
  }

  change(event) {
    const field = event.target.dataset?.field
    if (field === "line-text" || field === "topic-title") this.saveText(event.target)
    else if (field === "line-done") this.saveDone(event.target)
    else if (field === "topic-owner") this.saveOwner(event.target)
  }

  click(event) {
    const button = event.target.closest("[data-field=line-delete], [data-field=topic-delete]")
    if (!button) return
    const row = button.closest("[data-line-id], [data-topic-id]")
    if (button.dataset.field === "topic-delete" && !window.confirm(button.dataset.confirm)) return
    this.send("DELETE", row.dataset.updatePath)
  }

  async createLine(input) {
    const text = input.value.trim()
    if (text === "") return
    input.disabled = true
    const envelope = await this.send("POST", input.dataset.createPath, { text })
    input.disabled = false
    if (envelope) input.value = ""
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

  // Enter in a line moves to the next line of the topic, or to the empty line at its end.
  focusAfter(input) {
    const row = input.closest("[data-line-id]")
    if (!row) return input.blur()
    const sibling = row.nextElementSibling // the fold of quiet lines, when it follows, is closed: nothing to focus there
    const next = sibling?.matches("[data-line-id]") ? sibling.querySelector("[data-field=line-text]") : null
    ;(next || row.closest(".rubylode-agenda-topic").querySelector("[data-field=line-new]")).focus()
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
    const ids = [...container.children].map((row) => row.dataset.lineId || row.dataset.topicId)
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

  // Ctrl+Enter (Cmd+Enter) in a line opens the ticket form under it; in the empty line it first makes the line.
  lineTicketKey(event) {
    if (event.key !== "Enter" || !(event.ctrlKey || event.metaKey) || event.isComposing) return
    event.preventDefault()
    if (event.target.dataset.field === "line-new") this.createLineThenForm(event.target)
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
    const typed = row.querySelector("[data-field=line-text]")?.value.trim()
    if (typed) form.elements.subject.value = typed
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

  parkLine(event) {
    return this.park(event.currentTarget)
  }

  async park(button) {
    if (!button) return
    const row = button.closest("[data-line-id]")
    const envelope = await this.send("POST", button.dataset.parkPath, { lock_version: row.dataset.lockVersion })
    if (envelope) this.replaceParkedList(envelope.parked_html)
  }

  async unparkLine(event) {
    const envelope = await this.send("POST", event.currentTarget.dataset.unparkPath, {})
    if (envelope) this.replaceParkedList(envelope.parked_html)
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
