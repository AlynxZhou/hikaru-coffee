Extend
======

# TOC

- For Users
    - [Install](../user/install.md)
    - [Init](../user/init.md)
    - [Config](../user/config.md)
    - [Write](../user/write.md)
    - [Command](../user/command.md)
    - [Deploy](../user/deploy.md)
    - [Plugins and Scripts](../user/plugins-and-scripts.md)
- For Developers
    - [Lifecycle](../dev/lifecycle.md)
    - [Hikaru](../dev/hikaru.md)
    - [Types](../dev/types.md)
    - [Utils](../dev/utils.md)
    - [Extend](../dev/extend.md)
    - [Theme](../dev/theme.md)

Hikaru supports plugins and scripts, but not all part of Hikaru is designed for them. There are some parts that you can add your code.

# `Renderer`

`Renderer` is the first module called while building site. Each file will be rendered first, you can register new render function to it.

## `register(srcExt, docExt, fn)`

- `srcExt`: `String` or `String[]`
- `docExt`: `String`
- `fn`: `function (file, ctx)`
- Return type: `undefined`

`srcExt` and `docExt` are start with `.`. A file with `srcExt` extend name will be render and change to `docExt`. `Renderer` will call `fn` to render it, `file` is `Hikaru::types.File`. `fn` should return `Hikaru::types.File`.

# `Processor`

`Processor` is used to convert a file to a context that can be used by templates. In this time, you can change file content for different layout. Hikaru resolves links and image sources via it.

## `register(layout, fn)`

- `layout`: `String`
- `fn`: `function (p, posts, ctx)`
- Return type: `undefined`

`layout` should be one of `index`, `archives`, `tags`, `tag`, `categories`, `category`, `about`, `page`, `post` or other valid layouts. `fn` should return `Hikaru::types.File` and assign ctx into it, if you want attach posts, please assign `posts` to `p["posts"]`.

# `Generator`

`Generator` is used to generated some files or data that has no source file. For example, tags, categories and sitemap.

## `register(type, fn)`

- `type`: `String`
- `fn`: `function (site)`
- Return type: `undefined`

`type` should be one of `beforeProcessing` and `afterProcessing`. Typically, if you want create some data, use `beforeProcessing`, if you want create some page, use `afterProcessing`. Because some data are not ready when `beforeProcessing` is running. `site` is just `Hikaru::types.Site`, `fn` should return it too.

Prev Page: [Utils](utils.md)

Next Page: [Theme](theme.md)
