path = require("path")
{URL} = require("url")

escapeHTML = (str) ->
  return str
  .replace(/&/g, "&amp;")
  .replace(/</g, "&lt;")
  .replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;")
  .replace(/'/g, "&#039;")

removeControlChars = (str) ->
  return str.replace(/[\x00-\x1F\x7F]/g, "")

paginate = (page, posts, ctx, perPage) ->
  if not perPage
    perPage = 10
  results = []
  perPagePosts = []
  for post in posts
    if perPagePosts.length is perPage
      results.push(Object.assign({}, page, ctx, {"posts": perPagePosts}))
      perPagePosts = []
    perPagePosts.push(post)
  results.push(Object.assign({}, page, ctx, {"posts": perPagePosts}))
  results[0]["pageArray"] = results
  results[0]["pageIndex"] = 0
  results[0]["docPath"] = page["docPath"]
  for i in [1...results.length]
    results[i]["pageArray"] = results
    results[i]["pageIndex"] = i
    results[i]["docPath"] = path.join(path.dirname(page["docPath"]),
    "#{path.basename(
      page["docPath"], path.extname(page["docPath"])
    )}-#{i + 1}.html")
  return results

dateStrCompare = (a, b) ->
  return -(new Date(a["date"]) - new Date(b["date"]))

sortCategories = (category) ->
  category["posts"].sort(dateStrCompare)
  category["subs"].sort((a, b) ->
    return a["name"].localeCompare(b["name"])
  )
  for sub in category["subs"]
    sortCategories(sub)

paginateCategories = (category, page, parentPath, perPage, ctx) ->
  results = []
  p = Object.assign({}, page)
  p["layout"] = "category"
  p["docPath"] = path.join(parentPath, "#{category["name"]}", "index.html")
  category["docPath"] = p["docPath"]
  p["title"] = "category"
  p["name"] = category["name"].toString()
  results = results.concat(paginate(p, category["posts"], ctx, perPage))
  for sub in category["subs"]
    results = results.concat(
      paginateCategories(sub, page, path.join(
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
    return encodeURI(path.posix.join(rootDir,
    docPath.replace(path.win32.sep, path.posix.sep)))

getUrlFn = (baseUrl, rootDir = path.posix.sep) ->
  getAbsPath = getAbsPathFn(rootDir)
  return (docPath = "") ->
    return new URL(getAbsPath(docPath), baseUrl)

isCurrentPathFn = (rootDir = path.posix.sep, currentPath) ->
  # Must join a "/" before resolve or it will join current work dir.
  getAbsPath = getAbsPathFn(rootDir)
  currentPath = getAbsPath(currentPath).toLowerCase()
  currentToken = path.posix.resolve(path.posix.join(
    path.posix.sep, currentPath.replace(path.win32.sep, path.posix.sep)
  )).split(path.posix.sep)
  return (testPath = "", strict = false) ->
    testPath = getAbsPath(testPath).toLowerCase()
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
  "paginate": paginate,
  "dateStrCompare": dateStrCompare,
  "sortCategories": sortCategories,
  "paginateCategories": paginateCategories,
  "getAbsPathFn": getAbsPathFn,
  "getUrlFn": getUrlFn,
  "isCurrentPathFn": isCurrentPathFn
}
