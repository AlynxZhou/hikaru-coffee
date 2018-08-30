"use strict"
hljs = require("highlight.js/lib/highlight")

detectLang = (str) ->
  # Load all languages.
  for lang in [
    "c", "cpp", "c++", "cxx", "java", "kotlin",
    "scala", "javascript", "coffeescript", "typescript",
    "json", "yaml", "yml", "python", "go", "lisp",
    "elisp", "clisp", "scheme", "haskell", "xml",
    "html", "markdown", "nunjucks", "css", "stylus",
    "csharp", "c#"
  ]
    if not hljs.getLanguage(lang)?
      hljs.registerLanguage(lang,
      require("highlight.js/lib/languages/#{lang}"))
  data = hljs.highlightAuto(str)
  if data["relevance"] > 0 and data["language"]
    return data["language"]
  return "plain"

highlightLines = (str, lang) ->
  matching = str.match(/(\r?\n)/)
  if matching?
    lines = str.split(matching[1])
    values = []
    result = hljs.highlight(lang, lines.shift())
    values.push(result["value"])
    while (lines.length > 0)
      result = hljs.highlight(lang, lines.shift(), false, result.top)
      values.push(matching[1])
      values.push(result["value"])
    result["value"] = values.join("")
    return result
  return hljs.highlight(lang, str)

module.exports =
highlight = (str, options) ->
  if not str instanceof String
    throw new TypeError("str is not a String.")
  options = options or {}
  hljs.configure({"classPrefix": ""})
  if options["hljs"]
    hljs.configure({"classPrefix": "hljs-"})

  if not options["lang"]
    options["lang"] = detectLang(str)

  data = highlightLines(options["lang"], str)

  lines = data["value"].split("\n")
  gutters = []
  codes = []
  results = []

  for i in [0...lines.length]
    gutters.push("<span class=\"line\">#{i + 1}</span><br>")
    codes.push("<span class=\"line\>#{lines[i]}</span><br>")

  results.push("<figure class=\"highlight hljs")
  if data.language?
    results.push(" #{data["language"].toLowerCase()}")
  results.push("\"><table><tr>")

  if options["gutter"]
    results.push("<td class=\"gutter\"><pre>")
    results = results.concat(gutters)
    results.push("</pre></td>")

  results.push("<td class=\"code\"><pre>")
  if options["hljs"]
    results.push("<code class=\"hljs #{options["lang"]}\">")
  results = results.concat(codes)
  if options["hljs"]
    results.push("</code>")
  results.push("</pre></td>")

  results.push("</tr></table></figure>")

  return results.join("")
