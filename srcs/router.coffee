fse = require("fs-extra")
path = require("path")
yaml = require("js-yaml")
http = require("http")
{URL} = require("url")
colors = require("colors/safe")
moment = require("moment-timezone")
chokidar = require("chokidar")
Promise = require("bluebird")
{Site, File, Category, Tag} = require("./types")
{
  isArray,
  isString,
  isFunction,
  isObject,
  default404,
  matchFiles,
  getVersion,
  getPathFn,
  getURLFn,
  getContentType,
  getFileLayout,
  isCurrentPathFn,
  parseFrontMatter
} = require("./utils")

class Router
  constructor: (logger, renderer, processor, generator, translator, site) ->
    @logger = logger
    @renderer = renderer
    @processor = processor
    @generator = generator
    @translator = translator
    @site = site
    @_ = {}
    @watchers = []
    @watchedEvents = []
    @sourcePages = []
    @handling = false
    @getURL = getURLFn(
      @site["siteConfig"]["baseURL"], @site["siteConfig"]["rootDir"]
    )
    @getPath = getPathFn(@site["siteConfig"]["rootDir"])
    moment.locale(@site["siteConfig"]["language"])

  read: (path) ->
    return fse.readFile(path)

  write: (content, file) ->
    if not file["isBinary"]
      return fse.outputFile(
        path.join(file["docDir"], file["docPath"]), content
      )
    return fse.copy(
      path.join(file["srcDir"], file["srcPath"]),
      path.join(file["docDir"], file["docPath"])
    )

  loadFile: (file) =>
    @logger.debug("Hikaru is reading `#{colors.cyan(
      path.join(file["srcDir"], file["srcPath"])
    )}`...")
    raw = await @read(path.join(file["srcDir"], file["srcPath"]))
    # Auto detect if a file is a binary file or a UTF-8 encoding text file.
    if raw.equals(Buffer.from(raw.toString("utf8"), "utf8"))
      raw = raw.toString("utf8")
      file["isBinary"] = false
    else
      file["isBinary"] = true
    file["raw"] = raw
    file["text"] = raw
    file = parseFrontMatter(file)
    results = await Promise.all(@renderer.render(file))
    for result in results
      if isFunction(result["content"])
        result["type"] = "template"
        @site["templates"][path.basename(
          result["srcPath"], path.extname(result["srcPath"])
        )] = result["content"]
      else if result["layout"] is "post"
        result["type"] = "post"
        @site.put("posts", result)
      else if result["layout"]?
        result["type"] = "page"
        @site.put("pages", result)
      else
        result["type"] = "asset"
        @site.put("assets", result)

  saveFile: (file) =>
    @logger.debug("Hikaru is writing `#{colors.cyan(
      path.join(file["docDir"], file["docPath"])
    )}`...")
    layout = getFileLayout(file, Object.keys(@site["templates"]))
    if layout?
      @write(await @site["templates"][layout](@loadContext(file)), file)
    else
      @write(file["content"], file)

  loadLanguage: (file) =>
    lang = file["language"] or @site["siteConfig"]["language"]
    if lang not of @translator.list()
      try
        language = yaml.safeLoad(fse.readFileSync(path.join(
          @site["siteConfig"]["themeDir"], "languages", "#{lang}.yml"
        )))
        @translator.register(lang, language)
      catch err
        if err["code"] is "ENOENT"
          @logger.warn(
            "Hikaru cannot find `#{lang}` language file in your theme."
          )
    return lang

  loadContext: (file) =>
    lang = @loadLanguage(file)
    return Object.assign(new File(), file, {
      "site": @site,
      "siteConfig": @site["siteConfig"],
      "themeConfig": @site["themeConfig"],
      "moment": moment,
      "getVersion": getVersion,
      "getURL": @getURL,
      "getPath": @getPath,
      "isCurrentPath": isCurrentPathFn(
        @site["siteConfig"]["rootDir"], file["docPath"]
      ),
      "isArray": isArray,
      "isString": isString,
      "isFunction": isFunction,
      "isObject": isObject,
      "__": @translator.getTranslateFn(lang)
    })

  matchAll: () =>
    return (await matchFiles(path.join("**", "*"), {
      "nodir": true,
      "dot": true,
      "cwd": @site["siteConfig"]["themeSrcDir"]
    })).map((srcPath) =>
      return new File(
        @site["siteConfig"]["docDir"],
        @site["siteConfig"]["themeSrcDir"],
        srcPath
      )
    ).concat((await matchFiles(path.join("**", "*"), {
      "nodir": true,
      "dot": true,
      "cwd": @site["siteConfig"]["srcDir"]
    })).map((srcPath) =>
      return new File(
        @site["siteConfig"]["docDir"],
        @site["siteConfig"]["srcDir"],
        srcPath
      )
    ))

  buildServerRoutes: (allFiles) =>
    @_ = {}
    for f in allFiles
      key = @getPath(f["docPath"])
      @logger.debug("Hikaru is serving `#{colors.cyan(key)}`...")
      @_[key] = f

  watchAll: () =>
    for srcDir in [
      @site["siteConfig"]["themeSrcDir"], @site["siteConfig"]["srcDir"]
    ] then do (srcDir) =>
      watcher = chokidar.watch(path.join("**", "*"), {
        "cwd": srcDir, "ignoreInitial": true
      })
      @watchers.push(watcher)
      for event in ["add", "change", "unlink"] then do (event) =>
        watcher.on(event, (srcPath) =>
          @logger.debug(
            "Hikaru watched event `#{colors.blue(event)}` from `#{
              colors.cyan(path.join(srcDir, srcPath))
            }`"
          )
          i = @watchedEvents.findIndex((p) ->
            return p["srcDir"] is srcDir and p["srcPath"] is srcPath
          )
          if i isnt -1
            # Just update event.
            @watchedEvents[i]["type"] = event
          else
            # Not found.
            @watchedEvents.push({
              "type": event, "srcDir": srcDir, "srcPath": srcPath
            })
          setImmediate(@handleEvents)
        )

  unwatchAll: () =>
    while (w = @watchers.shift())?
      w.close()

  handleEvents: () =>
    # Keep handling atomic. Prevent repeatedly handling.
    if not @watchedEvents.length or @handling
      return
    @handling = true
    while (e = @watchedEvents.shift())?
      file = new File(@site["siteConfig"]["docDir"], e["srcDir"], e["srcPath"])
      if e["type"] is "unlink"
        for key in ["assets", "pages", "posts"]
          @site.del(key, file)
      else
        file = await @loadFile(file)
    await @handle()
    @buildServerRoutes(
      @site["assets"].concat(@site["posts"])
      .concat(@site["pages"]).concat(@site["files"])
    )
    @handling = false

  listen: (ip, port) =>
    server = http.createServer((request, response) =>
      # Remove query string.
      url = request["url"].split(/[?#]/)[0]
      if url not of @_
        @logger.log("404: #{url}")
        res = @_[@getPath("404.html")] or {
          "content": default404,
          "docPath": @getPath("404.html")
        }
        response.writeHead(404, {
          "Content-Type": getContentType(res["docPath"])
        })
      else
        @logger.log("200: #{url}")
        res = @_[url]
        response.writeHead(200, {
          "Content-Type": getContentType(res["docPath"])
        })
      layout = getFileLayout(res, Object.keys(@site["templates"]))
      if layout?
        response.write(
          await @site["templates"][layout](@loadContext(res))
        )
      else
        response.write(res["content"])
      response.end()
    )
    process.prependListener("exit", () =>
      server.close()
      @logger.log(
        "Hikaru stopped listening on http://#{ip}:#{port}#{@getPath()}..."
      )
      @unwatchAll()
    )
    @logger.log(
      "Hikaru is listening on http://#{ip}:#{port}#{@getPath()}..."
    )
    if ip isnt "localhost"
      server.listen(port, ip)
    else
      server.listen(port)
    @watchAll()

  handle: () =>
    @site = await @processor.process(@site)
    @site["files"] = await @generator.generate(@site)

  build: () =>
    await Promise.all((await @matchAll()).map(@loadFile))
    await @handle()
    @site["assets"].concat(@site["posts"])
    .concat(@site["pages"]).concat(@site["files"])
    .map(@saveFile)

  serve: (ip, port) =>
    await Promise.all((await @matchAll()).map(@loadFile))
    await @handle()
    @buildServerRoutes(
      @site["assets"].concat(@site["posts"])
      .concat(@site["pages"]).concat(@site["files"])
    )
    @listen(ip, port)

module.exports = Router
