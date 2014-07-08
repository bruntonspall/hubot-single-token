# Description:
#   Single Token allows you to have a number of "single tokens" that only one
#   user can possess at a time.  So you can have a :badger: and a :crown:, and
#   either of them can be possessed by one person at any time.
#   Each has it's own queue of people waiting for it.
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_TOKEN_NAMES - a comma seperated list of tokens: crown,badger
#   HUBOT_TOKEN_EMOJI - a comma seperated list of token emoji: :crown:,:badger:
#
# Commands:
#   hubot <token> me - Requests the <token>
#   who has the <token> - Replies who has the <token>
#   hubot give up the <token> - releases the <token> to the next person
#   hubot <token> queue - See who is waiting for the <token>
#   hubot really <token> me - Forcibly bypasses the queue and takes the <token>
#   hubot which tokens - See what tokens are available and who has them
#   hubot clear the <token> queue - Clear down the queue and current owner of the <token>
#   hubot create queue <token> <emoji> - Create a queue for the <token> using <emoji>
#   hubot delete queue <token> - Delete a queue for the <token>
#
# Notes:
#   * Relies on the brain user details
#   * Assumes a democratic team that can all see the commands, so no admins necessary
#
# Author:
#   bruntonspall

util = require 'util'

module.exports = (robot) ->
  robot.brain.data.tokens ?= {}

  enqueueUserById = (token, user) ->
    u = robot.brain.userForId user.id, user
    token.queue.push u.id

  processQueue = (token, msg) ->
    if token.queue.length > 0 and token.user == null
      uid = token.queue.shift()
      token.user = uid
      newuser = robot.brain.userForId uid
      msg.emote "passes the #{token.emoji} to #{newuser.name}"

  crownedUsername = (token) ->
    if token.user
      robot.brain.userForId(token.user).name
    else "Nobody"

  displayToken = (token, msg) ->
    response = ""
    if token.user != null
      response += "#{robot.brain.userForId(token.user).name} has the #{token.emoji}"
    else
      response += "Nobody has the #{token.emoji}"
    names = (robot.brain.userForId(id).name for id in token.queue)

    if names.length > 1
      response += " and #{names.join(", ")} are all waiting for the #{token.emoji}"
    else if names.length == 1
      response += " and #{names.join(", ")} is waiting for the #{token.emoji}"
    else
      response += " and nobody is waiting for the #{token.emoji}"
    msg.reply response

  giveToken = (token, msg) ->
    enqueueUserById token, msg.message.user
    if token.queue.length > 0 and token.user != null
      msg.reply "You are number #{token.queue.length} in the queue for the #{token.name}"
    processQueue(token, msg)


  withToken = (token, msg, callback) ->
    if not robot.brain.data.tokens[token]?
      msg.send "I've never heard of #{token.name}, sorry"
      null
    else
      callback robot.brain.data.tokens[token], msg
      processQueue robot.brain.data.tokens[token], msg

  robot.respond /^(\w+) queue\??$/i, (msg) ->
    withToken msg.match[1], msg, displayToken

  robot.respond /create queue (\w+) (:\w+:)/i, (msg) ->
    token = msg.match[1]
    robot.brain.data.tokens[token] =
      name: token
      user: null
      emoji: msg.match[2]
      queue: []
    msg.reply "Created queue for #{robot.brain.data.tokens[token].emoji}"

  robot.respond /delete queue (\w+)/i, (msg) ->
    token = msg.match[1]
    delete robot.brain.data.tokens[token]
    msg.reply "Ok guv, deleted queue for #{token}"

  robot.respond /debug tokens/i, (msg) ->
    output = util.inspect(robot.brain.data.tokens, false, 4)
    msg.send output

  robot.respond /(\w+) me/i, (msg) ->
    withToken msg.match[1], msg, giveToken

  robot.hear /who (has )?(the )?(\w+)\?*/i, (msg) ->
    withToken msg.match[3], msg, (token, msg) ->
      msg.reply "#{crownedUsername(token)} has the #{token.emoji}"

  robot.respond /(I )?give up (the )?(\w+)/i, (msg) ->
    withToken msg.match[3], msg, (token, msg) ->
      if token.user != msg.message.user.id
        msg.reply "You don't have the #{token.emoji} to give up, #{crownedUsername(token)} does!"
      else
        token.user = null
        msg.reply "The #{token.emoji} is now free"

  robot.respond /clear the (\w+) queue/i, (msg) ->
    withToken msg.match[1], msg, (token, msg) ->
      token.user = null
      token.queue = []
      msg.reply "I've cleared down the #{token.emoji} queue, nobody has the #{token.user} now"

  robot.respond /really (\w+) me/i, (msg) ->
    withToken msg.match[1], msg, (token, msg) ->
      u = robot.brain.userForId msg.message.user.id, msg.message.user
      olduser = robot.brain.userForId token.user
      token.user = u.id
      msg.send "#{token.emoji} was forcibly passed to #{u.name} from #{olduser.name}"

  robot.respond /which tokens/i, (msg) ->
    for token of robot.brain.data.tokens
      withToken token, msg, displayToken
