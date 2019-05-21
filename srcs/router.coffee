fse = require("fs-extra")
path = require("path")
yaml = require("js-yaml")
http = require("http")
{URL} = require("url")
colors = require("colors/safe")
moment = require("moment-timezone")
chokidar = require("chokidar")
packageJSON = require("../package.json")
Promise = require("bluebird")
{Site, File, Category, Tag} = require("./types")
{
  matchFiles,
  getVersion,
  getPathFn,
  getURLFn,
  getContentType,
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

  readFile: (file) ->
    raw = await fse.readFile(path.join(file["srcDir"], file["srcPath"]))
    # Auto detect if a file is a binary file or a UTF-8 encoding text file.
    if raw.equals(Buffer.from(raw.toString("utf8"), "utf8"))
      raw = raw.toString("utf8")
    file["text"] = raw
    file["raw"] = raw
    return file

  writeFile: (file) ->
    if file["content"] isnt file["raw"]
      return fse.outputFile(
        path.join(file["docDir"], file["docPath"]), file["content"]
      )
    return fse.copy(
      path.join(file["srcDir"], file["srcPath"]),
      path.join(file["docDir"], file["docPath"])
    )

  loadFile: (file) =>
    @logger.debug("Hikaru is reading `#{colors.cyan(
      path.join(file["srcDir"], file["srcPath"])
    )}`...")
    file = await @readFile(file)
    if file["srcDir"] is @site["siteConfig"]["themeSrcDir"]
      file = await @renderer.render(file)
      if path.dirname(file["srcPath"]) isnt "."
        file["type"] = "asset"
        @site.put("assets", file)
      else
        file["type"] = "template"
        @site["templates"][path.basename(
          file["srcPath"], path.extname(file["srcPath"])
        )] = file
    else if file["srcDir"] is @site["siteConfig"]["srcDir"]
      file = parseFrontMatter(file)
      file = await @renderer.render(file)
      if file["text"] isnt file["raw"]
        if file["layout"] is "post"
          file["type"] = "post"
          @site.put("posts", file)
        else
          file["layout"] = file["layout"] or "page"
          file["type"] = "page"
          @site.put("pages", file)
      else
        file["type"] = "asset"
        @site.put("assets", file)
    return file

  saveFile: (file) =>
    @logger.debug("Hikaru is writing `#{colors.cyan(
      path.join(file["docDir"], file["docPath"])
    )}`...")
    return @writeFile(file)

  processFile: (f) =>
    lang = f["language"] or @site["siteConfig"]["language"]
    if lang not of @translator.list()
      try
        language = yaml.safeLoad(fse.readFileSync(path.join(
          @site["siteConfig"]["themeDir"],
          "languages",
          "#{lang}.yml"
        )))
        @translator.register(lang, language)
      catch err
        if err["code"] is "ENOENT"
          @logger.warn(
            "Hikaru cannot find `#{lang}` language file in your theme."
          )
    fs = await @processor.process(f, @site["posts"], {
      "site": @site.raw(),
      "siteConfig": @site["siteConfig"],
      "themeConfig": @site["themeConfig"],
      "moment": moment,
      "getVersion": getVersion,
      "getURL": @getURL,
      "getPath": @getPath,
      "isCurrentPath": isCurrentPathFn(
        @site["siteConfig"]["rootDir"], f["docPath"]
      ),
      "__": @translator.getTranslateFn(lang)
    })
    if fs not instanceof Array
      return [fs]
    return fs

  processPosts: () =>
    @site["posts"].sort((a, b) ->
      return -(a["date"] - b["date"])
    )
    processed = []
    for ps in @site["posts"]
      ps = await @processFile(ps)
      processed = processed.concat(ps)
    @site["posts"] = processed
    for i in [0...@site["posts"].length]
      if i > 0
        @site["posts"][i]["next"] = @site["posts"][i - 1]
      if i < @site["posts"].length - 1
        @site["posts"][i]["prev"] = @site["posts"][i + 1]

  processPages: () =>
    for ps in @site["pages"]
      ps = await @processFile(ps)
      for p in ps
        @site.put("pages", p)

  saveAssets: () =>
    return @site["assets"].map((asset) =>
      @saveFile(asset)
      return asset
    )

  savePosts: () =>
    return @site["posts"].map((p) =>
      p["content"] = await @site["templates"][p["layout"]]["content"](p)
      @saveFile(p)
      return p
    )

  savePages: () =>
    return @site["pages"].map((p) =>
      if p["layout"] not of @site["templates"]
        p["layout"] = "page"
      p["content"] = await @site["templates"][p["layout"]]["content"](p)
      @saveFile(p)
      return p
    )

  saveFiles: () =>
    return @site["files"].map((file) =>
      @saveFile(file)
      return file
    )

  buildServerRoutes: () =>
    @_ = {}
    for f in @site["assets"].concat(@site["posts"])
    .concat(@site["pages"]).concat(@site["files"])
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
    @site["pages"] = @sourcePages
    while (e = @watchedEvents.shift())?
      file = new File(@site["siteConfig"]["docDir"], e["srcDir"], e["srcPath"])
      if e["type"] is "unlink"
        for key in ["assets", "pages", "posts"]
          if @site.del(key, file)?
            break
      else
        file = await @loadFile(file)
        # Templates or assets have relations. Need to reload all of them.
        if file["type"] is "template"
          for k, v of @site["templates"]
            @site["templates"][k] = await @renderer.render(v)
        else if file["type"] is "asset"
          @site["assets"] = await Promise.all(@site["assets"].map((file) =>
            return @renderer.render(file)
          ))
    @sourcePages = [@site["pages"]...]
    @site = await @generator.generate("beforeProcessing", @site)
    await @processPosts()
    await @processPages()
    @site = await @generator.generate("afterProcessing", @site)
    @buildServerRoutes()
    @handling = false

  listen: (ip, port) =>
    server = http.createServer((request, response) =>
      if request["url"] not of @_
        @logger.log("404: #{request["url"]}")
        res = @_[@getPath("404.html")]
        if not res?
          res = {
            "content": """
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
                  <p>Hikaru v#{packageJSON["version"]}</p>
                </body>
              </html>
            """,
            "docPath": @getPath("404.html")
          }
        response.writeHead(404, {
          "Content-Type": getContentType(res["docPath"])
        })
      else
        @logger.log("200: #{request["url"]}")
        res = @_[request["url"]]
        response.writeHead(200, {
          "Content-Type": getContentType(res["docPath"])
        })
      if res["layout"]?
        if res["layout"] not of @site["templates"]
          res["layout"] = "page"
        response.write(
          await @site["templates"][res["layout"]]["content"](res)
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

  build: () =>
    allFiles = (await matchFiles(path.join("**", "*"), {
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
    await Promise.all(allFiles.map(@loadFile))
    @saveAssets()
    @site = await @generator.generate("beforeProcessing", @site)
    await @processPosts()
    await @processPages()
    @site = await @generator.generate("afterProcessing", @site)
    @savePosts()
    @savePages()
    @saveFiles()

  serve: (ip, port) =>
    allFiles = (await matchFiles(path.join("**", "*"), {
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
    await Promise.all(allFiles.map(@loadFile))
    @sourcePages = [@site["pages"]...]
    @site = await @generator.generate("beforeProcessing", @site)
    await @processPosts()
    await @processPages()
    @site = await @generator.generate("afterProcessing", @site)
    @buildServerRoutes()
    @listen(ip, port)

module.exports = Router
