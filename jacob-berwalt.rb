#! /usr/bin/env ruby
# coding: utf-8

require "open-uri"
require "net/http"

# Regex for sitemap processing
Sitemap_Section = /^\* +(?<section>.*)/
Sitemap_Book    = /^== +(?<book>.*) +==/
Sitemap_Chapter = /^=== +(?<chapter>.*) +===/
Sitemap_Link    = /\[\[(?<link>[^|]*)\|(?<name>[^|]*)\]\]/

# String constants
Wikibook = 'Mathe für Nicht-Freaks'
Sitemap  = ': Sitemap'
Base_Url = 'https://de.wikibooks.org/w/index.php'

class Book
  def initialize(title, tocdepth = 2)
    @title = title
    @tocdepth = tocdepth
    @tree = [title, "", []]
  end

  def add_node(title, body, level)
    tree = @tree
    for _ in 1..level do
      tree = tree[2].last
    end
    tree[2].push [title, body, []]
    self
  end

  def add_chapter(title, body)
    self.add_node(title, body, 0)
  end

  def add_section(title, body)
    self.add_node(title, body, 1)
  end

  def to_s()
    "#<Book " + @tree.to_s + ">"
  end

  def toc()
    lines = ["Table of contents"]
    tocnum = []

    tocgen = lambda {|tree|
      lines.push tocnum.join(".") + " " + tree[0]
      tocnum.push(1)
      tree[2].each {|child|
        tocgen.call(child)
        tocnum[-1] += 1
      }
      tocnum.pop()
    }

    tocgen.call(@tree)
    lines.join("\n")
  end

  def to_tex()
    # TODO
  end
end

def fetch( item )
  base = Base_Url
  what = URI.escape(item, /[^a-zA-Z\d\-._~!$&\'()*+,;=:@\/]/)
  url = URI( base + '?title=' + what + '&action=raw' )
  Net::HTTP.get( url ).force_encoding("UTF-8")
end

def expand_link(item)
  if Sitemap_Link =~ item
    link = Regexp.last_match['link']
    name = Regexp.last_match['name']
    return name, link
  else
    return item, ''
  end
end


# A crude heuristic to turn a wikibooks page to several TOC (table of
# contents) objects.
def wikipage_to_books( item )
  books = []
  fetch(item).lines.each do |line|
    if Sitemap_Section =~ line
      section = Regexp.last_match['section']
      name, body = expand_link(section)
      books[-1].add_section(name, body)
    elsif Sitemap_Book =~ line
      book = Regexp.last_match["book"]
      name, body = expand_link(book)
      books.push Book.new(name, 2)
    elsif Sitemap_Chapter =~ line
      chapter = Regexp.last_match["chapter"]
      name, body = expand_link(chapter)
      books[-1].add_chapter(name, body)
    end
  end
  books
end

#books = wikipage_to_books('title=Mathe für Nicht-Freaks: Sitemap')
# books.each { |book| book.to_tex }
puts Book.new("TITLE").add_chapter("Chapter 1", "foo").add_section("Section 1", "bla").add_chapter("Chapter 2", "bar")

books = wikipage_to_books(Wikibook + Sitemap)
books.each { |book| puts book.toc }

puts books
