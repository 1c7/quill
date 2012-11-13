#= require diff_match_patch
#= require coffee/ot/jetsync

DIFF_DELETE = -1
DIFF_INSERT = 1
DIFF_EQUAL = 0

# Note: JetStates have precedence in the following order: Text > Cursor > Chat > Comment
# That means on an update message, text's update is always called before cursor's

class JetState
  @dmp: new diff_match_patch
  @CURSOR = "cursor"
  @TEXT = "text"
  @CHAT = "chat"
  @COMMENT = "comment"

  constructor: (delegate, client, initialState, sessionId) ->

  reset: (state) ->
    console.assert(false, "Should be implemented by decendents")

  localUpdate: (change) ->
    console.assert(false, "Should be implemented by decendents")

  remoteUpdate: (change, authorId) ->
    console.assert(false, "Should be implemented by decendents")

  takeoff: ->
    console.assert(false, "Should be implemented by decendents")

  land: ->
    console.assert(false, "Should be implemented by decendents")

  @applyDelta: (newDelta, insertFn, deleteFn, context = null) ->
    index = 0       # Stores where the last retain end was, so if we see another one, we know to delete
    offset = 0      # Tracks how many characters inserted to correctly offset new text
    for delta in newDelta.deltas
      authorId = if delta.attributes? then delta.attributes.authorId else 1
      if JetDelta.isInsert(delta)
        insertFn.call(context || insertFn, index + offset, delta.text, authorId)
        offset += delta.getLength()
      else if JetDelta.isRetain(delta)
        console.assert(delta.start >= index, "Somehow delta.start became smaller than index")
        if delta.start > index
          deleteFn.call(context || deleteFn, index + offset, delta.start + offset, authorId)
          offset -= (delta.start - index)
        index = delta.end
      else
        console.assert(false, "Unrecognized type in delta", delta)

    # If end of text was deleted
    if newDelta.endLength < newDelta.startLength + offset
      deleteFn.call(context || deleteFn, newDelta.endLength, newDelta.startLength + offset)
    return



class JetTextState extends JetState
  constructor: (@editor, @client, delta, @sessionId) ->
    @type = JetState.TEXT
    @userId = @client.settings.userId
    this.reset(delta)

  reset: (delta) ->
    delta = JetDelta.getInitial(delta) if _.isString(delta)
    @editor.applyDelta(delta)
    @arrived = delta
    @inFlight = JetDelta.getIdentity(@arrived.endLength)
    @inLine = JetDelta.getIdentity(@arrived.endLength)

  localUpdate: (delta) ->
    @inLine = JetSync.compose(@inLine, delta)

  remoteUpdate: (delta, authorId) ->
    delta = JetDelta.makeDelta(delta)
    flightDeltaFollows = JetSync.follows(@inFlight, delta, false)
    textFollows = JetSync.follows(@inLine, flightDeltaFollows, false)

    @arrived = JetSync.compose(@arrived, delta)
    @inFlight = JetSync.follows(delta, @inFlight, true)
    @inLine = JetSync.follows(flightDeltaFollows, @inLine, true)

    @editor.applyDelta(textFollows)

  takeoff: ->
    console.assert(@inFlight?, "inFlight is", @inFlight, "at takeoff")
    console.assert(@inLine?, "inLine is", @inLine, "at takeoff")
    if (@inFlight.isIdentity() && !@inLine.isIdentity())
      @inFlight = @inLine
      @inLine = JetDelta.getIdentity(@inFlight.endLength)
      return { change: @inFlight }
    return false

  land: ->
    @arrived = JetSync.compose(@arrived, @inFlight)
    @inFlight = JetDelta.getIdentity(@arrived.endLength)



class JetChatState extends JetState
  @COMPOSITION: "composition"
  @MAX_CHAT_HISTORY: 50

  constructor: (@chat, @client, @history, @sessionId) ->
    @type = JetState.CHAT
    $(@client).bind(JetChatState.COMPOSITION, (event, message) => this.remoteComposition.call(this, event, message))
    $(@client).bind(JetClient.LEAVE, (event, message) => this.chat.updateComposing("", message.userId))
    this.reset(@history)

  reset: (@history) ->
    @names = []
    @chat.clearMessages()
    for record in @history
      @chat.addMessage(record.text, record.authorId)

  localUpdate: (text) ->
    packet = @client.prepareChangePacket([{type: JetState.CHAT, change: text}])
    @client.send(packet)
    @history.push({text: text, authorId: @userId})
    @history.splice(0, 1) if @history.length > JetChatState.MAX_CHAT_HISTORY

  remoteUpdate: (text, authorId) ->
    @chat.addMessage(text, authorId)
    @history.push({text: text, authorId: authorId})
    @history.splice(0, 1) if @history.length > JetChatState.MAX_CHAT_HISTORY

  localComposition: (isComposing) ->
    @client.send({
      type: JetChatState.COMPOSITION
      composing: isComposing
    })

  remoteComposition: (event, message) ->
    @chat.updateComposing(message.composing, message.authorId)

  land: -> # Nothing to do

  takeoff: ->
    return false



# So other files can actually use this library
window.JetState = JetState if window?
window.JetTextState = JetTextState if window?
window.JetChatState = JetChatState if window?
