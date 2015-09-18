class Turbolinks.HttpRequest
  constructor: (@delegate, location, referrer) ->
    @url = Turbolinks.Location.box(location).requestURL
    @referrer = Turbolinks.Location.box(referrer)
    @createXHR()

  send: ->
    if @xhr and not @sent
      @notifyApplicationBeforeRequestStart()
      @setProgress(0)
      @xhr.send()
      @sent = true
      @delegate.requestStarted?()

  cancel: ->
    if @xhr and @sent
      @xhr.abort()

  # XMLHttpRequest events

  requestProgressed: (event) =>
    if event.lengthComputable
      @setProgress(event.loaded / event.total)

  requestLoaded: =>
    @endRequest =>
      if 200 <= @xhr.status < 300
        @delegate.requestCompletedWithResponse(@xhr.responseText)
      else
        @failed = true
        @delegate.requestFailedWithStatusCode(@xhr.status, @xhr.responseText)

  requestFailed: =>
    @endRequest =>
      @failed = true
      @delegate.requestFailedWithStatusCode(null)

  requestCanceled: =>
    @endRequest()

  # Application events

  notifyApplicationBeforeRequestStart: ->
    Turbolinks.dispatch("turbolinks:request-start", data: { url: @url, xhr: @xhr })

  notifyApplicationAfterRequestEnd: ->
    Turbolinks.dispatch("turbolinks:request-end", data: { url: @url, xhr: @xhr })

  # Private

  createXHR: ->
    @xhr = new XMLHttpRequest
    @xhr.open("GET", @url, true)
    @xhr.setRequestHeader("Accept", "text/html, application/xhtml+xml, application/xml")
    @xhr.setRequestHeader("X-XHR-Referer", @referrer.absoluteURL) if @referrer?
    @xhr.onprogress = @requestProgressed
    @xhr.onloadend = @requestLoaded
    @xhr.onerror = @requestFailed
    @xhr.onabort = @requestCanceled

  endRequest: (callback) ->
    if @xhr
      @notifyApplicationAfterRequestEnd()
      callback?.call(this)
      @destroy()

  setProgress: (progress) ->
    @progress = progress
    @delegate.requestProgressed?(@progress)

  destroy: ->
    @setProgress(1)
    @delegate.requestFinished?()
    @delegate = null
    @xhr = null
