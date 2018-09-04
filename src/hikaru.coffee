fse = require("fs-extra")
path = require("path")

cheerio = require("cheerio")

yaml = require("js-yaml")
nunjucks = require("nunjucks")
marked = require("marked")
stylus = require("stylus")
nib = require("nib")
coffee = require("coffeescript")

highlight = require("./highlight")
Logger = require("./logger")
Renderer = require("./renderer")
Generator = require("./generator")
Translator = require("./translator")
Router = require("./router")

module.exports =
class Hikaru
  constructor: (debug = false) ->
    @debug = debug
    @logger = new Logger(@debug)
    @logger.debug("Hikaru is starting...")
    process.on("exit", () =>
      @logger.debug("Hikaru is stopping...")
    )

  init: (workDir = ".", configPath, srcDir, docDir, themeSrcDir) =>
    @logger.debug("Hikaru started initialization in `#{workDir}`.")
    return fse.mkdirp(workDir).then(() =>
      @logger.debug("Hikaru created `#{workDir}/`.")
      return fse.mkdirp(srcDir or path.join(workDir, "src"))
    ).then(() =>
      @logger.debug("Hikaru created `#{srcDir or path.join(workDir, "src")}/`.")
      return fse.copy(path.join(__dirname, "..", "dist", "config.yml"),
      configPath or path.join(workDir, "config.yml"))
    ).then(() =>
      @logger.debug("Hikaru copyed `#{configPath or
      path.join(workDir, "config.yml")}`.")
      return fse.mkdirp(docDir or path.join(workDir, "doc"))
    ).then(() =>
      @logger.debug("Hikaru created `#{docDir or path.join(workDir, "doc")}/`.")
      return fse.mkdirp(themeSrcDir or path.join(workDir, "themes"))
    ).then(() =>
      @logger.debug("Hikaru created `#{themeSrcDir or
      path.join(workDir, "themes")}/`.")
      @logger.debug("Hikaru finished initialization in `#{workDir}`.")
    ).catch(@logger.error)

  clean: (workDir = ".", configPath, docDir) =>
    @workDir = workDir
    configPath = configPath or path.join(@workDir, "config.yml")
    @siteConfig = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    @docDir = docDir or path.join(@workDir, @siteConfig["docDir"]) or
    path.join(@workDir, "doc")
    fse.emptyDir(@docDir).then(() =>
      @logger.debug("Hikaru cleaned `#{@docDir}/`.")
    ).catch(@logger.error)

  generate: (workDir = ".", configPath, srcDir, docDir, themeDir) =>
    @workDir = workDir
    configPath = configPath or path.join(@workDir, "config.yml")
    @siteConfig = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    @srcDir = srcDir or path.join(@workDir, @siteConfig["srcDir"]) or
    path.join(@workDir, "src")
    @docDir = docDir or path.join(@workDir, @siteConfig["docDir"]) or
    path.join(@workDir, "doc")
    @themeDir = (if themeDir?
    then themeDir
    else path.join(@workDir, "themes", @siteConfig["themeDir"]) or
    path.join(@workDir, "themes", "aria"))
    @themeSrcDir = (if themeDir?
    then path.join(themeDir, "src")
    else path.join(@workDir, "themes", @siteConfig["themeDir"], "src") or
    path.join(@workDir, "themes", "aria", "src"))
    try
      @themeConfig = yaml.safeLoad(fse.readFileSync(path.join(@themeDir,
      "config.yml")))
    catch err
      if err["code"] is "ENOENT"
        @logger.info("Hikaru continues with a empty theme config...")
        @themeConfig = {}
    @renderer = new Renderer(@logger)
    @generator = new Generator(@logger)
    language = yaml.safeLoad(fse.readFileSync(path.join(@themeDir,
    "languages", "#{@siteConfig["language"]}.yml")))
    @translator = new Translator(language)
    @router = new Router(@logger, @renderer, @generator, @translator,
    @srcDir, @docDir, @themeSrcDir, @siteConfig, @themeConfig)
    @registerInternalRenderers()
    @registerInternalGenerators()
    @router.route()

  registerInternalRenderers: () =>
    templateDir = @themeSrcDir
    njkConfig = Object.assign({"autoescape": false}, @siteConfig["nunjucks"])
    njkEnv = nunjucks.configure(templateDir, njkConfig)
    @renderer.register([".njk", ".j2"], null, (data, ctx) ->
      # For template you must give a render function.
      template = nunjucks.compile(data["text"], njkEnv, data["srcPath"])
      njkRender = (ctx) ->
        return new Promise((resolve, reject) ->
          template.render(ctx, (err, res) ->
            if err
              return reject(err)
            return resolve(res)
          )
        )
      return njkRender
    )

    markedConfig = Object.assign({"gfm": true}, @siteConfig["marked"])
    renderer = new marked.Renderer()
    renderer.heading = (text, level) ->
      escaped = text.toLowerCase().replace(/[^\w]+/g, '-')
      return "<h#{level}>" +
      "<a class=\"headerlink\" href=\"##{escaped}\" title=\"##{escaped}\">" +
      "</a>" +
      "#{text}" +
      "</h#{level}>"
    marked.setOptions({
      "langPrefix": "",
      "highlight": (code, lang) ->
        return highlight(code, {
          "lang": lang?.toLowerCase(),
          "hljs":  markedConfig["hljs"] or true,
          "gutter": markedConfig["gutter"] or true
        })
    })
    @renderer.register(".md", ".html", (data, ctx) ->
      return new Promise((resolve, reject) ->
        try
          data["content"] = marked(
            data["text"],
            Object.assign({"renderer": renderer}, markedConfig)
          )
          return resolve(data)
        catch err
          return reject(err)
      )
    )

    stylConfig = @siteConfig.stylus or {}
    @renderer.register(".styl", ".css", (data, ctx) =>
      return new Promise((resolve, reject) =>
        stylus(data["text"])
        .use(nib())
        .use((style) =>
          style.define("getSiteConfig", (data) =>
            keys = data["val"].split(".")
            res = @themeConfig
            for k in keys
              if k not of res
                return null
              res = res[k]
            return res
          )
        ).use((style) =>
          style.define("getThemeConfig", (data) =>
            keys = data["val"].split(".")
            res = @themeConfig
            for k in keys
              if k not of res
                return null
              res = res[k]
            return res
          )
        ).set("filename", path.join(@themeSrcDir, data["srcPath"]))
        .set("sourcemap", stylConfig["sourcemap"])
        .set("compress", stylConfig["compress"])
        .set("include css", true)
        .render((err, res) ->
          if err
            return reject(err)
          data["content"] = res
          return resolve(data)
        )
      )
    )
    # TODO: CoffeeScript render.
    @renderer.register(".coffee", ".js", (data, ctx) ->)

  registerInternalGenerators: () =>
    @generator.register("index", (page, posts, ctx) =>
      posts.sort((a, b) ->
        return -(a["date"] - b["date"])
      )
      return paginate(page, posts, ctx, @siteConfig["perPage"])
    )

    @generator.register("archives", (page, posts, ctx) =>
      posts.sort((a, b) ->
        return -(a["date"] - b["date"])
      )
      return paginate(page, posts, ctx, @siteConfig["perPage"])
    )

    ###
    [
      {
        "name"：String,
        "posts": [Post],
        "subs": [
          {
            "name": String,
            "posts": [Post],
            "subs": []
          }
        ]
      }
    ]
    ###
    sortCategories = (category) ->
      category["posts"].sort((a, b) ->
        return -(a["date"] - b["date"])
      )
      category["subs"].sort((a, b) ->
        return a["name"].localeCompare(b["name"])
      )
      for sub in category["subs"]
        sortCategories(sub)
    paginateCategories = (category, page, parentPath, ctx) =>
      results = []
      p = Object.assign({}, page)
      p["layout"] = "category"
      p["docPath"] = path.join(parentPath, "#{category["name"]}", "index.html")
      category["docPath"] = p["docPath"]
      p["title"] = "category"
      p["name"] = "#{category["name"]}"
      results = results.concat(paginate(p, category["posts"], ctx,
      @siteConfig["perPage"]))
      for sub in category["subs"]
        results = results.concat(
          paginateCategories(sub, page, path.join(
            parentPath, "#{category["name"]}"
          ), ctx)
        )
      return results
    @generator.register("categories", (page, posts, ctx) ->
      categories = []
      for post in posts
        if not post["categories"]?
          continue
        postCategories = []
        subCategories = categories
        for cateName in post["categories"]
          found = false
          for category in subCategories
            if category["name"] is cateName
              found = true
              postCategories.push(category)
              category["posts"].push(post)
              subCategories = category["subs"]
              break
          if not found
            newCate = {"name": cateName, "posts": [post], "subs": []}
            postCategories.push(newCate)
            subCategories.push(newCate)
            subCategories = newCate["subs"]
        post["categories"] = postCategories
      categories.sort((a, b) ->
        return a["name"].localeCompare(b["name"])
      )
      for sub in categories
        sortCategories(sub)
      results = []
      for sub in categories
        results = results.concat(paginateCategories(sub, page,
        path.dirname(page["docPath"]), ctx))
      results.push(Object.assign(page, ctx, {"categories": categories}))
      return results
    )

    ###
    [
      {
        "name": String,
        "posts": [Post]
      }
    ]
    ###
    @generator.register("tags", (page, posts, ctx) =>
      tags = []
      for post in posts
        if not post["tags"]?
          continue
        postTags = []
        for tagName in post["tags"]
          found = false
          for tag in tags
            if tag["name"] is tagName
              found = true
              postTags.push(tag)
              tag["posts"].push(post)
              break
          if not found
            newTag = {"name": tagName, "posts": [post]}
            postTags.push(newTag)
            tags.push(newTag)
        post["tags"] = postTags
      tags.sort((a, b) ->
        return a["name"].localeCompare(b["name"])
      )
      for tag in tags
        tag["posts"].sort((a, b) ->
          return -(a["date"] - b["date"])
        )
      results = []
      for tag in tags
        p = Object.assign({}, page)
        p["layout"] = "tag"
        p["docPath"] = path.join(path.dirname(page["docPath"]),
        "#{tag["name"]}", "index.html")
        tag["docPath"] = p["docPath"]
        p["title"] = "tag"
        p["title"] = "#{tag["name"]}"
        results = results.concat(paginate(p, tag["posts"],
        ctx, @siteConfig["perPage"]))
      results.push(Object.assign(page, ctx, {"tags": tags}))
      return results
    )

    @generator.register(["post", "page"], (page, posts, ctx) ->
      $ = cheerio.load(page["content"])
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
        level.push({
          "id": $(h).attr("id"),
          "name": h["name"]
          "text": $(h).text().trim(),
          "subs": []
        })
      # Replace relative path to absolute path.
      links = $("a")
      for a in links
        href = $(a).attr("href")
        if href.startsWith("https://") or href.startsWith("http://") or
        href.startsWith("//") or href.startsWith("/") or
        href.startsWith("#")
          continue
        $(a).attr("href", path.posix.join(path.posix.sep,
        path.posix.dirname(page["docPath"]), href))
      imgs = $("img")
      for i in imgs
        src = $(i).attr("src")
        if src.startsWith("https://") or src.startsWith("http://") or
        src.startsWith("//") or src.startsWith("/") or
        src.startsWith("data:image")
          continue
        $(i).attr("src", path.posix.join(path.posix.sep,
        path.posix.dirname(page["docPath"]), src))
      return Object.assign(page, ctx, {
        "toc": toc,
        "content": $("body").html()
      })
    )

paginate = (page, posts, ctx, perPage) ->
  if not perPage
    perPage = 10
  results = []
  perPagePosts = []
  for post in posts
    if perPagePosts.length is perPage
      results.push(Object.assign(page, ctx, {"posts": perPagePosts}))
      perPagePosts = []
    perPagePosts.push(post)
  results.push(Object.assign(page, ctx, {"posts": perPagePosts}))
  results[0]["pageArray"] = results
  results[0]["pageIndex"] = 1
  results[0]["docPath"] = page["docPath"]
  for i in [1...results.length]
    results[i]["pageArray"] = results
    results[i]["pageIndex"] = i + 1
    results[i]["docPath"] = path.join(path.dirname(page["docPath"]),
    "#{results[i]["pageIndex"]}.html")
  return results
