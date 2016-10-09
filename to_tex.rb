# coding: utf-8

# this file contains functions to convert Book objects and string
# containting MediaWiki markup to TeX

LaTeX_Packages = ["[utf8]{inputenc}",
                  "[T1]{fontenc}",
                  "{amsmath}",
                  "[usenames,dvipsnames,svgnames,table]{xcolor}",
                  "{amssymb}",
                  "{hyperref}",
                  "{amsthm}"]

LaTeX_Headings = ["section",
                  "subsection",
                  "subsubsection",
                  "paragraph",
                  "subparagraph"]

Section_Delim   = /^(=+.*=+)/
Section_Subnode = /^(?<level>=+) *(?<name>.*) *\k<level>/
Block           = /{{(?<what>[^|]+?)\|(<(?<tag>.+?)>)?(?<body>.+?)(?(<tag>)<\/\k<tag>>)}}/m
Formel          = /{{ *?Formel *?\|(<(?<tag>.+?)>)?(?<body>.+?)(?(<tag>)<\/\k<tag>>)}}/m
Tag_Block       = /<(?<tag>[^ ]+)(?<options>[^>]*)>(?<body>.+?)<\/\k<tag>>/m
TeX_Environment = /\\begin *?{(?<env>.+?)}(?<texbody>.+)\\end *?{\k<env>}/m
List_Block      = /{{#invoke:Liste\|erzeugeListe\s+\|type=(?<type>\w+)\s+\|inline=(?<inline>\w+)\s+(?<inside>.*)}}/m
List_Item       = /\|item[\d+]=/
Pipe_Block      = /{\| *?class *?= *?"(?<what>.*?)"(?<body>.+?)\|}/m
Invoke_Block    = /\{\{#invoke:.*?\}\}/m
Def_Block       = /\{\{:Mathe für Nicht-Freaks: Vorlage:Definition\s+\|titel=(?<title>[^\|]+)\s+\|definition=(?<inside>.+?)\}\}/m
Theorem_Block   = /\{\{:Mathe für Nicht-Freaks: Vorlage:Satz\s+(\|titel=(?<title>[^\|]+)\s+)?\|satz=(?<theorem>.+?)(\|erklärung=(?<explanation>.+?))?\|beweis=(?<proof>.+?)\}\}/m

class String
  def formulas_to_tex!()
    # deal with {{ ... | ... }} blocks
    self.gsub!(Formel) do |match|
      tag = Regexp.last_match['tag']
      body =  Regexp.last_match['body']
      if TeX_Environment =~ body
        env = Regexp.last_match['env']
        texbody =  Regexp.last_match['texbody']
        env = "align*" if env and env[/align/]
        result = "\n\\begin{#{env}}\n"
        result << texbody.strip
        result << "\n\\end{#{env}}\n"
      else
        result = "\\begin{align*}\n"
        result << body.strip
        result << "\n\\end{align*}"
      end
    end
  end
end

class BookNode
  def to_tex(level = 0)
    result = "\n\\#{LaTeX_Headings[level]}{#{@title}}\n"
    if @body
      latex = String.new(self.body)

      latex.formulas_to_tex!

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
          if not item_stack.empty? and item.length == item_stack.last.length
            new_latex += '\item ' + rest + "\n"
          elsif not item_stack.empty? and item.length <= item_stack.last.length
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
      latex.gsub!(List_Block) do |s|
        type = Regexp.last_match["type"]
        inside = Regexp.last_match["inside"]
        if type == "ol"
          "\\begin{enumerate}\n" + inside + "\\end{enumerate}\n"
        else
          "\\begin{itemize}\n" + inside + "\\end{itemize}\n"
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
        title = '[' + title.strip + ']' unless title.nil?
        explanation = Regexp.last_match["explanation"] or ''
        theorem = Regexp.last_match["theorem"]
        proof = Regexp.last_match["proof"]
        "\\begin{theorem}#{title}\n#{theorem}\n\\end{theorem}\n" +
          explanation.to_s +
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

      # delete all remaining blocks
      latex.gsub!(Block) do |s|
        what = Regexp.last_match['what']
        tag = Regexp.last_match['tag']
        body =  Regexp.last_match['body']
        STDERR.print "A #{what.strip} clause has been ignored.\n"
      end

      result << "\n" << latex << "\n\n"
    end
    self.children.each{ |c| result << c.to_tex(level + 1)}
    result
  end
end

class WikiBook
  def to_tex()
    result = ["\\documentclass[11pt]{article}" ]
    LaTeX_Packages.each{|p| result << "\\usepackage#{p}"}
    result << "\\def \\N {\\mathbb{N}}"
    result << "\\def \\R {\\mathbb{R}}"
    result << "\\def \\Z {\\mathbb{Z}}"
    result << "\\def \\C {\\mathbb{Z}}"
    result << "\\def \\Q {\\mathbb{Q}}"
    result << "\\theoremstyle{definition}"
    result << "\\newtheorem{definition}{Definition}"
    result << "\\theoremstyle{theorem}"
    result << "\\newtheorem{theorem}{Satz}"
    result << "\\title{#{self.title}}"
    result << "\\begin{document}"
    result << "\\maketitle"
    result << "\\setcounter{tocdepth}{#{@tocdepth}}"
    result << "\\tableofcontents"
    result << "\\newpage"

    self.children.each{|c| result << c.to_tex}
    result << "\\end{document}"
    result.join("\n")
  end
end

