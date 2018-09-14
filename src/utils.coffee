fm = require("front-matter")
path = require("path")
{URL} = require("url")
Promise = require("bluebird")

escapeHTML = (str) ->
  return str
  .replace(/&/g, "&amp;")
  .replace(/</g, "&lt;")
  .replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;")
  .replace(/"/g, "&#039;")

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
      results.push(Object.assign({}, p, ctx, {"posts": perPagePosts}))
      perPagePosts = []
    perPagePosts.push(post)
  results.push(Object.assign({}, p, ctx, {"posts": perPagePosts}))
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

paginateCategories = (category, parentPath, perPage, ctx) ->
  results = []
  sp = {
    "layout": "category",
    "docPath": path.join(parentPath, "#{category["name"]}", "index.html"),
    "title": "category",
    "name": category["name"].toString()
  }
  category["docPath"] = sp["docPath"]
  results = results.concat(paginate(sp, category["posts"], perPage, ctx))
  for sub in category["subs"]
    results = results.concat(
      paginateCategories(sub, path.join(
        parentPath, "#{category["name"]}"
      ), perPage, ctx)
    )
  return results

getAbsPathFn = (rootDir = path.posix.sep) ->
  rootDir = rootDir.replace(path.win32.sep, path.posix.sep)
  return (docPath = "") ->
    if not path.posix.isAbsolute(rootDir)
      rootDir = path.posix.join(path.posix.sep, rootDir)
    if docPath.endsWith("index.html")
      docPath = docPath.substring(0, docPath.length - "index.html".length)
    return encodeURI(path.posix.join(
      rootDir, docPath.replace(path.win32.sep, path.posix.sep)
    ))

getUrlFn = (baseUrl, rootDir = path.posix.sep) ->
  getAbsPath = getAbsPathFn(rootDir)
  return (docPath = "") ->
    return new URL(getAbsPath(docPath), baseUrl)

isCurrentPathFn = (rootDir = path.posix.sep, currentPath) ->
  # Must join a "/" before resolve or it will join current work dir.
  getAbsPath = getAbsPathFn(rootDir)
  currentPath = getAbsPath(currentPath)
  currentToken = path.posix.resolve(path.posix.join(
    path.posix.sep, currentPath.replace(path.win32.sep, path.posix.sep)
  )).split(path.posix.sep)
  return (testPath = "", strict = false) ->
    testPath = getAbsPath(testPath)
    if currentPath is testPath
      return true
    testToken = path.posix.resolve(path.posix.join(
      path.posix.sep, testPath.replace(path.win32.sep, path.posix.sep)
    )).split(path.posix.sep)
    if strict and testToken.length isnt currentToken.length
      return false
    for i in [0...currentToken.length]
      if testToken[i] isnt currentToken[i]
        return false
    return true

module.exports = {
  "escapeHTML": escapeHTML,
  "removeControlChars": removeControlChars,
  "parseFrontMatter": parseFrontMatter,
  "getContentType": getContentType,
  "paginate": paginate,
  "sortCategories": sortCategories,
  "paginateCategories": paginateCategories,
  "getAbsPathFn": getAbsPathFn,
  "getUrlFn": getUrlFn,
  "isCurrentPathFn": isCurrentPathFn
}
