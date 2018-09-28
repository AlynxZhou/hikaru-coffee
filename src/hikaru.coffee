fse = require("fs-extra")
path = require("path")
{URL} = require("url")
glob = require("glob")
cheerio = require("cheerio")
moment = require("moment")
colors = require("colors/safe")
Promise = require("bluebird")

yaml = require("js-yaml")
nunjucks = require("nunjucks")
marked = require("marked")
stylus = require("stylus")
nib = require("nib")
coffee = require("coffeescript")

highlight = require("./highlight")
Logger = require("./logger")
Site = require("./site")
Renderer = require("./renderer")
Processer = require("./processer")
Generator = require("./generator")
Translator = require("./translator")
Router = require("./router")
{
  escapeHTML,
  removeControlChars,
  paginate,
  sortCategories,
  paginateCategories,
  getPathFn,
  getURLFn
} = require("./utils")

class Hikaru
  constructor: (debug = false) ->
    @debug = debug
    @logger = new Logger(@debug)
    @logger.debug("Hikaru is starting...")
    process.on("exit", () =>
      @logger.debug("Hikaru is stopping...")
    )
    if process.platform is "win32"
      require("readline").createInterface({
        "input": process.stdin,
        "output": process.stdout
      }).on("SIGINT", () ->
        process.emit("SIGINT")
      )
    process.on("SIGINT", () ->
      process.exit(0)
    )

  init: (workDir = ".", configPath) =>
    return fse.mkdirp(workDir).then(() =>
      @logger.debug("Hikaru is copying `#{colors.cyan(
        configPath or path.join(workDir, "config.yml")
      )}`.")
      @logger.debug("Hikaru is creating `#{colors.cyan(
        path.join(workDir, "src", path.sep)
      )}`.")
      @logger.debug("Hikaru is creating `#{colors.cyan(path.join(
        workDir, "doc", path.sep
      ))}`.")
      @logger.debug("Hikaru is creating `#{colors.cyan(path.join(
        workDir, "themes", path.sep
      ))}`.")
      fse.copy(
        path.join(__dirname, "..", "dist", "config.yml"),
        configPath or path.join(workDir, "config.yml")
      )
      fse.mkdirp(path.join(workDir, "src")).then(() =>
        @logger.debug("Hikaru is copying `#{colors.cyan(path.join(
          workDir, "src", "archives", "index.md"
        ))}`.")
        @logger.debug("Hikaru is copying `#{colors.cyan(path.join(
          workDir, "src", "categories", "index.md"
        ))}`.")
        @logger.debug("Hikaru is copying `#{colors.cyan(path.join(
          workDir, "src", "tags", "index.md"
        ))}`.")
        fse.copy(
          path.join(__dirname, "..", "dist", "archives.md"),
          path.join(workDir, "src", "archives", "index.md")
        )
        fse.copy(
          path.join(__dirname, "..", "dist", "categories.md"),
          path.join(workDir, "src", "categories", "index.md")
        )
        fse.copy(
          path.join(__dirname, "..", "dist", "tags.md"),
          path.join(workDir, "src", "tags", "index.md")
        )
      )
      fse.mkdirp(path.join(workDir, "doc"))
      fse.mkdirp(path.join(workDir, "themes"))
    ).catch((err) =>
      @logger.warn("Hikaru catched some error during initializing!")
      @logger.error(err)
    )

  clean: (workDir = ".", configPath) =>
    configPath = configPath or path.join(workDir, "config.yml")
    siteConfig = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    if not siteConfig?["docDir"]?
      return
    glob("*", {
      "cwd": path.join(workDir, siteConfig["docDir"])
    }, (err, res) =>
      if err
        return err
      return res.map((r) =>
        fse.stat(path.join(workDir, siteConfig["docDir"], r)).then((stats) =>
          if stats.isDirectory()
            @logger.debug("Hikaru is removing `#{colors.cyan(path.join(
              workDir, siteConfig["docDir"], r, path.sep
            ))}`.")
          else
            @logger.debug("Hikaru is removing `#{colors.cyan(path.join(
              workDir, siteConfig["docDir"], r
            ))}`.")
          return fse.remove(path.join(workDir, siteConfig["docDir"], r))
        ).catch((err) =>
          @logger.warn("Hikaru catched some error during cleaning!")
          @logger.error(err)
        )
      )
    )

  generate: (workDir = ".", configPath) =>
    @loadSite(workDir, configPath)
    @loadModules()
    try
      await @router.generate()
    catch err
      @logger.warn("Hikaru catched some error during generating!")
      @logger.error(err)
      @logger.warn("Hikaru advise you to check generated files!")

  serve: (workDir = ".", configPath, ip, port) =>
    @loadSite(workDir, configPath)
    @loadModules()
    try
      await @router.serve(ip or "localhost", Number.parseInt(port) or 2333)
    catch err
      @logger.warn("Hikaru catched some error during serving!")
      @logger.error(err)

  loadSite: (workDir, configPath) =>
    @site = new Site(workDir)
    configPath = configPath or path.join(@site.get("workDir"), "config.yml")
    try
      @site.set(
        "siteConfig", yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
      )
    catch err
      @logger.warn("Hikaru cannot find site config!")
      @logger.error(err)
      process.exit(-1)
    @site.set("srcDir", path.join(
      @site.get("workDir"), @site.get("siteConfig")["srcDir"] or "srcs"
    ))
    @site.set("docDir", path.join(
      @site.get("workDir"), @site.get("siteConfig")["docDir"] or "docs"
    ))
    @site.set("themeDir", path.join(
      @site.get("workDir"), "themes", @site.get("siteConfig")["themeDir"]
    ))
    @site.set("themeSrcDir", path.join(@site.get("themeDir"), "srcs"))
    try
      @site.set("themeConfig", yaml.safeLoad(
        fse.readFileSync(path.join(@site.get("themeDir"), "config.yml"))
      ))
    catch err
      if err["code"] is "ENOENT"
        @logger.warn("Hikaru continues with a empty theme config...")
    @site.set(
      "categoryDir", @site.get("siteConfig")["categoryDir"] or "categories"
    )
    @site.set("tagDir", @site.get("siteConfig")["tagDir"] or "tags")

  loadModules: () =>
    @renderer = new Renderer(@logger, @site.get("siteConfig")["skipRender"])
    @processer = new Processer(@logger)
    @generator = new Generator(@logger)
    @translator = new Translator(@logger)
    try
      defaultLanguage = yaml.safeLoad(
        fse.readFileSync(
          path.join(@site.get("themeDir"), "languages", "default.yml")
        )
      )
      @translator.register("default", defaultLanguage)
    catch err
      if err["code"] is "ENOENT"
        @logger.warn("Hikaru cannot find default language file in your theme.")
    @router = new Router(
      @logger, @renderer, @processer, @generator, @translator, @site
    )
    try
      @registerInternalRenderers()
      @registerInternalProcessers()
      @registerInternalGenerators()
    catch err
      @logger.warn("Hikaru cannot register internal functions!")
      @logger.error(err)
      process.exit(-2)

  registerInternalRenderers: () =>
    njkConfig = Object.assign(
      {"autoescape": false}, @site.get("siteConfig")["nunjucks"]
    )
    njkEnv = nunjucks.configure(@site.get("themeSrcDir"), njkConfig)
    @renderer.register([".njk", ".j2"], null, (file, ctx) ->
      return new Promise((resolve, reject) ->
        try
          template = nunjucks.compile(file["text"], njkEnv, file["srcPath"])
          # For template you must give a render function.
          file["content"] = (ctx) ->
            return new Promise((resolve, reject) ->
              template.render(ctx, (err, res) ->
                if err
                  return reject(err)
                return resolve(res)
              )
            )
          return resolve(file)
        catch err
          return reject(err)
      )
    )

    markedConfig = Object.assign({
      "gfm": true,
      "langPrefix": "",
      "highlight": (code, lang) =>
        return highlight(code, Object.assign({
          "lang": lang?.toLowerCase(),
          "hljs": true,
          "gutter": true
        }, @site.get("siteConfig")["highlight"]))
    }, @site.get("siteConfig")["marked"])
    marked.setOptions(markedConfig)
    @renderer.register(".md", ".html", (file, ctx) ->
      return new Promise((resolve, reject) ->
        try
          file["content"] = marked(file["text"])
          return resolve(file)
        catch err
          return reject(err)
      )
    )

    stylConfig = @site.get("siteConfig")["stylus"] or {}
    @renderer.register(".styl", ".css", (file, ctx) =>
      return new Promise((resolve, reject) =>
        stylus(file["text"])
        .use(nib())
        .use((style) =>
          style.define("getSiteConfig", (file) =>
            keys = file["val"].toString().split(".")
            res = @site.get("siteConfig")
            for k in keys
              if k not of res
                return null
              res = res[k]
            return res
          )
        ).use((style) =>
          style.define("getThemeConfig", (file) =>
            keys = file["val"].toString().split(".")
            res = @site.get("themeConfig")
            for k in keys
              if k not of res
                return null
              res = res[k]
            return res
          )
        ).set("filename", path.join(@site.get("themeSrcDir"), file["srcPath"]))
        .set("sourcemap", stylConfig["sourcemap"])
        .set("compress", stylConfig["compress"])
        .set("include css", true)
        .render((err, res) ->
          if err
            return reject(err)
          file["content"] = res
          return resolve(file)
        )
      )
    )

    coffeeConfig = @site.get("siteConfig")["coffeescript"] or {}
    @renderer.register(".coffee", ".js", (file, ctx) ->
      return new Promise((resolve, reject) ->
        try
          file["content"] = coffee.compile(file["text"], coffeeConfig)
          return resolve(file)
        catch err
          return reject(err)
      )
    )

  registerInternalProcessers: () =>
    @processer.register("index", (p, posts, ctx) =>
      return new Promise((resolve, reject) =>
        try
          posts.sort((a, b) ->
            return -(a["date"] - b["date"])
          )
          return resolve(paginate(
            p, posts, @site.get("siteConfig")["perPage"], ctx
          ))
        catch err
          return reject(err)
      )
    )

    @processer.register("archives", (p, posts, ctx) =>
      return new Promise((resolve, reject) =>
        try
          posts.sort((a, b) ->
            return -(a["date"] - b["date"])
          )
          return resolve(paginate(
            p, posts, @site.get("siteConfig")["perPage"], ctx
          ))
        catch err
          return reject(err)
      )
    )

    @processer.register("categories", (p, posts, ctx) =>
      return new Promise((resolve, reject) =>
        try
          return resolve(Object.assign({}, p, ctx, {
            "categories": @site.get("categories")
          }))
        catch err
          return reject(err)
      )
    )

    @processer.register("tags", (p, posts, ctx) =>
      return new Promise((resolve, reject) =>
        try
          return resolve(Object.assign({}, p, ctx, {
            "tags": @site.get("tags")
          }))
        catch err
          return reject(err)
      )
    )

    @processer.register(["post", "page"], (p, posts, ctx) =>
      return new Promise((resolve, reject) =>
        try
          getURL = getURLFn(
            @site.get("siteConfig")["baseURL"],
            @site.get("siteConfig")["rootDir"]
          )
          getPath = getPathFn(@site.get("siteConfig")["rootDir"])
          $ = cheerio.load(p["content"])
          # TOC generate.
          hNames = ["h1", "h2", "h3", "h4", "h5", "h6"]
          headings = $(hNames.join(", "))
          toc = []
          headerIds = {}
          for h in headings
            level = toc
            while level.length > 0 and
            hNames.indexOf(level[level.length - 1]["name"]) <
            hNames.indexOf(h["name"])
              level = level[level.length - 1]["subs"]
            text = $(h).text()
            # Remove space in escaped ID because
            # bootstrap scrollspy cannot support it.
            escaped = escapeHTML(text).trim().replace(/\s+/, "")
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
            # Don't set archor to absolute path because bootstrap scrollspy
            # can only accept relative path for ID.
            level.push({
              "archor": "##{id}",
              "name": h["name"]
              "text": text.trim(),
              "subs": []
            })
          # Replace relative path to absolute path.
          links = $("a")
          for a in links
            href = $(a).attr("href")
            if new URL(
              href, @site.get("siteConfig")["baseURL"]
            ).host isnt getURL(p["docPath"]).host
              $(a).attr("target", "_blank")
            if href.startsWith("https://") or href.startsWith("http://") or
            href.startsWith("//") or href.startsWith("/") or
            href.startsWith("javascript:")
              continue
            $(a).attr("href", getPath(path.join(
              path.dirname(p["docPath"]), href
            )))
          imgs = $("img")
          for i in imgs
            src = $(i).attr("src")
            if src.startsWith("https://") or src.startsWith("http://") or
            src.startsWith("//") or src.startsWith("/") or
            src.startsWith("file:image")
              continue
            $(i).attr("src", getPath(path.join(
              path.dirname(p["docPath"]), src
            )))
          p["content"] = $("body").html()
          if p["content"].indexOf("<!--more-->") isnt -1
            split = p["content"].split("<!--more-->")
            p["excerpt"] = split[0]
            p["more"] = split[1]
          return resolve(Object.assign({}, p, ctx, {"toc": toc, "$": $}))
        catch err
          return reject(err)
      )
    )

  registerInternalGenerators: () =>
    @generator.register("beforeProcessing", (site) ->
      # Generate categories
      return new Promise((resolve, reject) ->
        try
          categories = []
          categoriesLength = 0
          for post in site.get("posts")
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
            for p in paginateCategories(
              sub,
              site.get("categoryDir"),
              site.get("siteConfig")["perPage"]
            )
              site.put("pages", p)
          site.set("categories", categories)
          site.set("categoriesLength", categoriesLength)
          return resolve(site)
        catch err
          return reject(err)
      )
    )

    @generator.register("beforeProcessing", (site) ->
      # Generate tags.
      return new Promise((resolve, reject) ->
        try
          tags = []
          tagsLength = 0
          for post in site.get("posts")
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
                newTag = {"name": tagName, "posts": [post]}
                ++tagsLength
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
            sp = {
              "layout": "tag",
              "docPath": path.join(
                site.get("tagDir"), "#{tag["name"]}", "index.html"
              ),
              "title": "tag",
              "name": tag["name"].toString()
            }
            tag["docPath"] = sp["docPath"]
            for p in paginate(
              sp, tag["posts"], site.get("siteConfig")["perPage"]
            )
              site.put("pages", p)
          site.set("tags", tags)
          site.set("tagsLength", tagsLength)
          return resolve(site)
        catch err
          return reject(err)
      )
    )

    @generator.register("afterProcessing", (site) ->
      return new Promise((resolve, reject) ->
        try
          if not site.get("siteConfig")["search"]["enable"]
            return resolve(site)
          # Generate search index.
          search = []
          all = site.get("pages").concat(site.get("posts"))
          getPath = getPathFn(site.get("siteConfig")["rootDir"])
          for p in all
            search.push({
              "title": "#{p["title"]}",
              "url": getPath(p["docPath"]),
              "content": p["text"]
            })
          site.put("files", {
            "docPath": site.get(
              "siteConfig"
            )["search"]["path"] or "search.json",
            "content": JSON.stringify(search)
          })
          return resolve(site)
        catch err
          return reject(err)
      )
    )

    @generator.register("afterProcessing", (site) ->
      return new Promise((resolve, reject) ->
        try
          if not site.get("siteConfig")["sitemap"]["enable"]
            return resolve(site)
          # Generate sitemap.
          tmpContent = fse.readFileSync(path.join(
            __dirname, "..", "dist", "sitemap.njk"
          ), "utf8")
          content = nunjucks.renderString(tmpContent, {
            "posts": site.get("posts"),
            "getURL": getURLFn(site.get("siteConfig")["baseURL"],
            site.get("siteConfig")["rootDir"]),
            "getPath": getPathFn(site.get("siteConfig")["rootDir"])
          })
          site.put("files", {
            "docPath": site.get(
              "siteConfig"
            )["sitemap"]["path"] or "sitemap.xml",
            "content": content
          })
          return resolve(site)
        catch err
          return reject(err)
      )
    )

    @generator.register("afterProcessing", (site) ->
      return new Promise((resolve, reject) ->
        try
          if not site.get("siteConfig")["feed"]["enable"]
            return resolve(site)
          # Generate RSS feed.
          tmpContent = fse.readFileSync(path.join(
            __dirname, "..", "dist", "atom.njk"
          ), "utf8")
          content = nunjucks.renderString(tmpContent, {
            "siteConfig": site.get("siteConfig"),
            "themeConfig": site.get("themeConfig"),
            "posts": site.get("posts"),
            "removeControlChars": removeControlChars,
            "getURL": getURLFn(site.get("siteConfig")["baseURL"],
            site.get("siteConfig")["rootDir"]),
            "getPath": getPathFn(site.get("siteConfig")["rootDir"])
          })
          site.put("files", {
            "docPath": site.get("siteConfig")["feed"]["path"] or "atom.xml",
            "content": content
          })
          return resolve(site)
        catch err
          return reject(err)
      )
    )

module.exports = Hikaru
