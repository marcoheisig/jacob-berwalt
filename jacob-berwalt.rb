#! /usr/bin/env ruby
# coding: utf-8

require "open-uri"
require "net/http"

LaTeX_Packages = ["[utf8]{inputenc}",
                  "[T1]{fontenc}",
                  "{amsmath}",
                  "[usenames,dvipsnames,svgnames,table]{xcolor}",
                  "{amssymb}",
                  "{hyperref}"]

LaTeX_Headings = ["section",
                  "subsection",
                  "subsubsection",
                  "paragraph",
                  "subparagraph"]

# Regex for sitemap processing
Sitemap_Section = /^\*(?<section>.+)$/
Sitemap_Book    = /^==(?<book>[^=]+)== *$/
Sitemap_Chapter = /^===(?<chapter>[^=]+)=== *$/
Link            = /\[\[(?<link>[^|]+?)\|(?<name>[^|]+?)\]\]/
Section_Delim   = /^(=+.*=+)/
Section_Subnode = /^(?<level>=+) *(?<name>.*) *\k<level>/
Block           = /{{(?<what>[^|]+?)\|(<(?<tag>.+?)>)?(?<body>.+?)(?(<tag>)<\/\k<tag>>)}}/m
Tag_Block       = /<(?<tag>[^ ]+)(?<options>[^>]*)>(?<body>.+?)<\/\k<tag>>/m
TeX_Environment = /\\begin *?{(?<env>.+?)}(?<texbody>.+)\\end *?{\k<env>}/m
List_Blog       = /\{\{#invoke:Liste\|erzeugeListe\s+\|type=(?<type>\w+)\s+\|inline=(?<inline>\w+)\s+(?<inside>.*?)\}\}/m
List_Item       = /\|item[\d+]=/
Pipe_Block      = /{\| *?class *?= *?"(?<what>.*?)"(?<body>.+?)\|}/m
Invoke_Block    = /\{\{#invoke:.*?\}\}/m
Def_Block       = /\{\{:Mathe für Nicht-Freaks: Vorlage:Definition\s+\|titel=(?<title>[^\|]+)\s+\|definition=(?<inside>.+?)\}\}/m
Theorem_Block   = /\{\{:Mathe für Nicht-Freaks: Vorlage:Satz\s+\|titel=(?<title>[^\|]+)\s+\|satz=(?<theorem>.+?)\|beweis=(?<proof>.+?)\}\}/m

# String constants
Wikibook = 'Mathe für Nicht-Freaks'
Sitemap  = ': Sitemap'
Base_Url = 'https://de.wikibooks.org/w/index.php'

class String
  def formulas_to_tex!()
    # deal with {{ ... | ... }} blocks
    self.gsub!(Block) do |match|
      what = Regexp.last_match['what']
      tag = Regexp.last_match['tag']
      body =  Regexp.last_match['body']
      if what[/^Formel/]
        if TeX_Environment =~ body
          env = Regexp.last_match['env']
          texbody =  Regexp.last_match['texbody']
          env = "align*" if env and env[/align/]
          result = "\n\\begin{#{env}}"
          result << texbody
          result << "\\end{#{env}}\n"
        end
      else
        match
      end
    end
  end
end

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
    @children.push( child )
  end

  def update_content()
    # lazy download only once
    return nil unless @link and not @body
    content = fetch(@link)

    # parse the text -> array of sections with content
    subtree = []
    content.split(Section_Delim).each do |elem|
      if subtree.empty? and not (Section_Subnode =~ elem)
        @body = elem
        next
      end
      if Section_Subnode =~ elem
        level = Regexp.last_match('level')
        name  = Regexp.last_match('name')
        name.gsub!(/\{\{.*\}\}/, '')
        subtree.push([level.length, name])
      else
        subtree[-1].push(elem)
      end
    end

    # built the tree
    return if subtree.empty?
    top_level = subtree[0][0]
    subtree.each do |child|
      current_node = self
      level = child[0]
      title = child[1]
      body  = child[2]
      while level > top_level do
        level -= 1
        current_node = current_node.children[-1]
      end
      puts @title unless current_node
      current_node.add_child(BookNode.new(title: title, body: body))
    end
  end

  def to_s()
    result = "#<BookNode"
    result << " title: " + @title if @title
    result << " link: " + @link if @link
    result << " body: " + @body[0..10] + "..." if @body
    result << ">"
  end

  def to_latex(level = 0)
    result = "\n\\#{LaTeX_Headings[level]}{#{@title}}\n"
    if @body
      latex = String.new(self.body)
      latex.formulas_to_tex!

      # convert <FOO>...</FOO> environments to plain LaTeX
      latex.gsub!(Tag_Block) do |s|
        tag = Regexp.last_match['tag']
        options = Regexp.last_match['options']
        body =  Regexp.last_match['body']
        if tag[/^math/]
          "$#{body}$"
        elsif tag[/^dfn/]
          if options[/title="(.*)"/]
            "\\emph{#{$1}}"
          else
            "\\emph{#{body}}"
          end
        else
          STDERR.print "A #{tag} block has been ignored.\n"
          ""
        end
      end

      # handle [[ ... | ... ]] links
      latex.gsub!(Link) do |s|
        link = Regexp.last_match['link']
        name = Regexp.last_match['name']
        name
      end

      # convert '''' to \textit{}
      latex.gsub!(/(?<b>[^'])''(?<word>[^']+)''(?<a>[^'])/) do |s|
        Regexp.last_match["b"] +
          '\textit{' + Regexp.last_match["word"] + '}' +
          Regexp.last_match["a"]
      end

      # convert '''''' to \textbf{}
      latex.gsub!(/(?<b>[^'])'''(?<word>[^']+)'''(?<a>[^'])/) do |s|
        Regexp.last_match["b"] +
          '\textbf{' + Regexp.last_match["word"] + '}' +
          Regexp.last_match["a"]
      end

      # parse itemize/enumerate
      item_stack = []
      new_latex = ''
      latex.lines.each do |line|
        if /^ *(?<item>[\*#]+)(?<rest>.*)/ =~ line
          if not item_stack.empty? and item.length == item_stack[-1].length
            new_latex += '\item ' + rest + "\n"
          elsif not item_stack.empty? and item.length <= item_stack[-1].length
            new_latex += '\item ' + rest + "\n"
            old_item = item_stack.pop
            if old_item =~ /^#+$/
              new_latex += "\\end{enumerate}\n"
            else
              new_latex += "\\end{itemize}\n"
            end
          else
            item_stack.push item
            if item =~ /^#+$/
              new_latex += "\\begin{enumerate}\n"
            else
              new_latex += "\\begin{itemize}\n"
            end
            new_latex += '\item ' + rest + "\n"
          end
        else
          old_item = item_stack.pop
          if old_item
            if old_item =~ /^#+$/
              new_latex += "\\end{enumerate}\n"
            else
              new_latex += "\\end{itemize}\n"
            end
          end
          new_latex += line
        end
      end
      latex = new_latex

      # translate mediawiki lists
      latex.gsub!(List_Blog) do |s|
        if Regexp.last_match["type"] == "ol"
          "\\begin{enumerate}\n" +
            Regexp.last_match["inside"] +
            "\\end{enumerate}\n"
        else
          "\\begin{itemize}\n" +
            Regexp.last_match["inside"] +
            "\\end{itemize}\n"
        end
      end
      latex.gsub!(List_Item) { |s| '\item' }

      # translate definitions
      latex.gsub!(Def_Block) do |s|
        title = Regexp.last_match["title"]
        inside = Regexp.last_match["inside"]
        "\\begin{definition}[#{title.strip}]\n#{inside}\n\\end{definition}\n"
      end

      # translate theorems
      latex.gsub!(Theorem_Block) do |s|
        title = Regexp.last_match["title"]
        theorem = Regexp.last_match["theorem"]
        proof = Regexp.last_match["proof"]
        "\\begin{theorem}[#{title.strip}]\n#{theorem}\n\\end{theorem}\n" +
          "\\begin{proof}\n#{proof}\n\\end{proof}\n"
      end

      # handle {| class="..." ... |} blocks
      latex.gsub!(Pipe_Block) do |s|
        what = Regexp.last_match['what']
        body = Regexp.last_match['body']
        case what
        when "wikitable"
          "" # TODO
        else
          s
        end
      end

      latex.formulas_to_tex!
      # delete all remaining blocks
      latex.gsub!(Block) do |s|
        what = Regexp.last_match['what']
        tag = Regexp.last_match['tag']
        body =  Regexp.last_match['body']
        STDERR.print "A #{what.strip} clause has been ignored.\n"
      end

      result << "\n" << latex << "\n\n"
    end
    self.children.each{|c| result << c.to_latex(level + 1)}
    result
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

  def to_latex()
    result = ["\\documentclass[11pt]{article}" ]
    LaTeX_Packages.each{|p| result << "\\usepackage#{p}"}
    result << "\\def \\N {\\mathbb{N}}"
    result << "\\def \\R {\\mathbb{R}}"
    result << "\\def \\Z {\\mathbb{Z}}"
    result << "\\def \\C {\\mathbb{Z}}"
    result << "\\def \\Q {\\mathbb{Q}}"
    result << "\\title{#{self.title}}"
    result << "\\begin{document}"
    result << "\\maketitle"
    result << "\\setcounter{tocdepth}{#{@tocdepth}}"
    result << "\\tableofcontents"
    result << "\\newpage"

    self.children.each{|c| result << c.to_latex}
    result << "\\end{document}"
    result.join("\n")
  end
end

def fetch( item )
  base = Base_Url
  what = URI.escape(item, /[^a-zA-Z\d\-._~!$&\'()*+,;=:@\/]/)
  url = URI( base + '?title=' + what + '&action=raw' )
  Net::HTTP.get( url ).force_encoding("UTF-8")
end

def expand_link(item)
  if Link =~ item
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
      name, link = expand_link(section)
      books[-1].add_section(title: name, link: link)
    elsif Sitemap_Book =~ line
      book = Regexp.last_match["book"]
      name, link = expand_link(book)
      books.push Book.new(name, 2)
    elsif Sitemap_Chapter =~ line
      chapter = Regexp.last_match["chapter"]
      name, link = expand_link(chapter)
      books[-1].add_chapter(title: name)
    end
  end
  books
end

books = wikipage_to_books(Wikibook + Sitemap)
grundlagen = books[0]
analysis1 = books[1]
lineare_algebra = books[2]

puts lineare_algebra.to_latex
