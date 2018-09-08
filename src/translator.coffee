{vsprintf} = require("sprintf-js")

module.exports =
class Translator
  constructor: (logger) ->
    @logger = logger
    @_ = {}

  register: (lang, obj) =>
    if obj not instanceof Object
      throw new TypeError(
        "obj must be a Object generated from yaml language file!"
      )
      return
    if lang instanceof Array
      for l in lang
        @_[l] = obj
      return
    @_[lang] = obj

  list: () =>
    return Object.keys(@_)

  getTranslateFn: (lang) =>
    return (key, args...) =>
      keys = key.toString().split(".")
      res = @_[lang]
      if lang not of @_
        @logger.info("Hikaru cannot find language `#{lang}`, using default.")
        res = @_["default"]
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
