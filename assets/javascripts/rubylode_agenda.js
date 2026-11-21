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
  static targets = ["topics", "status"]
  static values = { conflictMessage: String, failureMessage: String, blankMessage: String }

  connect() {
    this.drag = null
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
  }

  applyTopic(record, force, containers) {
    const row = this.topicsTarget.querySelector(`:scope > [data-topic-id="${record.id}"]`)
    if (record.deleted) return row?.remove()
    const fresh = this.parseRow(record.html)
    if (!fresh) return
    if (!row) {
      this.topicsTarget.append(fresh)
    } else {
      row.dataset.position = record.position
      row.dataset.lockVersion = record.lock_version
      const header = row.querySelector(":scope > .rubylode-agenda-topic-header")
      // The lines are applied from their own records, so only the header is swapped.
      if (force || !header.contains(document.activeElement)) header.replaceWith(fresh.querySelector(":scope > .rubylode-agenda-topic-header"))
    }
    containers.add(this.topicsTarget)
  }

  applyLine(record, force, containers) {
    let row = this.element.querySelector(`[data-line-id="${record.id}"]`)
    if (record.deleted) return row?.remove()
    const container = this.element.querySelector(`[data-lines-for="${record.topic_id}"]`)
    if (!container) return row?.remove()
    const fresh = this.parseRow(record.html)
    if (!fresh) return
    if (!row) {
      row = fresh
    } else if (force || !row.contains(document.activeElement)) {
      row.replaceWith(fresh)
      row = fresh
    } else {
      row.dataset.position = record.position
      row.dataset.lockVersion = record.lock_version
      row.dataset.topicId = record.topic_id
    }
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

  async send(method, path, body) {
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
      this.applyEnvelope(envelope)
      return envelope
    }
    if (response.status === 409 && envelope) {
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
    this.send("PATCH", row.dataset.updatePath, { [key]: text, lock_version: row.dataset.lockVersion }).then((envelope) => {
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
