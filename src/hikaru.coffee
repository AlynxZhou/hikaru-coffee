fse = require("fs-extra")
path = require("path")
{URL} = require("url")
glob = require("glob")

cheerio = require("cheerio")
moment = require("moment")

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

{
  escapeHTML,
  removeControlChars,
  paginate,
  dateStrCompare,
  sortCategories,
  paginateCategories,
  getAbsPathFn,
  getUrlFn
} = require("./utils")

module.exports =
class Hikaru
  constructor: (debug = false) ->
    @debug = debug
    @logger = new Logger(@debug)
    @logger.debug("Hikaru is starting...")
    process.on("exit", () =>
      @logger.debug("Hikaru is stopping...")
    )

  init: (workDir = ".", configPath) =>
    return fse.mkdirp(workDir).then(() =>
      @logger.debug("Hikaru started initialization in `#{path.join(
        workDir, path.sep
      )}`.")
      return fse.copy(
        path.join(__dirname, "..", "dist", "config.yml"),
        configPath or path.join(workDir, "config.yml")
      )
    ).then(() =>
      @logger.debug("Hikaru copyed `#{configPath or path.join(
        workDir, "config.yml"
      )}`.")
      return fse.mkdirp(path.join(workDir, "src"))
    ).then(() =>
      @logger.debug("Hikaru created `#{path.join(
        workDir, "src", path.sep
      )}`.")
      return fse.copy(
        path.join(__dirname, "..", "dist", "archives.md"),
        path.join(workDir, "src", "archives", "index.md")
      )
    ).then(() =>
      @logger.debug("Hikaru copyed `#{path.join(
        workDir, "src", "archives", "index.md"
      )}`.")
      return fse.copy(
        path.join(__dirname, "..", "dist", "categories.md"),
        path.join(workDir, "src", "categories", "index.md")
      )
    ).then(() =>
      @logger.debug("Hikaru copyed `#{path.join(
        workDir, "src", "categories", "index.md"
      )}`.")
      return fse.copy(
        path.join(__dirname, "..", "dist", "tags.md"),
        path.join(workDir, "src", "tags", "index.md")
      )
    ).then(() =>
      @logger.debug("Hikaru copyed `#{path.join(
        workDir, "src", "tags", "index.md"
      )}`.")
      return fse.mkdirp(path.join(workDir, "doc"))
    ).then(() =>
      @logger.debug("Hikaru created `#{path.join(
        workDir, "doc", path.sep
      )}`.")
      return fse.mkdirp(path.join(workDir, "themes"))
    ).then(() =>
      @logger.debug("Hikaru created `#{path.join(
        workDir, "themes", path.sep
      )}`.")
      @logger.debug("Hikaru finished initialization in `#{workDir}`.")
    ).catch(@logger.error)

  clean: (workDir = ".", configPath) =>
    configPath = configPath or path.join(workDir, "config.yml")
    siteConfig = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    if siteConfig?["docDir"]?
      glob("*", {
        "cwd": path.join(workDir, siteConfig["docDir"])
      }, (err, res) =>
        if err
          return err
        for r in res then do (r) =>
          fse.remove(path.join(workDir, siteConfig["docDir"], r)).then(() =>
            @logger.debug("Hikaru removed `#{path.join(
              workDir, siteConfig["docDir"], r
            )}`.")
          ).catch(@logger.error)
      )

  generate: (workDir = ".", configPath) =>
    @site = {
      "workDir": workDir
      "templates": {},
      "assets": [],
      "pages": [],
      "posts": [],
      "data": []
    }
    configPath = configPath or path.join(@site["workDir"], "config.yml")
    @site["siteConfig"] = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    @site["srcDir"] = path.join(
      @site["workDir"], @site["siteConfig"]["srcDir"]
    )
    @site["docDir"] = path.join(
      @site["workDir"], @site["siteConfig"]["docDir"]
    )
    @site["themeDir"] = path.join(
      @site["workDir"], "themes", @site["siteConfig"]["themeDir"]
    )
    @site["themeSrcDir"] = path.join(@site["themeDir"], "src")
    try
      @site["themeConfig"] = yaml.safeLoad(
        fse.readFileSync(path.join(@site["themeDir"], "config.yml"))
      )
    catch err
      if err["code"] is "ENOENT"
        @logger.info("Hikaru continues with a empty theme config...")
        @site["themeConfig"] = {}
    @renderer = new Renderer(@logger, @site["siteConfig"]["skipRender"])
    @generator = new Generator(@logger)
    @translator = new Translator(@logger)
    defaultLanguage = yaml.safeLoad(
      fse.readFileSync(
        path.join(@site["themeDir"], "languages", "default.yml")
      )
    )
    @translator.register("default", defaultLanguage)
    @router = new Router(@logger, @renderer, @generator, @translator, @site)
    @registerInternalRenderers()
    @registerInternalGenerators()
    @registerInternalRoutes()
    @router.route()

  registerInternalRenderers: () =>
    njkConfig = Object.assign(
      {"autoescape": false}, @site["siteConfig"]["nunjucks"]
    )
    njkEnv = nunjucks.configure(@site["themeSrcDir"], njkConfig)
    @renderer.register([".njk", ".j2"], null, (data, ctx) ->
      # For template you must give a render function.
      template = nunjucks.compile(data["text"], njkEnv, data["srcPath"])
      data["content"] = (ctx) ->
        return new Promise((resolve, reject) ->
          template.render(ctx, (err, res) ->
            if err
              return reject(err)
            return resolve(res)
          )
        )
    )

    markedConfig = Object.assign(
      {"gfm": true},
      @site["siteConfig"]["marked"]
    )
    renderer = new marked.Renderer()
    renderer.heading = (text, level) ->
      escaped = escapeHTML(text)
      return "<h#{level} id=\"#{escaped}\">" +
      "<a class=\"headerlink\" href=\"##{escaped}\" title=\"#{escaped}\">" +
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

    stylConfig = @site["siteConfig"]["stylus"] or {}
    @renderer.register(".styl", ".css", (data, ctx) =>
      return new Promise((resolve, reject) =>
        stylus(data["text"])
        .use(nib())
        .use((style) =>
          style.define("getSiteConfig", (data) =>
            keys = data["val"].toString().split(".")
            res = @site["siteConfig"]
            for k in keys
              if k not of res
                return null
              res = res[k]
            return res
          )
        ).use((style) =>
          style.define("getThemeConfig", (data) =>
            keys = data["val"].toString().split(".")
            res = @site["themeConfig"]
            for k in keys
              if k not of res
                return null
              res = res[k]
            return res
          )
        ).set("filename", path.join(@site["themeSrcDir"], data["srcPath"]))
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
      posts.sort(dateStrCompare)
      return paginate(page, posts, ctx, @site["siteConfig"]["perPage"])
    )

    @generator.register("archives", (page, posts, ctx) =>
      posts.sort(dateStrCompare)
      return paginate(page, posts, ctx, @site["siteConfig"]["perPage"])
    )

    @generator.register("categories", (page, posts, ctx) =>
      results = []
      for sub in ctx["site"]["categories"]
        results = results.concat(paginateCategories(
          sub,
          page,
          path.dirname(page["docPath"]),
          @site["siteConfig"]["perPage"],
          ctx
        ))
      results.push(Object.assign({}, page, ctx, {
        "categories": ctx["site"]["categories"]
      }))
      return results
    )

    @generator.register("tags", (page, posts, ctx) =>
      results = []
      for tag in ctx["site"]["tags"]
        p = Object.assign({}, page)
        p["layout"] = "tag"
        p["docPath"] = path.join(path.dirname(page["docPath"]),
        "#{tag["name"]}", "index.html")
        tag["docPath"] = p["docPath"]
        p["title"] = "tag"
        p["name"] = tag["name"].toString()
        results = results.concat(paginate(p, tag["posts"],
        ctx, @site["siteConfig"]["perPage"]))
      results.push(Object.assign({}, page, ctx, {
        "tags": ctx["site"]["tags"]
      }))
      return results
    )

    @generator.register(["post", "page"], (page, posts, ctx) =>
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
      getUrl = getUrlFn(
        @site["siteConfig"]["baseUrl"], @site["siteConfig"]["rootDir"]
      )
      links = $("a")
      for a in links
        href = $(a).attr("href")
        if new URL(href, @site["siteConfig"]["baseUrl"]).host isnt getUrl().host
          $(a).attr("target", "_blank")
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
      page["content"] = $("body").html()
      if page["content"].indexOf("<!--more-->") isnt -1
        split = page["content"].split("<!--more-->")
        page["excerpt"] = split[0]
        page["more"] = split[1]
      return Object.assign({}, page, ctx, {"toc": toc})
    )

  registerInternalRoutes: () =>
    @router.register("beforeGenerating", (site) ->
      # Generate categories
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
      categories = []
      categoriesLength = 0
      for post in site["posts"]
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
            ++categoriesLength
            postCategories.push(newCate)
            subCategories.push(newCate)
            subCategories = newCate["subs"]
        post["categories"] = postCategories
      categories.sort((a, b) ->
        return a["name"].localeCompare(b["name"])
      )
      for sub in categories
        sortCategories(sub)
      site["categories"] = categories
      site["categoriesLength"] = categoriesLength
      return site
    )

    @router.register("beforeGenerating", (site) ->
      # Generate tags.
      ###
      [
        {
          "name": String,
          "posts": [Post]
        }
      ]
      ###
      tags = []
      tagsLength = 0
      for post in site["posts"]
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
            ++tagsLength
            postTags.push(newTag)
            tags.push(newTag)
        post["tags"] = postTags
      tags.sort((a, b) ->
        return a["name"].localeCompare(b["name"])
      )
      for tag in tags
        tag["posts"].sort(dateStrCompare)
      site["tags"] = tags
      site["tagsLength"] = tagsLength
      return site
    )

    @router.register("afterGenerating", (site) ->
      if not site["siteConfig"]["search"]["enable"]
        return site
      # Generate search index.
      search = []
      all = site["pages"].concat(site["posts"])
      getAbsPath = getAbsPathFn(site["siteConfig"]["rootDir"])
      for p in all
        search.push({
          "title": "#{p["title"]}",
          "url": getAbsPath(p["docPath"]),
          "content": p["text"]
        })
      site["data"].push({
        # "srcPath": site["siteConfig"]["search"]["path"] or "search.json",
        "docPath": site["siteConfig"]["search"]["path"] or "search.json",
        "content": JSON.stringify(search)
      })
      return site
    )

    @router.register("afterGenerating", (site) ->
      if not site["siteConfig"]["feed"]["enable"]
        return site
      # Generate RSS feed.
      tmpContent = fse.readFileSync(path.join(
        __dirname, "..", "dist", "atom.njk"
      ), "utf8")
      content = nunjucks.renderString(tmpContent, {
        "site": site,
        "siteConfig": site["siteConfig"],
        "themeConfig": site["themeConfig"],
        "posts": site["posts"],
        "moment": moment,
        "removeControlChars": removeControlChars,
        "getUrl": getUrlFn(site["siteConfig"]["baseUrl"],
        site["siteConfig"]["rootDir"]),
        "getAbsPath": getAbsPathFn(site["siteConfig"]["rootDir"])
      })
      site["data"].push({
        # "srcPath": site["siteConfig"]["feed"]["path"] or "atom.xml",
        "docPath": site["siteConfig"]["feed"]["path"] or "atom.xml",
        "content": content
      })
      return site
    )
