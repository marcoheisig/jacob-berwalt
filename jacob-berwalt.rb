#! /usr/bin/env ruby
# coding: utf-8

require "open-uri"
require "net/http"

LaTeX_Packages = ["[utf8]{inputenc}",
                  "[T1]{fontenc}",
                  "{amsmath}",
                  "{amssymb}",
                  "{hyperref}"]

# Regex for sitemap processing
Sitemap_Section = /^\* +(?<section>.*)/
Sitemap_Book    = /^== +(?<book>.*) +==/
Sitemap_Chapter = /^=== +(?<chapter>.*) +===/
Sitemap_Link    = /\[\[(?<link>[^|]*)\|(?<name>[^|]*)\]\]/

# String constants
Wikibook = 'Mathe für Nicht-Freaks'
Sitemap  = ': Sitemap'
Base_Url = 'https://de.wikibooks.org/w/index.php'

class BookNode
  def initialize(title: "", body: nil, link: nil)
    @title = title
    @body = body
    @link = link
    @children = []
  end

  def title()
    @title
  end

  def body()
    update_content
    @body
  end

  def children()
    update_content
    @children
  end

  def add_child(child)
    children.push( child )
  end

  def update_content()
    return nil unless @link and not @body
    # TODO
  end

  def to_s()
    result = "#<BookNode"
    result << " title: " + @title if @title
    result << " link: " + @link if @link
    result << " body: " + @body[0..10] + "..." if @body
    result << ">"
  end
end

class Book
  def initialize(title, tocdepth = 2)
    @tocdepth = tocdepth
    @tree = BookNode.new(title: title)
  end

  def add_node(level, **rest)
    tree = @tree
    for _ in 1..level do
      tree = tree.children.last
    end
    tree.add_child( BookNode.new(**rest) )
    self
  end

  def children()
    @tree.children
  end

  def add_chapter(**rest)
    self.add_node(0, **rest)
  end

  def add_section(**rest)
    self.add_node(1, **rest)
  end

  def title()
    @tree.title()
  end

  def to_s()
    self.toc
  end

  def toc()
    lines = []
    tocnum = []

    tocgen = lambda {|tree|
      lines.push tocnum.join(".").ljust(5) + " "  + tree.title
      tocnum.push(1)
      tree.children.each {|child|
        tocgen.call(child)
        tocnum[-1] += 1
      }
      tocnum.pop()
    }

    tocgen.call(@tree)
    lines.join("\n")
  end

  def to_tex()
    title = self.title
    filename = title + ".tex"
    File.open(filename, 'w') {|file|
      file.write("\\documentclass[11pt]{book}\n");
      LaTeX_Packages.each{|package| file.write("\\usepackage#{package}\n")}
      file.write("\\title{#{title}}\n");
      file.write("\\begin{document}\n")
      file.write("\\maketitle\n")
      file.write("\\end{document}\n")
    }
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
testbook = Book.new("TITLE").add_chapter(title: "Chapter 1").add_section(title: "Section 1").add_chapter(title: "Chapter 2")
# testbook.to_tex
puts testbook.children
# books = wikipage_to_books(Wikibook + Sitemap)
# books.each { |book| puts book.toc }

