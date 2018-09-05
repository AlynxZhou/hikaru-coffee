path = require("path")

escapeHTML = (str) ->
  return str
  .replace(/&/g, "&amp;")
  .replace(/</g, "&lt;")
  .replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;")
  .replace(/'/g, "&#039;")

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
    "#{i + 1}.html")
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

module.exports = {
  "escapeHTML": escapeHTML,
  "paginate": paginate,
  "dateStrCompare": dateStrCompare,
  "sortCategories": sortCategories,
  "paginateCategories": paginateCategories
}
