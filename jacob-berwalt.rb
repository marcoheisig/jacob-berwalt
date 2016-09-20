#! /usr/bin/env ruby
# coding: utf-8

require "open-uri"
require "net/http"

class Book
  def initialize(title, tocdepth = 2)
    @title = title
    @tocdepth = tocdepth
    @tree = [title, "", []]
  end

  def add_node(title, body, level)
    tree = @tree
    for i in 1..level do
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

  def to_tex()
    # TODO
  end
end

Sitemap_Booktitle = /==\W*\[\[(.*)\|(.*)\]\]\W*==/
Sitemap_Chapter = /===\W*(.*)\W*===/

def fetch( item )
  sitemap = 'https://de.wikibooks.org/w/index.php'
  what = URI.escape(item, /[^a-zA-Z\d\-._~!$&\'()*+,;=:@\/]/)
  url = URI( sitemap + '?' + what + '&action=raw' )
  Net::HTTP.get( url ).force_encoding("UTF-8")
end

# A crude heuristic to turn a wikibooks page to several TOC (table of
# contents) objects.
def wikipage_to_books( item )
  # TODO
  array = fetch(item).split(Sitemap_Booktitle)
end

#books = wikipage_to_books('title=Mathe für Nicht-Freaks: Sitemap')
# books.each { |book| book.to_tex }
puts Book.new("TITLE").add_chapter("Chapter 1", "foo").add_section("Section 1", "bla").add_chapter("Chapter 2", "bar")
