# clayoven
[![Code Climate](https://codeclimate.com/github/artagnon/clayoven.png)](https://codeclimate.com/github/artagnon/clayoven)

Modern website generator with a traditional design. Generates html
that faithfully represents the textual input, provided the input is
like an email I write to the git list.  This
[input](http://artagnon.com/hidden:claytext) produces this
[output](http://artagnon.com/claytext).

## Installation

The whole point of using clayoven is so you can hack on it: don't use
gems. Just clone, and put `bin/clayoven` in `$PATH`.

Depends on ruby 2.0+, git, and [slim](http://slim-lang.com).

## Usage

* Run `clayoven` on your website's repository to generate HTML files.
* Run `clayoven httpd` to preview your website locally.

## Pages

Every site needs a sidebar that allows the user to navigate through
various sections: these are called Topics.  Each topic has one Index
Page (named `<topic>.index`; `<topic>` is the permalink), and several
Content Pages (named `<topic>:<permalink>`) corresponding to it.
`index` is a special index page corresponding to the permalink `/`.
Additionally, every repository should contain a `design/template.slim`
to specify how to render content.

So, if you have these files:

    index
    blog.index
    blog:first
    blog:second
    colophon.index
    design/template.slim

clayoven automatically builds a sidebar with `index`, `blog` and `colophon`.
In the page `/blog`, there will be links to the posts `/first` and
`/second`.

The special "hidden" topic can be used to create content pages with no
corresponding index or sidebar entry.  This is useful for 404 pages,
for example.

Content pages are sorted based on the committer-timestamp of the
commit that first introduced the file, reverse-chronologically.  Index
pages are sorted chronologically.  Just don't check in multiple files
simultaneously.

## Configuration

On the first run, clayoven will create a `.clayoven/ignore` file in
your repository.  This is a gitignore-like file (but uses full regular
expressions) specifying which files clayoven should ignore.  Useful
for your site's `README.md` and drafts.

## Slim template

Look at the
[template](https://github.com/artagnon/artagnon.com/blob/master/design/template.slim)
that artagnon.com uses.

## Hacking

Fork and customize as you please.  To avoid regressions, just check
[this file](https://github.com/artagnon/artagnon.com/blob/master/hidden:claytext)
into your website repository (and update it as you add new features):
your testsuite is a clean `git diff`.

You may optionally contribute back changes if you think I will find it
useful.  Either use pull requests, or email me your patches.
