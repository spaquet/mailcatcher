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

  formatSender: (sender) ->
    # Handle sender format: either "email@example.com" or "<email@example.com>" or "Name <email@example.com>"
    unless sender
      return ""

    # Remove angle brackets if present
    sender = sender.replace(/^<(.+?)>$/, "$1")

    # Handle "Name <email>" format
    match = sender.match(/^(.+?)\s+<(.+?)>$/)
    if match
      name = match[1].trim()
      email = match[2].trim()
      return "#{name} #{email}"

    # Return clean email (angle brackets already removed above)
    return sender

  parseSender: (sender) ->
    # Parse sender into name and email parts
    # Returns {name: string, email: string}
    unless sender
      return {name: "", email: ""}

    # Remove angle brackets if present
    cleanSender = sender.replace(/^<(.+?)>$/, "$1")

    # Handle "Name <email>" format
    match = cleanSender.match(/^(.+?)\s+<(.+?)>$/)
    if match
      return {name: match[1].trim(), email: match[2].trim()}

    # Just an email address
    return {name: "", email: cleanSender}

  getEmailPreview: (message, callback) ->
    # Extract email preview using tiers 2-3 of the preview text fallback system:
    # Tier 2: Extract preheader text from HTML body (hidden text at start of HTML email)
    # Tier 3: Extract first 100 characters of email content (fallback)
    # This is async so we pass a callback
    # Note: Tier 1 (Preview-Text header) is handled in addMessage() before calling this method
    self = @
    if message.formats && (message.formats.includes("plain") || message.formats.includes("html"))
      # Fetch the plain text or HTML version to extract preview
      format = if message.formats.includes("plain") then "plain" else "html"
      $.ajax
        url: "messages/#{message.id}.#{format}"
        type: "GET"
        success: (data) ->
          # Extract first 100 characters, strip HTML tags
          preview = data.replace(/<[^>]*>/g, "").trim()
          preview = preview.substring(0, 100)
          if preview.length >= 100
            preview += "..."
          callback(preview) if callback
        error: ->
          callback("") if callback
    else
      callback("") if callback

  addMessage: (message) ->
    # Format sender: remove angle brackets and show name + email
    formattedSender = @formatSender(message.sender or "No sender")

    # Check if email has attachments (from detailed message data, or assume false initially)
    hasAttachments = message.attachments && message.attachments.length > 0

    # Create subject cell with bold subject and preview
    $subjectCell = $("<td/>").addClass("subject-cell")
    $subject = $("<div/>").addClass("subject-text").html("<strong>#{@escapeHtml(message.subject or "No subject")}</strong>")
    $preview = $("<div/>").addClass("preview-text").text("")
    $subjectCell.append($subject).append($preview)

    # Create from cell with two-tier format (name bold + email preview)
    $fromCell = $("<td/>").addClass("from-cell")
    senderParts = @parseSender(message.sender or "")

    $fromCellText = $("<div/>").addClass("sender-text-container")
    if senderParts.name
      # Show name in bold and email below
      $senderName = $("<div/>").addClass("sender-name").html("<strong>#{@escapeHtml(senderParts.name)}</strong>")
      $senderEmail = $("<div/>").addClass("sender-email").text(senderParts.email)
      $fromCellText.append($senderName).append($senderEmail)
    else
      # Just email address
      $senderEmail = $("<div/>").addClass("sender-email").text(senderParts.email)
      $fromCellText.append($senderEmail)

    $fromCell.append($fromCellText).toggleClass("blank", !message.sender)

    # Create attachment indicator cell
    $attachmentCell = $("<td/>").addClass("col-attachments")
    if hasAttachments
      $attachmentCell.text("📎")

    # Create BIMI cell with generic icon (will be updated with actual logo if available)
    $bimiCell = $("<td/>").addClass("col-bimi")
    # Add generic BIMI icon SVG
    $bimiIcon = $("<svg/>").addClass("bimi-placeholder-icon")
      .attr("viewBox", "0 0 24 24")
      .attr("fill", "none")
      .attr("stroke", "currentColor")
      .attr("stroke-width", "2")
    $bimiIcon.append($("<circle/>").attr("cx", "12").attr("cy", "12").attr("r", "10"))
    $bimiIcon.append($("<text/>").attr("x", "12").attr("y", "13").attr("text-anchor", "middle").attr("font-size", "10").attr("font-weight", "bold").text("B"))
    $bimiCell.append($bimiIcon)

    # Create recipients cell with two-tier format (name bold + email preview)
    $toCell = $("<td/>").addClass("to-cell")
    if message.recipients && message.recipients.length > 0
      # Show first recipient (same pattern as From column)
      firstRecipient = message.recipients[0]
      recipientParts = @parseSender(firstRecipient)

      $toCellText = $("<div/>").addClass("sender-text-container")
      if recipientParts.name
        # Show name in bold and email below
        $recipientName = $("<div/>").addClass("sender-name").html("<strong>#{@escapeHtml(recipientParts.name)}</strong>")
        $recipientEmail = $("<div/>").addClass("sender-email").text(recipientParts.email)
        $toCellText.append($recipientName).append($recipientEmail)
      else
        # Just email address
        $recipientEmail = $("<div/>").addClass("sender-email").text(recipientParts.email)
        $toCellText.append($recipientEmail)

      $toCell.append($toCellText)
    else
      $toCell.addClass("blank").text("No recipients")

    $tr = $("<tr />").attr("data-message-id", message.id.toString())
      .append($attachmentCell)
      .append($bimiCell)
      .append($fromCell)
      .append($toCell)
      .append($subjectCell)
      .append($("<td/>").text(@formatDate(message.created_at)))
      .append($("<td/>").text(@formatSize(message.size)))

    # Store attachment information for filtering
    $tr.data("has-attachments", hasAttachments)
    $tr.prependTo($("#messages tbody"))

    # Fetch full message data to get attachment and BIMI info
    self = @
    $.getJSON "messages/#{message.id}.json", (fullMessage) ->
      # Update From and To cells with email headers if available
      # Use from_header/to_header from email headers, fall back to sender/recipients from envelope
      if fullMessage.from_header
        $fromCellText.empty()
        fromParts = self.parseSender(fullMessage.from_header)
        if fromParts.name
          $fromName = $("<div/>").addClass("sender-name").html("<strong>#{self.escapeHtml(fromParts.name)}</strong>")
          $fromEmail = $("<div/>").addClass("sender-email").text(fromParts.email)
          $fromCellText.append($fromName).append($fromEmail)
        else
          $fromEmail = $("<div/>").addClass("sender-email").text(fromParts.email)
          $fromCellText.append($fromEmail)

      if fullMessage.to_header
        $toCell.empty()
        recipients = fullMessage.to_header.split(",").map((email) -> email.trim())
        if recipients.length > 0
          firstRecipient = recipients[0]
          recipientParts = self.parseSender(firstRecipient)

          $toCellText = $("<div/>").addClass("sender-text-container")
          if recipientParts.name
            $recipientName = $("<div/>").addClass("sender-name").html("<strong>#{self.escapeHtml(recipientParts.name)}</strong>")
            $recipientEmail = $("<div/>").addClass("sender-email").text(recipientParts.email)
            $toCellText.append($recipientName).append($recipientEmail)
          else
            $recipientEmail = $("<div/>").addClass("sender-email").text(recipientParts.email)
            $toCellText.append($recipientEmail)

          $toCell.append($toCellText)

      # Update attachment cell if attachments are present
      if fullMessage.attachments && fullMessage.attachments.length > 0
        $tr.data("has-attachments", true)
        $attachmentCell.text("📎")

      # Extract and display email preview using 3-tier fallback system:
      # Tier 1: Use Preview-Text header if present (de facto standard email header)
      # Tier 2: Extract from HTML body preheader (hidden text at start of HTML email)
      # Tier 3: Use first lines of email content
      if fullMessage.preview_text
        # Tier 1: Preview-Text header from email metadata
        $preview.text(fullMessage.preview_text)
      else
        # Tiers 2-3: Extract from email body (HTML preheader or first content lines)
        self.getEmailPreview(fullMessage, (previewText) ->
          $preview.text(previewText)
        )

      # Add BIMI image if available in message headers
      if fullMessage.bimi_location
        $bimiCell.empty()
        $bimiImg = $("<img/>").addClass("bimi-image").attr("src", fullMessage.bimi_location).attr("alt", "BIMI")
        $bimiCell.append($bimiImg)

    @updateMessagesCount()
    @applyFilters()

  escapeHtml: (text) ->
    div = document.createElement("div")
    div.textContent = text
    div.innerHTML

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
    $(".attachments-column").removeClass("visible")
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
        # Use email headers if available, otherwise fall back to envelope data
        if message.from_header
          $("#message .metadata dd.from").text(@formatSender(message.from_header))
        else
          $("#message .metadata dd.from").text(@cleanEmailAddress(message.sender))
        if message.to_header
          # Parse To header which may have multiple recipients
          toAddresses = message.to_header.split(",").map((email) => @formatSender(email.trim())).join(", ")
          $("#message .metadata dd.to").text(toAddresses)
        else
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
          $(".attachments-column").addClass("visible")
        else
          $(".attachments-column").removeClass("visible")

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
      when "source"
        message_iframe = $("#message iframe").contents()
        body = message_iframe.find("body")

        # Get the raw source content
        if body.length
          content = body.text()
          if content
            # Escape HTML entities for display
            escapedContent = content
              .replace(/&/g, "&amp;")
              .replace(/</g, "&lt;")
              .replace(/>/g, "&gt;")
              .replace(/"/g, "&quot;")

            # Create syntax-highlighted code block
            highlightedHtml = "<pre><code class=\"language-xml\">#{escapedContent}</code></pre>"

            # Build the page with proper styling
            sourceHtml = """
              <body style="background: #f5f5f5; color: #1a1a1a; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', sans-serif; padding: 0; margin: 0; line-height: 1.6;">
                <div style="padding: 20px 28px;">
                  #{highlightedHtml}
                </div>
              </body>
            """

            message_iframe.find("html").html(sourceHtml)

            # Apply syntax highlighting after content is rendered
            setTimeout =>
              message_iframe.find("code").each (i, block) ->
                hljs.highlightElement(block)
            , 0

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
