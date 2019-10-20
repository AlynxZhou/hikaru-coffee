fm = require("front-matter")
fse = require("fs-extra")
path = require("path")
glob = require("glob")
{URL} = require("url")
moment = require("moment-timezone")
Promise = require("bluebird")
{Site, File, Category, Tag, Toc} = require("./types")
highlight = require("./highlight")
packageJSON = require("../package.json")
extMIME = require("../dist/ext-mime.json")

isString = (o) ->
  return typeof(o) is "string"

isBuffer = (o) ->
  return Buffer.isBuffer(o)

isArray = (o) ->
  return Array.isArray(o)

isFunction = (o) ->
  return o instanceof Function

isObject = (o) ->
  return typeof(o) is "object" and o != null

escapeHTML = (str) ->
  return str
  .replace(/&/g, "&amp;")
  .replace(/</g, "&lt;")
  .replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;")
  .replace(/'/g, "&#039;")

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

# YAML ignores your local timezone and parse time as UTC.
# This function will transpose it to a time without timezone.
# Which looks the same as the original string.
# If you keep timezone, you cannot easily parse it as another timezone.
# https://github.com/nodeca/js-yaml/issues/91
transposeYAMLTime = (datetime) ->
  # If you don't write full YYYY-MM-DD HH:mm:ss, js-yaml will leave a string.
  if isString(datetime)
    return moment(datetime).format("YYYY-MM-DD HH:mm:ss")
  return moment(
    new Date(datetime.getTime() + datetime.getTimezoneOffset() * 60000)
  ).format("YYYY-MM-DD HH:mm:ss")

parseFrontMatter = (file) ->
  if not isString(file["raw"])
    return file
  parsed = fm(file["raw"])
  file["text"] = parsed["body"]
  file["frontMatter"] = parsed["attributes"]
  file = Object.assign(file, parsed["attributes"])
  file["title"] = file["title"]?.toString()
  # Nunjucks does not allow to call moment.tz.guess() in template.
  # So we pass timezone to each file as an attribute.
  file["zone"] = file["zone"] or moment.tz.guess()
  if not file["updatedTime"]?
    file["updatedTime"] = fse.statSync(path.join(
      file["srcDir"], file["srcPath"]
    ))["mtime"]
  else
    file["updatedTime"] = moment.tz(
      transposeYAMLTime(file["updatedTime"]), file["zone"]
    ).toDate()
  # Fallback compatibility.
  file["createdTime"] = file["createdTime"] or file["date"]
  if not file["createdTime"]?
    file["createdTime"] = file["updatedTime"]
    file["createdMoment"] = moment(file["createdTime"])
  else
    # Parsing non-timezone string with a user-specific timezone.
    file["createdMoment"] = moment.tz(
      transposeYAMLTime(file["createdTime"]), file["zone"]
    )
    file["createdTime"] = file["createdMoment"].toDate()
  if file["language"]?
    file["createdMoment"].locale(file["language"])
  # Fallback compatibility.
  file["date"] = file["createdTime"]
  return file

getContentType = (docPath) ->
  return extMIME[path.extname(docPath)] or "application/octet-stream"

paginate = (p, posts, perPage = 10) ->
  results = []
  perPagePosts = []
  for post in posts
    if perPagePosts.length is perPage
      results.push(Object.assign(new File(), p, {"posts": perPagePosts}))
      perPagePosts = []
    perPagePosts.push(post)
  results.push(Object.assign(new File(), p, {"posts": perPagePosts}))
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

paginateCategories = (category, parentPath, site, perPage = 10) ->
  results = []
  sp = new File({
    "layout": "category",
    "docDir": site["siteConfig"]["docDir"],
    "docPath": path.join(parentPath, "#{category["name"]}", "index.html"),
    "title": "category",
    "name": category["name"].toString(),
    "comment": false,
    "reward": false
  })
  category["docPath"] = sp["docPath"]
  results = results.concat(paginate(sp, category["posts"], perPage))
  for sub in category["subs"]
    results = results.concat(
      paginateCategories(sub, path.join(
        parentPath, "#{category["name"]}"
      ), site, perPage)
    )
  return results

getPathFn = (rootDir = path.posix.sep) ->
  rootDir = rootDir.replace(path.win32.sep, path.posix.sep)
  return (docPath = "") ->
    if not path.posix.isAbsolute(rootDir)
      rootDir = path.posix.join(path.posix.sep, rootDir)
    if docPath.endsWith("index.html")
      docPath = docPath.substring(0, docPath.length - "index.html".length)
    else if docPath.endsWith("index.htm")
      docPath = docPath.substring(0, docPath.length - "index.htm".length)
    return encodeURI(path.posix.join(
      rootDir, docPath.replace(path.win32.sep, path.posix.sep)
    ))

getURLFn = (baseURL, rootDir = path.posix.sep) ->
  getPath = getPathFn(rootDir)
  return (docPath = "") ->
    return new URL(getPath(docPath), baseURL)

isCurrentPathFn = (rootDir = path.posix.sep, currentPath = "") ->
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

genCategories = (posts) ->
  categories = []
  categoriesLength = 0
  for post in posts
    if not post["frontMatter"]["categories"]?
      continue
    postCategories = []
    subCategories = categories
    for cateName in post["frontMatter"]["categories"]
      found = false
      for category in subCategories
        if category["name"] is cateName
          found = true
          postCategories.push(category)
          category["posts"].push(post)
          subCategories = category["subs"]
          break
      if not found
        newCate = new Category(cateName, [post], [])
        ++categoriesLength
        postCategories.push(newCate)
        subCategories.push(newCate)
        subCategories = newCate["subs"]
    post["categories"] = postCategories
  categories.sort((a, b) ->
    return a["name"].localeCompare(b["name"])
  )
  return {"categories": categories, "categoriesLength": categoriesLength}

genTags = (posts) ->
  tags = []
  tagsLength = 0
  for post in posts
    if not post["frontMatter"]["tags"]?
      continue
    postTags = []
    for tagName in post["frontMatter"]["tags"]
      found = false
      for tag in tags
        if tag["name"] is tagName
          found = true
          postTags.push(tag)
          tag["posts"].push(post)
          break
      if not found
        newTag = new Tag(tagName, [post])
        ++tagsLength
        postTags.push(newTag)
        tags.push(newTag)
    post["tags"] = postTags
  tags.sort((a, b) ->
    return a["name"].localeCompare(b["name"])
  )
  return {"tags": tags, "tagsLength": tagsLength}

getFileLayout = (file, available) ->
  if not file["layout"]?
    return null
  if file["layout"] not in available
    return "page"
  return file["layout"]

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
      "<a class=\"header-link\" href=\"##{id}\" title=\"#{escaped}\">" +
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
    level.push(new Toc(h["name"], "##{$(h).attr("id")}", $(h).text().trim()))
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
      $(a).attr("rel", "noreferrer noopener")
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

default404 = """
  <!DOCTYPE html>
  <html>
    <head>
      <meta charset="utf-8">
      <meta http-equiv="X-UA-Compatible" content="IE=edge">
      <meta name="viewport" content="
        width=device-width,
        initial-scale=1,
        maximum-scale=1
      ">
      <title>404 Not Found</title>
    </head>
    <body>
      <h1>404 Not Found</h1>
      <p>Hikaru v#{getVersion()}</p>
    </body>
  </html>
"""

module.exports = {
  "isString": isString,
  "isBuffer": isBuffer,
  "isArray": isArray,
  "isFunction": isFunction,
  "isObject": isObject,
  "default404": default404,
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
  "genCategories": genCategories,
  "genTags": genTags,
  "getFileLayout": getFileLayout,
  "isCurrentPathFn": isCurrentPathFn,
  "resolveHeaderIds": resolveHeaderIds,
  "resolveLink": resolveLink,
  "resolveImage": resolveImage,
  "genToc": genToc,
  "getVersion": getVersion,
  "highlight": highlight
}
