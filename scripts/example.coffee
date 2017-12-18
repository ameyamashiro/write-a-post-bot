# Description:
#   Example scripts for you to examine and try out.
#
# Notes:
#   They are commented out by default, because most of them are pretty silly and
#   wouldn't be useful and amusing enough for day to day huboting.
#   Uncomment the ones you want to try and experiment with.
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md

Datastore = require "nedb"
db = {}
db.members = new Datastore(
  filename: "./members.db"
  autoload: true
)
db.dates = new Datastore(
  filename: "./dates.db",
  autoload: true
)
roomId = '#api-test'

members = []

format = (date, str) ->
  str = str.replace(/yyyy/g, date.getFullYear())
  str = str.replace(/MM/g, ('0' + (date.getMonth() + 1)).slice(-2))
  str = str.replace(/DD/g, ('0' + date.getDate()).slice(-2))
  str = str.replace(/hh/g, ('0' + date.getHours()).slice(-2))
  str = str.replace(/mm/g, ('0' + date.getMinutes()).slice(-2))
  str = str.replace(/ss/g, ('0' + date.getSeconds()).slice(-2))
  str

setPIC = (date, pic) ->
  new Promise (resolve, reject) ->
    db.dates.insert [
      { date: date, url: '', pic: pic }
    ], (err, newDoc) ->
      if err
        reject err
      resolve newDoc

setDateURL = (date, url) ->
  new Promise (resolve, reject) ->
    db.dates.update { date: date }, { $set: { url: url } }, {}, (err, numReplaced) ->
      if err
        reject err
      resolve numReplaced

fetchPIC = (date) ->
  new Promise (resolve, reject) ->
    db.dates.find {
      date: date
    }, (err, docs) ->
      if err
        reject err
      resolve docs[0]


module.exports = (robot) ->
  users = robot.brain.data.users

  sendRemindMessage = (to) ->
    new Promise (resolve) ->
      robot.messageRoom roomId, "<@#{getUserId(to)}> まだ記事投稿してない"
      resolve()

  sendPICMessage = (to) ->
    new Promise (resolve) ->
      robot.messageRoom roomId, "<@#{getUserId(to)}> Your！"
      resolve()

  sendWroteMessage = (to) ->
    new Promise (resolve) ->
      robot.messageRoom roomId, "<@#{getUserId(to)}> Registered"

  sendAlreadyWroteMessage = (to) ->
    new Promise (resolve) ->
      robot.messageRoom roomId, "<@#{getUserId(to)}> Already"
    
  sendPICNotYetDecidedMessage = (to) ->
    new Promise (resolve) ->
      robot.messageRoom roomId, "<@#{getUserId(to)}> Not yet decided"

  getUserId = (name) ->
    for key of users
      if name == users[key].real_name
        return users[key].id

  # 現在日時を取得して今月の pic が設定されているか検索
  # されてなければ設定
  # されている場合は url があるか確認してあれば何もしない
  # ない場合は remind を送る
  routine = () ->
    now = new Date()
    currentDate = format now, 'yyyy-MM'

    fetchPIC(currentDate)
    .then (doc) ->
      if !doc
        # 今月の pic が設定されていない場合は members からランダムに選択して設定
        pic = members[Math.floor(Math.random() * members.length)]
        setPIC(currentDate, pic.id)
        sendPICMessage pic.id
      else
        if !doc.url
          console.log doc
          sendRemindMessage doc.pic

    # 毎週金曜日 11:00 に routine を再起呼び出し (epoch で計算して setTimeout)
    d = new Date(Date.now() + ((5 - new Date().getDay()) * 1000 * 60 * 60 * 24))
    nextDate = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 11, 0)
    nextTime = nextDate.getTime() - Date.now()
    setTimeout routine, nextTime

  db.members.find {}, (err, docs) ->
    members = docs
    setTimeout(routine, 1000)

  #
  # URL 付きメンションを listen して url をアップデート
  #
  # 現在の月の PIC を取得
  # url が設定されてないか確認
  # PIC とメンションしてきた人が同じかどうか確認
  # 一致すれば update
  robot.respond /(h?ttps?:\/\/[-a-zA-Z0-9@:%_\+.~#?&\/=]+)/i, (res) ->
    mentioner = res.message.user.real_name
    url = res.match[1]
    now = new Date()
    currentDate = format now, 'yyyy-MM'

    fetchPIC(currentDate)
    .then (pic) ->
      if !pic
        sendPICNotYetDecidedMessage(mentioner)
        return Promise.reject()
      if pic.url != ''
        sendAlreadyWroteMessage(mentioner)
        return Promise.reject()
    .then () -> setDateURL(currentDate, url)
    .then () -> sendWroteMessage(mentioner)

  # robot.hear /badger/i, (res) ->
  #   robot.logger.debug "Received message #{res.message.text}"
  #   res.send "Yes ?"
  #
  # robot.hear /badger/i, (res) ->
  #   res.send "Badgers? BADGERS? WE DON'T NEED NO STINKIN BADGERS"
  #
  # robot.respond /open the (.*) doors/i, (res) ->
  #   doorType = res.match[1]
  #   if doorType is "pod bay"
  #     res.reply "I'm afraid I can't let you do that."
  #   else
  #     res.reply "Opening #{doorType} doors"
  #
  # robot.hear /I like pie/i, (res) ->
  #   res.emote "makes a freshly baked pie"
  #
  # lulz = ['lol', 'rofl', 'lmao']
  #
  # robot.respond /lulz/i, (res) ->
  #   res.send res.random lulz
  #
  # robot.topic (res) ->
  #   res.send "#{res.message.text}? That's a Paddlin'"
  #
  #
  # enterReplies = ['Hi', 'Target Acquired', 'Firing', 'Hello friend.', 'Gotcha', 'I see you']
  # leaveReplies = ['Are you still there?', 'Target lost', 'Searching']
  #
  # robot.enter (res) ->
  #   res.send res.random enterReplies
  # robot.leave (res) ->
  #   res.send res.random leaveReplies
  #
  # answer = process.env.HUBOT_ANSWER_TO_THE_ULTIMATE_QUESTION_OF_LIFE_THE_UNIVERSE_AND_EVERYTHING
  #
  # robot.respond /what is the answer to the ultimate question of life/, (res) ->
  #   unless answer?
  #     res.send "Missing HUBOT_ANSWER_TO_THE_ULTIMATE_QUESTION_OF_LIFE_THE_UNIVERSE_AND_EVERYTHING in environment: please set and try again"
  #     return
  #   res.send "#{answer}, but what is the question?"
  #
  # robot.respond /you are a little slow/, (res) ->
  #   setTimeout () ->
  #     res.send "Who you calling 'slow'?"
  #   , 60 * 1000
  #
  # annoyIntervalId = null
  #
  # robot.respond /annoy me/, (res) ->
  #   if annoyIntervalId
  #     res.send "AAAAAAAAAAAEEEEEEEEEEEEEEEEEEEEEEEEIIIIIIIIHHHHHHHHHH"
  #     return
  #
  #   res.send "Hey, want to hear the most annoying sound in the world?"
  #   annoyIntervalId = setInterval () ->
  #     res.send "AAAAAAAAAAAEEEEEEEEEEEEEEEEEEEEEEEEIIIIIIIIHHHHHHHHHH"
  #   , 1000
  #
  # robot.respond /unannoy me/, (res) ->
  #   if annoyIntervalId
  #     res.send "GUYS, GUYS, GUYS!"
  #     clearInterval(annoyIntervalId)
  #     annoyIntervalId = null
  #   else
  #     res.send "Not annoying you right now, am I?"
  #
  #
  # robot.router.post '/hubot/chatsecrets/:room', (req, res) ->
  #   room   = req.params.room
  #   data   = JSON.parse req.body.payload
  #   secret = data.secret
  #
  #   robot.messageRoom room, "I have a secret: #{secret}"
  #
  #   res.send 'OK'
  #
  # robot.error (err, res) ->
  #   robot.logger.error "DOES NOT COMPUTE"
  #
  #   if res?
  #     res.reply "DOES NOT COMPUTE"
  #
  # robot.respond /have a soda/i, (res) ->
  #   # Get number of sodas had (coerced to a number).
  #   sodasHad = robot.brain.get('totalSodas') * 1 or 0
  #
  #   if sodasHad > 4
  #     res.reply "I'm too fizzy.."
  #
  #   else
  #     res.reply 'Sure!'
  #
  #     robot.brain.set 'totalSodas', sodasHad+1
  #
  # robot.respond /sleep it off/i, (res) ->
  #   robot.brain.set 'totalSodas', 0
  #   res.reply 'zzzzz'
