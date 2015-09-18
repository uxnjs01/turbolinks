#= require ./location
#= require ./browser_adapter
#= require ./history
#= require ./view
#= require ./cache
#= require ./visit

class Turbolinks.Controller
  constructor: ->
    @history = new Turbolinks.History this
    @view = new Turbolinks.View this
    @location = Turbolinks.Location.box(window.location)
    @clearCache()

  start: ->
    unless @started
      addEventListener("click", @clickCaptured, true)
      addEventListener("DOMContentLoaded", @pageLoaded, false)
      @history.start()
      @started = true

  stop: ->
    if @started
      removeEventListener("click", @clickCaptured, true)
      removeEventListener("DOMContentLoaded", @pageLoaded, false)
      @history.stop()
      @started = false

  clearCache: ->
    @cache = new Turbolinks.Cache 10

  visit: (location, options = {}) ->
    location = Turbolinks.Location.box(location)
    if @applicationAllowsVisitingLocation(location)
      action = options.action ? "advance"
      @adapter.visitProposedToLocationWithAction(location, action)

  pushHistory: (location) ->
    @location = Turbolinks.Location.box(location)
    @history.push(@location)

  replaceHistory: (location) ->
    @location = Turbolinks.Location.box(location)
    @history.replace(@location)

  loadResponse: (response) ->
    @view.loadSnapshotHTML(response)
    @notifyApplicationAfterResponseLoad()

  loadErrorResponse: (response) ->
    @view.loadDocumentHTML(response)
    @controller.stop()

  startVisitToLocationWithAction: (location, action) ->
    @startVisit(location, action)

  # Page snapshots

  hasSnapshotForLocation: (location) ->
    @cache.has(location)

  saveSnapshot: ->
    @notifyApplicationBeforeSnapshotSave()
    snapshot = @view.saveSnapshot()
    @cache.put(@lastRenderedLocation, snapshot)

  restoreSnapshotForLocationWithAction: (location, action) ->
    if snapshot = @cache.get(location)
      @view.loadSnapshotWithAction(snapshot, action)
      @notifyApplicationAfterSnapshotLoad()
      true

  # View delegate

  viewInvalidated: ->
    @adapter.pageInvalidated()

  viewRendered: ->
    @lastRenderedLocation = @currentVisit.location

  # History delegate

  historyPoppedToLocation: (location) ->
    @startVisit(location, "restore", true)
    @location = location

  # Event handlers

  pageLoaded: =>
    @lastRenderedLocation = @location
    @notifyApplicationAfterPageLoad()

  clickCaptured: =>
    removeEventListener("click", @clickBubbled, false)
    addEventListener("click", @clickBubbled, false)

  clickBubbled: (event) =>
    if @clickEventIsSignificant(event)
      if link = @getVisitableLinkForNode(event.target)
        if location = @getVisitableLocationForLink(link)
          if @applicationAllowsFollowingLinkToLocation(link, location)
            event.preventDefault()
            action = @getActionForLink(link)
            @visit(location, {action})

  # Application events

  applicationAllowsFollowingLinkToLocation: (link, location) ->
    @dispatchEvent("turbolinks:click", target: link, data: { url: location.absoluteURL }, cancelable: true)

  applicationAllowsVisitingLocation: (location) ->
    @dispatchEvent("turbolinks:visit", data: { url: location.absoluteURL }, cancelable: true)

  notifyApplicationBeforeSnapshotSave: ->
    @dispatchEvent("turbolinks:snapshot-save")

  notifyApplicationAfterSnapshotLoad: ->
    @dispatchEvent("turbolinks:snapshot-load")

  notifyApplicationAfterResponseLoad: ->
    @dispatchEvent("turbolinks:response-load")

  notifyApplicationAfterPageLoad: ->
    @dispatchEvent("turbolinks:load")

  # Private

  startVisit: (location, action, historyChanged) ->
    @currentVisit?.cancel()
    @currentVisit = @createVisit(location, action, historyChanged)
    @currentVisit.start()

  createVisit: (location, action, historyChanged) ->
    visit = new Turbolinks.Visit this, location, action, historyChanged
    visit.referrer = @location
    visit.then(@visitFinished)
    visit

  visitFinished: =>
    @notifyApplicationAfterPageLoad()

  dispatchEvent: ->
    event = Turbolinks.dispatch(arguments...)
    not event.defaultPrevented

  clickEventIsSignificant: (event) ->
    not (
      event.defaultPrevented or
      event.which > 1 or
      event.altKey or
      event.ctrlKey or
      event.metaKey or
      event.shiftKey
    )

  getVisitableLinkForNode: (node) ->
    if @nodeIsVisitable(node)
      Turbolinks.closest(node, "a[href]:not([target])")

  getVisitableLocationForLink: (link) ->
    location = new Turbolinks.Location link.href
    location if location.isSameOrigin()

  getActionForLink: (link) ->
    link.getAttribute("data-turbolinks-action") ? "advance"

  nodeIsVisitable: (node) ->
    if container = Turbolinks.closest(node, "[data-turbolinks]")
      container.getAttribute("data-turbolinks") isnt "false"
    else
      true

do ->
  Turbolinks.controller = controller = new Turbolinks.Controller
  controller.adapter = new Turbolinks.BrowserAdapter(controller)
  controller.start()
