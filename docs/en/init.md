Init Site
=========

# TOC

- For Users
	- [Install](install.md)
	- [Init](init.md)
	- [Config](config.md)
	- [Write](write.md)
	- [Command](command.md)
	- [Deploy](deploy.md)

# Init site

After installing Hikaru, you can use following command to setup a site directory:

```
$ hikaru i hikaru-site
$ cd hikaru-site
```

The directory looks like:

```plain
hikura-site/
    |- srcs/
    |- docs/
    |- themes/
    |- config.yml
```

# Install theme

Before rendering, you need a theme as a template.

## Clone theme

Using `hikaru-theme-aria` as example:

```
$ git clone https://github.com/AlynxZhou/hikaru-theme-aria.git themes/aria
```

Or if you want commit the whole site you can use submodule:

```
$ git submodule add https://github.com/AlynxZhou/hikaru-theme-aria.git themes/aria
```

## Edit config

```
$ $EDITOR config.yml
```

Set `themeDir` to `aria`

```yaml
themeDir: aria
```

Don't forget to config your theme as its README file.

# File info

## `config.yml`

This contains most site config.

## `srcs/`

This contains your site's source files.

## `docs/`

Your source files will be built to this directory.

## `themes/`

This contains your site's themes.

**Most of those dirs can be changed in `config.yml`.**

Prev Page: [Install](install.md)

Next Page: [Config](config.md)
