hljs = require("highlight.js")
{escapeHTML} = require("./utils")
Promise = require("bluebird")

aliases = null

loadLangAliases = () ->
  aliases = {"plain": "plain"}
  for lang in hljs.listLanguages()
    aliases[lang] = lang
    lAliases = require("highlight.js/lib/languages/#{lang}")(hljs)["aliases"]
    if lAliases?
      for alias in lAliases
        aliases[alias] = lang
  return aliases

highlightAuto = (str) ->
  for alias, lang in aliases
    if not hljs.getLanguage(lang)?
      hljs.registerLanguage(
        lang, require("highlight.js/lib/languages/#{lang}")
      )
  data = hljs.highlightAuto(str)
  if data["relevance"] > 0 and data["language"]
    return data
  return {"value": escapeHTML(str), "language": "plain"}

highlight = (str, options = {}) ->
  if not aliases?
    aliases = loadLangAliases()
  if options["hljs"]
    hljs.configure({"classPrefix": "hljs-"})

  options["lang"] = aliases[options["lang"]]
  if not options["lang"]?
    data = highlightAuto(str)
  else if options["lang"] is "plain"
    data = {"value": escapeHTML(str), "language": "plain"}
  else
    data = hljs.highlight(options["lang"], str)

  results = [
    "<figure class=\"highlight hljs #{data["language"].toLowerCase()}\">"
  ]
  if options["gutter"]
    gutters = ["<pre class=\"gutter\">"]
    lines = data["value"].split("\n").length
    for i in [0...lines]
      gutters.push("<span class=\"line\">#{i + 1}</span>\n")
    gutters.push("</pre>")
    results = results.concat(gutters)
  results.push("<pre class=\"code\"><code>")
  results.push(data["value"])
  results.push("</code></pre></figure>")
  return results.join("")

module.exports = highlight
