hljs = require("highlight.js")

aliases = null

escapeHTML = (str) ->
  return str
  .replace(/&/g, "&amp;")
  .replace(/</g, "&lt;")
  .replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;")
  .replace(/"/g, "&#039;")

loadLangAliases = () ->
  aliases = {}
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
  if data["relevance"] > 0 and data["language"]?
    return data
  return {"value": escapeHTML(str)}

highlight = (str, options = {}) ->
  if not aliases?
    aliases = loadLangAliases()
  if options["hljs"]
    hljs.configure({"classPrefix": "hljs-"})

  # Guess when no lang was given,
  if not options["lang"]?
    data = highlightAuto(str)
  # Skip auto guess when user sets lang to plain,
  # plain is not in the alias list, so judge it first.
  else if options["lang"] is "plain"
    data = {"value": escapeHTML(str)}
  # Guess when lang is given but not in highlightjs' alias list, too.
  else if not aliases[options["lang"]]?
    data = highlightAuto(str)
  # We have correct lang alias, tell highlightjs to handle it.
  # If given language does not match string content,
  # highlightjs will set language to undefined.
  else
    data = hljs.highlight(aliases[options["lang"]], str)

  # Language in <figure>'s class is highlight's detected result, not user input.
  # To get user input, marked set it to parent <code>'s class.
  results = ["<figure class=\"highlight hljs"]
  if data["language"]?
    results.push(" #{data["language"].toLowerCase()}\">")
  else
    results.push("\">")

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
