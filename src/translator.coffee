{vsprintf} = require("sprintf-js")

module.exports =
class Translator
  constructor: (language) ->
    @language = language

  __: (key) =>
    keys = key.toString().split(".")
    res = @language
    for k in keys
      if k not of res
        return key
      res = res[k]
    if typeof(res) is "string"
      return res
    return key

  _p: (key, args...) =>
    keys = key.toString().split(".")
    res = @language
    for k in keys
      if k not of res
        return key
      res = res[k]
    if typeof(res) is "string"
      return vsprintf(res, args)
    return vsprintf(key, args)
