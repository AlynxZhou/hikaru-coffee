Site Config
===========

# TOC

- For Users
	- [Install](install.md)
	- [Init](init.md)
	- [Config](config.md)
	- [Write](write.md)
	- [Command](command.md)
	- [Deploy](deploy.md)

# Site info

## `title`

Your site title.

## `subtitle`

Your site subtitle.

## `description`

Your site description.

## `author`

Usually, this is your name or nickname.

## `email`

Your email.

## `language`

Your site's language, options are depends on your theme. Hikaru does **NOT** support multi-lingual site. In fact only few people can write their site in different languages totally, most people do part of translation and makes their site a mess. It's more convenient to create two site with different languages, then you can arrange them by yourself. Multi-lingual site makes theme harder to write.

Hikaru contains **NO** timezone settings, it use your system timezone.

# Dir config

## `baseURL`

Your site's base URL, like `https://example.com`

## `rootDir`

Your site's root dir, for example, if you want to put your site in `https://example.com/blog/`, you can set it to `/blog/`, or if you create different sites with different languages, you can set it to `/en/` or `/zh_CN/`. If you don't need those, set it to `/`.

## `srcDir`

Your site's src dir, you can move `srcs/` to another name and change this.

## `docDir`

Your site's doc dir, you can move `docs/` to another name and change this.

## `themeDir`

Your site's theme, this is a sub dir name under `themes/`, for example, you cloned `hikaru-theme-aria` to `themes/aria`, you need to set it to `aria`.

## `categoryDir`

Your site's category sub page, which is generated automatically by Hikaru (No source path), will be put in to this dir.

## `tagDir`

Your site's tag sub page, which is generated automatically by Hikaru (No source path), will be put in to this dir.

# Other options

## `perPage`

When paginating, how many posts in a single page.

## `skipRender`

A list for files that won't be rendered, for example:

```yaml
skipRender:
  - README.md
  - EXAMPLE.md
  - TOC.md
```

For different npm modules, you can set their options as their docs, and it will be passed when rendering.

Prev Page: [Install](install.md)

Next Page: [Write](write.md)
