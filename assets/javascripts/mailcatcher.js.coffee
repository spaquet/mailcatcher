#= require jquery
#= require favcount

# Add a new jQuery selector expression which does a case-insensitive :contains
jQuery.expr.pseudos.icontains = (a, i, m) ->
  (a.textContent ? a.innerText ? "").toUpperCase().indexOf(m[3].toUpperCase()) >= 0

class MailCatcher
  constructor: ->
    $("#messages").on "click", "tr", (e) =>
      e.preventDefault()
      @loadMessage $(e.currentTarget).attr("data-message-id")

    $("input[name=search]").on "keyup", (e) =>
      query = $.trim $(e.currentTarget).val()
      if query
        @searchMessages query
      else
        @clearSearch()
      @applyFilters()

    $("#searchClear").on "click", (e) =>
      e.preventDefault()
      $("input[name=search]").val("").focus()
      @clearSearch()
      @applyFilters()

    $("#attachmentFilter").on "change", (e) =>
      @applyFilters()

    $("#message").on "click", ".views .format.tab a", (e) =>
      e.preventDefault()
      @loadMessageBody @selectedMessage(), $($(e.currentTarget).parent("li")).data("message-format")

    $("#message iframe").on "load", =>
      @decorateMessageBody()

    $("#resizer").on "mousedown", (e) =>
      e.preventDefault()
      events =
        mouseup: (e) =>
          e.preventDefault()
          $(window).off(events)
        mousemove: (e) =>
          e.preventDefault()
          @resizeTo e.clientY
      $(window).on(events)

    @resizeToSaved()

    $("nav.app .clear a").on "click", (e) =>
      e.preventDefault()
      if confirm "You will lose all your received messages.\n\nAre you sure you want to clear all messages?"
        $.ajax
          url: new URL("messages", document.baseURI).toString()
          type: "DELETE"
          success: =>
            @clearMessages()
          error: ->
            alert "Error while clearing all messages."

    $("nav.app .quit a").on "click", (e) =>
      e.preventDefault()
      if confirm "You will lose all your received messages.\n\nAre you sure you want to quit?"
        @quitting = true
        $.ajax
          type: "DELETE"
          success: =>
            @hasQuit()
          error: =>
            @quitting = false
            alert "Error while quitting."

    @favcount = new Favcount($("""link[rel="icon"]""").attr("href"))

    # Keyboard shortcuts using native keyboard events
    document.addEventListener "keydown", (e) =>
      # Don't trigger shortcuts when typing in search box
      return if e.target.type == "search"

      switch e.code
        when "ArrowUp"
          e.preventDefault()
          if @selectedMessage()
            @loadMessage $("#messages tr.selected").prevAll(":visible").first().data("message-id")
          else
            @loadMessage $("#messages tbody tr[data-message-id]").first().data("message-id")

        when "ArrowDown"
          e.preventDefault()
          if @selectedMessage()
            @loadMessage $("#messages tr.selected").nextAll(":visible").data("message-id")
          else
            @loadMessage $("#messages tbody tr[data-message-id]:first").data("message-id")

        when "ArrowLeft"
          e.preventDefault()
          @openTab @previousTab()

        when "ArrowRight"
          e.preventDefault()
          @openTab @nextTab()

        when "Backspace", "Delete"
          e.preventDefault()
          id = @selectedMessage()
          if id?
            $.ajax
              url: new URL("messages/#{id}", document.baseURI).toString()
              type: "DELETE"
              success: =>
                @removeMessage(id)
              error: ->
                alert "Error while removing message."

      # Handle Ctrl+Up / Cmd+Up and Ctrl+Down / Cmd+Down
      if (e.ctrlKey or e.metaKey)
        switch e.code
          when "ArrowUp"
            e.preventDefault()
            @loadMessage $("#messages tbody tr[data-message-id]:visible").first().data("message-id")
          when "ArrowDown"
            e.preventDefault()
            @loadMessage $("#messages tbody tr[data-message-id]:visible").last().data("message-id")

    @refresh()
    @subscribe()

  parseDate: (dateString) ->
    if typeof dateString == "string"
      new Date(dateString)
    else
      dateString

  formatDate: (date) ->
    date = @parseDate(date) if typeof(date) == "string"
    return null unless date

    # Format: "Day, DD MMM YYYY HH:MM:SS"
    days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    dayName = days[date.getDay()]
    day = String(date.getDate()).padStart(2, '0')
    month = months[date.getMonth()]
    year = date.getFullYear()
    hours = String(date.getHours()).padStart(2, '0')
    minutes = String(date.getMinutes()).padStart(2, '0')
    seconds = String(date.getSeconds()).padStart(2, '0')

    "#{dayName}, #{day} #{month} #{year} #{hours}:#{minutes}:#{seconds}"

  formatSize: (bytes) ->
    unless bytes
      return "-"
    bytes = parseInt(bytes)
    if bytes == 0
      return "0 B"
    k = 1024
    sizes = ["B", "KB", "MB", "GB"]
    i = Math.floor(Math.log(bytes) / Math.log(k))
    (bytes / Math.pow(k, i)).toFixed(2).replace(/\.?0+$/, "") + " " + sizes[i]

  messagesCount: ->
    $("#messages tr").length - 1

  updateMessagesCount: ->
    @favcount.set(@messagesCount())
    document.title = 'MailCatcher (' + @messagesCount() + ')'

  tabs: ->
    $("#message ul").children(".tab")

  getTab: (i) =>
    $(@tabs()[i])

  selectedTab: =>
    @tabs().index($("#message li.tab.selected"))

  openTab: (i) =>
    @getTab(i).children("a").click()

  previousTab: (tab)=>
    i = if tab || tab is 0 then tab else @selectedTab() - 1
    i = @tabs().length - 1 if i < 0
    if @getTab(i).is(":visible")
      i
    else
      @previousTab(i - 1)

  nextTab: (tab) =>
    i = if tab then tab else @selectedTab() + 1
    i = 0 if i > @tabs().length - 1
    if @getTab(i).is(":visible")
      i
    else
      @nextTab(i + 1)

  haveMessage: (message) ->
    message = message.id if message.id?
    $("""#messages tbody tr[data-message-id="#{message}"]""").length > 0

  selectedMessage: ->
    $("#messages tr.selected").data "message-id"

  currentSearchQuery: ""
  currentAttachmentFilter: "all"

  searchMessages: (query) ->
    @currentSearchQuery = query
    @applyFilters()

  clearSearch: ->
    @currentSearchQuery = ""
    @applyFilters()

  applyFilters: ->
    $rows = $("#messages tbody tr")
    query = @currentSearchQuery
    attachmentFilter = $("#attachmentFilter").val()
    @currentAttachmentFilter = attachmentFilter

    $rows.each (i, row) =>
      $row = $(row)

      # Apply search filter
      searchMatches = true
      if query
        tokens = query.split /\s+/
        text = $row.text().toUpperCase()
        searchMatches = tokens.every (token) -> text.indexOf(token.toUpperCase()) >= 0

      # Apply attachment filter
      attachmentMatches = true
      messageId = $row.attr("data-message-id")
      if messageId and attachmentFilter != "all"
        hasAttachments = $row.data("has-attachments")

        # If we don't have attachment data yet, fetch it from the server
        if hasAttachments == undefined
          $.getJSON "messages/#{messageId}.json", (message) =>
            $row.data("has-attachments", message.attachments && message.attachments.length > 0)
            # Reapply filters after loading the data
            @applyFilters()
          return

        if attachmentFilter == "with"
          attachmentMatches = hasAttachments
        else if attachmentFilter == "without"
          attachmentMatches = !hasAttachments

      # Show/hide based on both filters
      if searchMatches and attachmentMatches
        $row.show()
      else
        $row.hide()

  addMessage: (message) ->
    $tr = $("<tr />").attr("data-message-id", message.id.toString())
      .append($("<td/>").text(message.sender or "No sender").toggleClass("blank", !message.sender))
      .append($("<td/>").text((message.recipients || []).join(", ") or "No recipients").toggleClass("blank", !message.recipients.length))
      .append($("<td/>").text(message.subject or "No subject").toggleClass("blank", !message.subject))
      .append($("<td/>").text(@formatDate(message.created_at)))
      .append($("<td/>").text(@formatSize(message.size)))
    # Store attachment information for filtering
    $tr.data("has-attachments", message.attachments && message.attachments.length > 0)
    $tr.prependTo($("#messages tbody"))
    @updateMessagesCount()

  removeMessage: (id) ->
    messageRow = $("""#messages tbody tr[data-message-id="#{id}"]""")
    isSelected = messageRow.is(".selected")
    if isSelected
      switchTo = messageRow.next().data("message-id") || messageRow.prev().data("message-id")
    messageRow.remove()
    if isSelected
      if switchTo
        @loadMessage switchTo
      else
        @unselectMessage()
    @updateMessagesCount()

  clearMessages: ->
    $("#messages tbody tr").remove()
    @unselectMessage()
    @updateMessagesCount()

  scrollToRow: (row) ->
    relativePosition = row.offset().top - $("#messages").offset().top
    if relativePosition < 0
      $("#messages").scrollTop($("#messages").scrollTop() + relativePosition - 20)
    else
      overflow = relativePosition + row.height() - $("#messages").height()
      if overflow > 0
        $("#messages").scrollTop($("#messages").scrollTop() + overflow + 20)

  unselectMessage: ->
    $("#messages tbody, #message .metadata dd").empty()
    $(".attachments-list").empty()
    $(".attachments-column").hide()
    $("#message iframe").attr("src", "about:blank")
    null

  cleanEmailAddress: (email) ->
    # Remove angle brackets if present
    if email
      email.replace(/^<(.+)>$/, "$1")
    else
      email

  loadMessage: (id) ->
    id = id.id if id?.id?
    id ||= $("#messages tr.selected").attr "data-message-id"

    if id?
      $("#messages tbody tr:not([data-message-id='#{id}'])").removeClass("selected")
      messageRow = $("#messages tbody tr[data-message-id='#{id}']")
      messageRow.addClass("selected")
      @scrollToRow(messageRow)

      $.getJSON "messages/#{id}.json", (message) =>
        # Update the row's attachment data
        messageRow = $("#messages tbody tr[data-message-id='#{id}']")
        messageRow.data("has-attachments", message.attachments && message.attachments.length > 0)

        $("#message .metadata dd.created_at").text(@formatDate message.created_at)
        $("#message .metadata dd.from").text(@cleanEmailAddress(message.sender))
        $("#message .metadata dd.to").text((message.recipients || []).map((email) => @cleanEmailAddress(email)).join(", "))
        $("#message .metadata dd.subject").text(message.subject)
        $("#message .views .tab.format").each (i, el) ->
          $el = $(el)
          format = $el.attr("data-message-format")
          if $.inArray(format, message.formats) >= 0
            $el.find("a").attr("href", "messages/#{id}.#{format}")
            $el.show()
          else
            $el.hide()

        if $("#message .views .tab.selected:not(:visible)").length
          $("#message .views .tab.selected").removeClass("selected")
          $("#message .views .tab:visible:first").addClass("selected")

        if message.attachments.length
          $ul = $(".attachments-list").empty()
          self = @

          $.each message.attachments, (i, attachment) ->
            $li = $("<li/>")
            $a = $("<a/>").attr("href", "messages/#{id}/parts/#{attachment["cid"]}").addClass(attachment["type"].split("/", 1)[0]).addClass(attachment["type"].replace("/", "-")).text(attachment["filename"])
            $meta = $("<div/>").addClass("attachment-meta")
            $meta.append($("<div/>").addClass("attachment-size").text(self.formatSize(attachment["size"])))
            $meta.append($("<div/>").addClass("attachment-type").text(attachment["type"]))
            $li.append($a).append($meta)
            $ul.append($li)
          $(".attachments-column").show()
        else
          $(".attachments-column").hide()

        $("#message .views .download a").attr("href", "messages/#{id}.eml")

        @loadMessageBody()

  loadMessageBody: (id, format) ->
    id ||= @selectedMessage()
    format ||= $("#message .views .tab.format.selected").attr("data-message-format")
    format ||= "html"

    $("""#message .views .tab[data-message-format="#{format}"]:not(.selected)""").addClass("selected")
    $("""#message .views .tab:not([data-message-format="#{format}"]).selected""").removeClass("selected")

    if id?
      $("#message iframe").attr("src", "messages/#{id}.#{format}")

  decorateMessageBody: ->
    format = $("#message .views .tab.format.selected").attr("data-message-format")

    switch format
      when "html"
        body = $("#message iframe").contents().find("body")
        $("a", body).attr("target", "_blank")
      when "plain"
        message_iframe = $("#message iframe").contents()
        body = message_iframe.find("body")

        # If body already exists and has content, preserve it as-is with proper styling
        if body.length
          body.css("font-family", "sans-serif")
          body.css("white-space", "pre-wrap")
          body.css("word-wrap", "break-word")
        else
          # Fallback: get the text content
          text = message_iframe.text()

          # Escape special characters
          text = text.replace(/&/g, "&amp;")
          text = text.replace(/</g, "&lt;")
          text = text.replace(/>/g, "&gt;")
          text = text.replace(/"/g, "&quot;")

          # Autolink text
          text = text.replace(/((http|ftp|https):\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-\.,@?^=%&amp;:\/~\+#]*[\w\-\@?^=%&amp;\/~\+#])?)/g, """<a href="$1" target="_blank">$1</a>""")

          message_iframe.find("html").html("""<body style="font-family: sans-serif; white-space: pre-wrap; word-wrap: break-word">#{text}</body>""")

  refresh: ->
    $.getJSON "messages", (messages) =>
      $.each messages, (i, message) =>
        unless @haveMessage message
          @addMessage message
      @updateMessagesCount()

  subscribe: ->
    if WebSocket?
      @subscribeWebSocket()
    else
      @subscribePoll()

  reconnectWebSocketAttempts: 0
  maxReconnectAttempts: 10
  reconnectBaseDelay: 1000  # 1 second

  subscribeWebSocket: ->
    secure = window.location.protocol is "https:"
    url = new URL("messages", document.baseURI)
    url.protocol = if secure then "wss" else "ws"
    @websocket = new WebSocket(url.toString())

    @websocket.onopen = =>
      console.log "[MailCatcher] WebSocket connection established"
      @reconnectWebSocketAttempts = 0
      @updateWebSocketStatus(true)

    @websocket.onmessage = (event) =>
      try
        data = JSON.parse(event.data)
        console.log "[MailCatcher] WebSocket message received:", data
        if data.type == "add"
          @addMessage(data.message)
        else if data.type == "remove"
          @removeMessage(data.id)
        else if data.type == "clear"
          @clearMessages()
        else if data.type == "quit" and not @quitting
          @hasQuit()
      catch e
        console.error "[MailCatcher] Error processing WebSocket message:", e

    @websocket.onerror = (event) =>
      console.error "[MailCatcher] WebSocket error:", event
      @updateWebSocketStatus(false)

    @websocket.onclose = =>
      console.log "[MailCatcher] WebSocket connection closed"
      @updateWebSocketStatus(false)
      @attemptWebSocketReconnect()

  subscribePoll: ->
    unless @refreshInterval?
      @refreshInterval = setInterval (=> @refresh()), 1000

  attemptWebSocketReconnect: ->
    if @reconnectWebSocketAttempts < @maxReconnectAttempts
      delay = @reconnectBaseDelay * Math.pow(2, @reconnectWebSocketAttempts)
      @reconnectWebSocketAttempts++
      console.log "[MailCatcher] Attempting WebSocket reconnection in #{delay}ms (attempt #{@reconnectWebSocketAttempts}/#{@maxReconnectAttempts})"
      setTimeout (=> @subscribeWebSocket()), delay
    else
      console.log "[MailCatcher] Max WebSocket reconnection attempts reached, staying in polling mode"
      @subscribePoll()

  resizeToSavedKey: "mailcatcherSeparatorHeight"

  resizeTo: (height) ->
    $("#messages").css
      height: height - $("#messages").offset().top
    window.localStorage?.setItem(@resizeToSavedKey, height)

  resizeToSaved: ->
    height = parseInt(window.localStorage?.getItem(@resizeToSavedKey))
    unless isNaN height
      @resizeTo height

  updateWebSocketStatus: (connected) ->
    badge = document.getElementById("websocketStatus")
    statusText = document.getElementById("statusText")
    if badge and statusText
      if connected
        badge.classList.remove("disconnected")
        statusText.textContent = "Connected"
      else
        badge.classList.add("disconnected")
        statusText.textContent = "Disconnected"

  hasQuit: ->
    # Server has quit, stay on current page
    console.log "[MailCatcher] Server has quit"

$ -> window.MailCatcher = new MailCatcher
