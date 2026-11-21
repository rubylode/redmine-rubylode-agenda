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
    this.applyEnvelope(row.dataset.lineId ? { lines: [record] } : { topics: [record] })
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
    if (record.deleted) {
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
    const next = row.nextElementSibling?.querySelector("[data-field=line-text]")
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
}

application.register("rubylode-agenda", RubylodeAgendaController)
