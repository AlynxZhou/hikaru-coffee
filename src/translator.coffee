{vsprintf} = require("sprintf-js")

module.exports =
class Translator
  constructor: (logger) ->
    @logger = logger
    @store = {}

  register: (lang, obj) =>
    if obj not instanceof Object
      return
    if lang instanceof Array
      for l in lang
        @store[l] = obj
      return
    @store[lang] = obj

  list: () =>
    return Object.keys(@store)

  getTranslateFn: (lang) =>
    return (key, args...) =>
      keys = key.toString().split(".")
      res = @store[lang]
      if lang not of @store
        res = @store["default"]
      for k in keys
        if k not of res
          return key
        res = res[k]
      if typeof(res) is "string"
        if args.length > 0
          return vsprintf(res, args)
        else
          return res
      if args.length > 0
        return vsprintf(key, args)
      else
        return key
