fm = require("front-matter")
path = require("path")
glob = require("glob")
{URL} = require("url")
Promise = require("bluebird")
{Site, File, Category, Tag} = require("./types")
highlight = require("./highlight")
packageJSON = require("../package.json")

escapeHTML = (str) ->
  return str
  .replace(/&/g, "&amp;")
  .replace(/</g, "&lt;")
  .replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;")
  .replace(/"/g, "&#039;")

matchFiles = (pattern, options) ->
  return new Promise((resolve, reject) ->
    glob(pattern, options, (err, res) ->
      if err?
        return reject(err)
      return resolve(res)
    )
  )

removeControlChars = (str) ->
  return str.replace(/[\x00-\x1F\x7F]/g, "")

parseFrontMatter = (file) ->
  if typeof(file["raw"]) isnt "string"
    return file
  parsed = fm(file["raw"])
  file["text"] = parsed["body"]
  file["frontMatter"] = parsed["attributes"]
  file = Object.assign(file, parsed["attributes"])
  if file["date"]?
    # Fix js-yaml"s bug that ignore timezone while parsing.
    # https://github.com/nodeca/js-yaml/issues/91
    file["date"] = new Date(
      file["date"].getTime() +
      file["date"].getTimezoneOffset() * 60000
    )
  else
    file["date"] = new Date()
  if file["title"]?
    file["title"] = file["title"].toString()
  return file

getContentType = (docPath) ->
  switch path.extname(docPath)
    when ".html"
      return "text/html; charset=UTF-8"
    when ".html"
      return "text/html; charset=UTF-8"
    when ".js"
      return "application/javascript; charset=UTF-8"
    when ".css"
      return "text/css; charset=UTF-8"
    when ".txt"
      return "text/plain; charset=UTF-8"
    when ".manifest"
      return "text/cache-manifest; charset=UTF-8"
    else
      return "application/octet-stream"

paginate = (p, posts, perPage, ctx) ->
  if not perPage
    perPage = 10
  results = []
  perPagePosts = []
  for post in posts
    if perPagePosts.length is perPage
      results.push(Object.assign(new File(), p, ctx, {"posts": perPagePosts}))
      perPagePosts = []
    perPagePosts.push(post)
  results.push(Object.assign(new File(), p, ctx, {"posts": perPagePosts}))
  results[0]["pageArray"] = results
  results[0]["pageIndex"] = 0
  results[0]["docPath"] = p["docPath"]
  for i in [1...results.length]
    results[i]["pageArray"] = results
    results[i]["pageIndex"] = i
    results[i]["docPath"] = path.join(
      path.dirname(p["docPath"]),
      "#{path.basename(
        p["docPath"], path.extname(p["docPath"])
      )}-#{i + 1}.html"
    )
  return results

sortCategories = (category) ->
  category["posts"].sort((a, b) ->
    return -(a["date"] - b["date"])
  )
  category["subs"].sort((a, b) ->
    return a["name"].localeCompare(b["name"])
  )
  for sub in category["subs"]
    sortCategories(sub)

paginateCategories = (category, parentPath, perPage, site) ->
  results = []
  sp = Object.assign(new File(site.get("docDir")), {
    "layout": "category",
    "docPath": path.join(parentPath, "#{category["name"]}", "index.html"),
    "title": "category",
    "name": category["name"].toString()
  })
  category["docPath"] = sp["docPath"]
  results = results.concat(paginate(sp, category["posts"], perPage))
  for sub in category["subs"]
    results = results.concat(
      paginateCategories(sub, path.join(
        parentPath, "#{category["name"]}"
      ), perPage, site)
    )
  return results

getPathFn = (rootDir = path.posix.sep) ->
  rootDir = rootDir.replace(path.win32.sep, path.posix.sep)
  return (docPath = "") ->
    if not path.posix.isAbsolute(rootDir)
      rootDir = path.posix.join(path.posix.sep, rootDir)
    if docPath.endsWith("index.html")
      docPath = docPath.substring(0, docPath.length - "index.html".length)
    return encodeURI(path.posix.join(
      rootDir, docPath.replace(path.win32.sep, path.posix.sep)
    ))

getURLFn = (baseURL, rootDir = path.posix.sep) ->
  getPath = getPathFn(rootDir)
  return (docPath = "") ->
    return new URL(getPath(docPath), baseURL)

isCurrentPathFn = (rootDir = path.posix.sep, currentPath) ->
  # Must join a "/" before resolve or it will join current work dir.
  getPath = getPathFn(rootDir)
  currentPath = getPath(currentPath)
  currentToken = path.posix.resolve(path.posix.join(
    path.posix.sep, currentPath.replace(path.win32.sep, path.posix.sep)
  )).split(path.posix.sep)
  return (testPath = "", strict = false) ->
    testPath = getPath(testPath)
    if currentPath is testPath
      return true
    testToken = path.posix.resolve(path.posix.join(
      path.posix.sep, testPath.replace(path.win32.sep, path.posix.sep)
    )).split(path.posix.sep)
    if strict and testToken.length isnt currentToken.length
      return false
    # testPath is shorter and usually be a menu link.
    for i in [0...testToken.length]
      if testToken[i] isnt currentToken[i]
        return false
    return true

resolveHeaderIds = ($) ->
  hNames = ["h1", "h2", "h3", "h4", "h5", "h6"]
  headings = $(hNames.join(", "))
  headerIds = {}
  for h in headings
    text = $(h).text()
    # Remove some chars in escaped ID because
    # bootstrap scrollspy cannot support it.
    escaped = escapeHTML(text).trim().replace(
      /[\s\(\)\[\]{}<>\.,\!\@#\$%\^&\*=\|`"'/\?~]+/g,
      ""
    )
    if headerIds[escaped]
      id = "#{escaped}-#{headerIds[escaped]++}"
    else
      id = escaped
      headerIds[escaped] = 1
    $(h).attr("id", "#{id}")
    $(h).html(
      "<a class=\"headerlink\" href=\"##{id}\" title=\"#{escaped}\">" +
      "</a>" + "#{text}"
    )

genToc = ($) ->
  # TOC generate.
  hNames = ["h1", "h2", "h3", "h4", "h5", "h6"]
  headings = $(hNames.join(", "))
  toc = []
  for h in headings
    level = toc
    while level.length > 0 and
    hNames.indexOf(level[level.length - 1]["name"]) <
    hNames.indexOf(h["name"])
      level = level[level.length - 1]["subs"]
    # Don't set archor to absolute path because bootstrap scrollspy
    # can only accept relative path for ID.
    level.push({
      "archor": "##{$(h).attr("id")}",
      "name": h["name"]
      "text": $(h).text().trim(),
      "subs": []
    })
  return toc

resolveLink = ($, baseURL, rootDir, docPath) ->
  getURL = getURLFn(baseURL, rootDir)
  getPath = getPathFn(rootDir)
  # Replace relative path to absolute path.
  links = $("a")
  for a in links
    href = $(a).attr("href")
    if not href?
      continue
    if new URL(href, baseURL).host isnt getURL(docPath).host
      $(a).attr("target", "_blank")
    if href.startsWith("https://") or href.startsWith("http://") or
    href.startsWith("//") or href.startsWith("/") or
    href.startsWith("javascript:")
      continue
    $(a).attr("href", getPath(path.join(
      path.dirname(docPath), href
    )))

resolveImage = ($, rootDir, docPath) ->
  getPath = getPathFn(rootDir)
  # Replace relative path to absolute path.
  imgs = $("img")
  for i in imgs
    src = $(i).attr("src")
    if not src?
      continue
    if src.startsWith("https://") or src.startsWith("http://") or
    src.startsWith("//") or src.startsWith("/") or
    src.startsWith("file:image")
      continue
    $(i).attr("src", getPath(path.join(
      path.dirname(docPath), src
    )))

getVersion = () ->
  return packageJSON["version"]

module.exports = {
  "escapeHTML": escapeHTML,
  "matchFiles": matchFiles,
  "removeControlChars": removeControlChars,
  "parseFrontMatter": parseFrontMatter,
  "getContentType": getContentType,
  "paginate": paginate,
  "sortCategories": sortCategories,
  "paginateCategories": paginateCategories,
  "getPathFn": getPathFn,
  "getURLFn": getURLFn,
  "isCurrentPathFn": isCurrentPathFn,
  "resolveHeaderIds": resolveHeaderIds,
  "resolveLink": resolveLink,
  "resolveImage": resolveImage,
  "genToc": genToc,
  "getVersion": getVersion,
  "highlight": highlight
}
