# Description:
#   Example scripts for you to examine and try out.
#
# Notes:
#   They are commented out by default, because most of them are pretty silly and
#   wouldn't be useful and amusing enough for day to day huboting.
#   Uncomment the ones you want to try and experiment with.
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md

format = require '../modules/format'
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

class PIC
  date: null

  constructor: (date) ->
    @date = date

  fetch: () =>
    new Promise (resolve, reject) =>
        db.dates.find {
          date: @date
        }, (err, docs) ->
          if err
            reject err
          resolve docs[0]

  setURL: (url) =>
    new Promise (resolve, reject) =>
      db.dates.update { date: @date }, { $set: { url: url } }, {}, (err, numReplaced) ->
        if err
          reject err
        resolve numReplaced
  
  setPerson: (person) =>
    new Promise (resolve, reject) =>
      db.dates.insert [
        { date: @date, url: '', pic: person }
      ], (err, newDoc) ->
        if err
          reject err
        resolve newDoc

class Message
  robot: null

  constructor: (robot) ->
    @robot = robot

  getUserId: (name) =>
    users = @robot.brain.data.users
    for key of users
      if name == users[key].real_name
        return users[key].id

  sendRemind: (to) =>
    new Promise (resolve) =>
      @robot.messageRoom roomId, "<@#{@getUserId(to)}> 記事書きましたかー？書いたら私に URL つけてメンションしてね！書いてくれるとボット的には嬉しいです！"
      resolve()

  sendPersonDecided: (to) =>
    new Promise (resolve) =>
      @robot.messageRoom roomId, "<@#{@getUserId(to)}> 今月の担当ですよ！書いたら私に URL つけてメンションしてね！"
      resolve()

  sendURLRegistered: (to) =>
    new Promise (resolve) =>
      @robot.messageRoom roomId, "<@#{@getUserId(to)}> URL 確認しました！書いてくれてありがとう！！次もよろしくね！"

  sendURLAlreadyRegistered: (to) =>
    new Promise (resolve) =>
      @robot.messageRoom roomId, "<@#{@getUserId(to)}> あれ？すでに書いてますよね！？次回もよろしくね！"

  sendPersonNotYetDecided: (to) =>
    new Promise (resolve) =>
      @robot.messageRoom roomId, "<@#{@getUserId(to)}> まだ今月の担当は決めてないです！チョット待っててください！"


module.exports = (robot) ->
  message = new Message robot
  members = []

  # 現在日時を取得して今月の pic が設定されているか検索
  # されてなければ設定
  # されている場合は url があるか確認してあれば何もしない
  # ない場合は remind を送る
  routine = () ->
    now = new Date()
    currentDate = format now, 'yyyy-MM'

    pic = new PIC(currentDate)
    pic.fetch()
    .then (doc) ->
      if !doc
        # 今月の pic が設定されていない場合は members からランダムに選択して設定
        person = members[Math.floor(Math.random() * members.length)]
        pic.setPerson(person.id)
        message.sendPersonDecided pic.id
      else
        if !doc.url
          console.log doc
          message.sendRemind(doc.pic)

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

    pic = new PIC(currentDate)
    pic.fetch()
    .then (pic) ->
      if !pic
        message.sendPersonNotYetDecided mentioner
        return Promise.reject()
      if pic.url != ''
        message.sendURLAlreadyRegistered mentioner
        return Promise.reject()
    .then () -> pic.setURL(url)
    .then () -> message.sendURLRegistered mentioner
