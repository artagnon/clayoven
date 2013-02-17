# clayoven

Modern website generator with a traditional design. Generates html
files from a git repository; files are written in claytext.  Pages can
optionally be posted via email.

## Installation

Get the gem

    gem install clayoven

clayoven depends on Git, Ruby 1.9.3 and [Slim](http://slim-lang.com).

## Usage

* Run `clayoven` on your website's repository to generate HTML files.
* Run `clayoven httpd` to preview your website locally.
* Run `clayoven imapd` to start a daemon which will poll for emails.

## Repository format

There are two kinds of pages: index pages and content pages.  Index
pages are toplevel pages and (optionally) contain links to
corresponding content pages.  To specify which pages should go under
which "topic" (or index), content page filenames must look like
`<topic>:<permalink>`.  Topic page filenames must look like
`<topic>.index`.  A special index page called `index` will serve as
the homepage.  Additionally, the repository should contain a
`design/template.slim`.

Content pages are sorted based on the timestamp of the commit that
first introduced the file, reverse-chronologically.  This means that
updating a page (and checking in the changes) will not break the sort
order.

## Using slim and claytext

claytext is the markup engine that processes all your files, and
passes structured information to the slim template.  However, no
special effort is required to mark up the text that you write.  The
first line of file should contain the title, followed by the body
peppered with [\d+] markers referring to links in the footer.  The
footer should contain "[\d+]: \<link\>" lines, which will be turned
into clickable links.  For a full example, see
[artagnon.com/claytext](http://artagnon.com/claytext).


The simplest possible slim template that will work with clayoven is:

    doctype html
    html
      head
        title #{permalink}
      body
        h1 #{title}
	pre #{body}

However, this does not make use of the structured information that
claytext offers.  For a full example, look at the
[template](https://github.com/artagnon/artagnon.com/blob/master/design/template.slim)
that artagnon.com uses.

## Contributing

Open issues and send pull requests on GitHub.  You can optionally
email the author your patches, if you prefer that.
