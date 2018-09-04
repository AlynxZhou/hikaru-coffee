fse = require("fs-extra")
fm = require("front-matter")
path = require("path")
glob = require("glob")

module.exports =
class Router
  constructor: (logger, renderer, generator, translator,
  srcDir, docDir, themeSrcDir) ->
    @logger = logger
    @renderer = renderer
    @generator = generator
    @translator = translator
    @srcDir = srcDir
    @docDir = docDir
    @themeSrcDir = themeSrcDir
    @templates = {}
    @pages = []
    @posts = []

  matchFiles: (pattern, options) ->
    return new Promise((resolve, reject) ->
      glob(pattern, options, (err, res) ->
        if err
          return reject(err)
        return resolve(res)
      )
    )

  readData: (srcDir, srcPath) =>
    @logger.debug("Hikaru is loading `#{srcPath}`...")
    return fse.readFile(path.join(srcDir, srcPath), "utf8").then((raw) ->
      return {
        "srcPath": srcPath,
        "text": raw,
        "raw": raw
      }
    )

  writeData: (srcDir, data) =>
    @logger.debug("Hikaru is saving `#{data["docPath"]}`...")
    if data["content"]?
      return fse.outputFile(path.join(@docDir, data["docPath"]),
      data["content"])
    return fse.copy(
      path.join(srcDir, data["srcPath"]),
      path.join(@docDir, data["docPath"])
    )

  routeThemeAssets: () =>
    @matchFiles(path.join("**", "*.*"),
    {"cwd": @themeSrcDir}).then((themeSrcs) =>
      themeSrcs.filter((srcPath) ->
        # Asset is in sub dir.
        return path.dirname(srcPath) isnt "."
      ).map((srcPath) =>
        return @readData(@themeSrcDir, srcPath).then((data) =>
          return @renderer.render(data, null)
        ).then((data) =>
          return @writeData(@themeSrcDir, data)
        )
      )
    )

  routeTemplates: () =>
    return @matchFiles("*.*", {"cwd": @themeSrcDir}).then((templates) =>
      return Promise.all(templates.map((srcPath) =>
        return @readData(@themeSrcDir, srcPath).then((data) =>
          @templates[path.basename(srcPath,
          path.extname(srcPath))] = @renderer.render(data, null)
        )
      ))
    )

  routeSrcs: () =>
    return @matchFiles(path.join("**", "*.*"), {"cwd": @srcDir}).then((srcs) =>
      renderedPromises = []
      for srcPath in srcs then do (srcPath) =>
        renderedPromises.push(@readData(@srcDir, srcPath).then((data) =>
          if typeof(data["raw"]) is "string"
            parsed = fm(data["raw"])
            data["text"] = parsed["body"]
            data = Object.assign(data, parsed["attributes"])
            data["date"] = new Date(data["date"])
            if data["text"] isnt data["raw"]
              return @renderer.render(data, null)
          @renderer.render(data, null).then((data) =>
            @writeData(@themeSrcDir, data)
          )
          return null
        ))
      return Promise.all(renderedPromises.filter((p) ->
        return p?
      ))
    )

  route: () =>
    @routeThemeAssets()
    @routeTemplates().then(() =>
      return @routeSrcs()
    ).then((renderedPages) =>
      for p in renderedPages
        if p["layout"] is "post"
          @posts.push(p)
        else
          @pages.push(p)
      # Posts.
      @posts.sort((a, b) ->
        return -(a["date"] - b["date"])
      )
      generatedPosts = []
      for post in @posts
        p = @generator.generate(post, null, {
          "Date": Date,
          "__": @translator.__,
          "_p": @translator._p,
          "hello": () -> return "Hello"
        })
        if p not instanceof Array
          generatedPosts.push(p)
        else
          generatedPosts = generatedPosts.concat(p)
      @posts = generatedPosts
      for i in [0...@posts.length]
        if i > 0
          @posts[i]["next"] = @posts[i - 1]
        if i < @posts.length - 1
          @posts[i]["prev"] = @posts[i + 1]
      # Pages.
      generatedPages = []
      for page in @pages
        p = @generator.generate(page, @posts, {
          "Date": Date,
          "__": @translator.__,
          "_p": @translator._p,
          "hello": () -> return "Hello"
        })
        if p not instanceof Array
          generatedPages.push(p)
        else
          generatedPages = generatedPages.concat(p)
      @pages = generatedPages
      # Generate search index.
      search = []
      all = @pages.concat(@posts)
      for p in all
        search.push({
          "title": p["title"],
          "url": path.posix.join(path.posix.sep, p["docPath"]),
          "content": p["text"]
        })
      @writeData(@srcPath, {
        "srcPath": "search.json",
        "docPath": "search.json",
        "content": JSON.stringify(search)
      })
      for page in @pages
        layout = page["layout"]
        if layout not of @templates
          layout = "page"
        page["content"] = await @templates[layout](page)
        @writeData(@srcDir, page)
      # Merge post and template last.
      for post in @posts
        layout = post["layout"]
        if layout not of @templates
          layout = "page"
        post["content"] = await @templates[layout](post)
        @writeData(@srcDir, post)
    )
