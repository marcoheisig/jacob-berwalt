#! /usr/bin/env ruby
# coding: utf-8

require "open-uri"
require "net/http"

class TOC
  def initialize( headline, location, children )
    @headline = headline
    @location = location
    @children = children
  end

  def to_book()
    # TODO
  end
end

class Book
  # TODO

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
def wikipage_to_tocs( item )
  # TODO
  array = fetch(item).split(Sitemap_Booktitle)
end

tocs = wikipage_to_tocs('title=Mathe für Nicht-Freaks: Sitemap')
tocs.each { |toc| toc.to_book.to_tex }
