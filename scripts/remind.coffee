# Description:
#   Forgetful? Add reminders
#   Modified by DakotaNelson to work in Slack and notify whole rooms
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot remind <room> in <time> that <thing> - Set a reminder in <time> that <thing> 
#     <time> is in the format 1 day, 2 hours, 5 minutes etc. Time segments are optional, as are commas
#
# Author:
#   whitman
#   modified by DakotaNelson

class Reminders
  constructor: (@robot) ->
    @cache = []
    @current_timeout = null

    @robot.brain.on 'loaded', =>
      if @robot.brain.data.reminders
        @cache = @robot.brain.data.reminders
        @queue()

  add: (reminder) ->
    @cache.push reminder
    @cache.sort (a, b) -> a.due - b.due
    @robot.brain.data.reminders = @cache
    @queue()

  removeFirst: ->
    reminder = @cache.shift()
    @robot.brain.data.reminders = @cache
    return reminder

  queue: ->
    clearTimeout @current_timeout if @current_timeout
    if @cache.length > 0
      now = new Date().getTime()
      @removeFirst() until @cache.length is 0 or @cache[0].due > now
      if @cache.length > 0
        trigger = =>
          reminder = @removeFirst()
          @robot.messageRoom '#' + reminder.room, 'Hi, everyone! ' + reminder.msg_envelope.user.name + ' asked me to remind you that ' + reminder.action + '.'
          @queue()
        # setTimeout uses a 32-bit INT
        extendTimeout = (timeout, callback) ->
          if timeout > 0x7FFFFFFF
            @current_timeout = setTimeout ->
              extendTimeout (timeout - 0x7FFFFFFF), callback
            , 0x7FFFFFFF
          else
            @current_timeout = setTimeout callback, timeout
        extendTimeout @cache[0].due - now, trigger

class Reminder
  constructor: (@msg_envelope, @room, @time, @action) ->
    @time.replace(/^\s+|\s+$/g, '')
    @room = @room.replace(/^\#/g, '') # trim leading hash marks from channel

    periods =
      weeks:
        value: 0
        regex: "weeks?"
      days:
        value: 0
        regex: "days?"
      hours:
        value: 0
        regex: "hours?|hrs?"
      minutes:
        value: 0
        regex: "minutes?|mins?"
      seconds:
        value: 0
        regex: "seconds?|secs?"

    for period of periods
      pattern = new RegExp('^.*?([\\d\\.]+)\\s*(?:(?:' + periods[period].regex + ')).*$', 'i')
      matches = pattern.exec(@time)
      periods[period].value = parseInt(matches[1]) if matches

    @due = new Date().getTime()
    @due += ((periods.weeks.value * 604800) + (periods.days.value * 86400) + (periods.hours.value * 3600) + (periods.minutes.value * 60) + periods.seconds.value) * 1000

  dueDate: ->
    dueDate = new Date @due
    options = {
      'timeZone':'America/New_York',
      'hour12':'false'
    }
    dueDate.toLocaleString("en-US", options)

module.exports = (robot) ->

  reminders = new Reminders robot

  robot.respond /remind (.*?) in ((?:(?:\d+) (?:weeks?|days?|hours?|hrs?|minutes?|mins?|seconds?|secs?)[ ,]*(?:and)? +)+)that (.*)/i, (msg) ->
    room = msg.match[1]
    time = msg.match[2]
    action = msg.match[3]
    reminder = new Reminder msg.envelope, room, time, action
    reminders.add reminder
    @robot.send msg.envelope, 'Got it! I\'ll remind ' + room + ' that ' + action + ' on ' + reminder.dueDate()
