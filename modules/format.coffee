module.exports = (date, str) ->
  str = str.replace(/yyyy/g, date.getFullYear())
  str = str.replace(/MM/g, ('0' + (date.getMonth() + 1)).slice(-2))
  str = str.replace(/DD/g, ('0' + date.getDate()).slice(-2))
  str = str.replace(/hh/g, ('0' + date.getHours()).slice(-2))
  str = str.replace(/mm/g, ('0' + date.getMinutes()).slice(-2))
  str = str.replace(/ss/g, ('0' + date.getSeconds()).slice(-2))
  str