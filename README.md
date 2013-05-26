# clayoven
[![Code Climate](https://codeclimate.com/github/artagnon/clayoven.png)](https://codeclimate.com/github/artagnon/clayoven)

Modern website generator with a traditional design. Generates html
that faithfully represents the textual input, provided the input is
like an email I write to the git list.  This
[input](http://artagnon.com/hidden:claytext) produces this
[output](http://artagnon.com/claytext).

## Installation

Get the gem

    gem install clayoven

clayoven depends on Git, Ruby 1.9.3 and [Slim](http://slim-lang.com).

## Usage

* Run `clayoven` on your website's repository to generate HTML files.
* Run `clayoven httpd` to preview your website locally.

## Repository format

There are two kinds of pages: index pages and content pages.  Index
pages are toplevel pages and (optionally) contain links to
corresponding content pages.  To specify which pages should go under
which "topic" (or index), content page filenames must look like
`<topic>:<permalink>`.  Topic page filenames must look like
`<topic>.index`.  A special index page called `index` will serve as
the homepage.  Additionally, the repository should contain a
`design/template.slim`. `hidden` is a special topic that can be used
to publish a content page that are not listed in any index; example:
404 page.

Content pages are sorted based on the timestamp of the commit that
first introduced the file, reverse-chronologically.  This means that
updating a page (and checking in the changes) will not break the sort
order.  Index pages are sorted chronologically.

## Slim template

The simplest possible slim template that will work with clayoven is:

    doctype html
    html
      head
        title #{permalink}
      body
        h1 #{title}
	pre #{body}

However, this does not make use of the structured information that
clayoven offers.  For a full example, look at the
[template](https://github.com/artagnon/artagnon.com/blob/master/design/template.slim)
that artagnon.com uses.

## Contributing

Fork and customize as you please.  You may optionally contribute back
changes if you think I will find it useful.

Either use pull requests, or email me your patches.
