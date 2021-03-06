# coding: utf-8

# In the context of this program, a book is a tree of BookNodes. Each
# BookNode has a title, a list of child BookNodes and a body. The body is a
# string that may contain MediaWiki markup.
#
# It is also possible to initialize a BookNode using a link instead of a
# body. In this case the first access to body() or children() will trigger
# the loading and parsing of the specified URL, which may add body text and
# several new children.

class WikiBook
  attr_reader :title

  def initialize(title: "", base_url: "", tocdepth: 2, tree: nil)
    @tocdepth = tocdepth
    @tree = tree.nil? ? BookNode.new(title: title, content: base_url) : tree
  end

  def children()
    @tree.children
  end

  def subsection(path)
    # TODO add a custom exception and a way to handle it
    raise StandardError unless path.shift.to_s == @tree.title
    @tree.subsection(path)
  end

  def to_s()
    @tree.to_s
  end

  def toc()
    lines = []
    tocnum = []

    tocgen = lambda { |tree|
      lines.push tocnum.join(".").ljust(8) + " "  + tree.title
      tocnum.push(1)
      tree.children.each { |child|
        tocgen.call(child)
        tocnum[-1] += 1
      }
      tocnum.pop()
    }

    tocgen.call(@tree)
    lines.join("\n")
  end
end

# String constants
Base_Url = 'https://de.wikibooks.org/w/index.php'

class String
  def flip
    if self[/\s*<(.+)>\s*/]
      "</" + $1 + ">"
    else
      self.reverse.gsub(/[<{\(\[]/) {|c|
        case c
        when "<" then ">"
        when "{" then "}"
        when "(" then ")"
        when "[" then "]"
        end
      }
    end
  end
end

class BookNode
  # Regex for sitemap processing
  Hierarchy_Upper = /^ *(?<level>=+)(?<name>.+)\k<level> *$/
  Hierarchy_Lower = /^\* +\[\[(?<link>[^|]+?)\|(?<name>[^|]+?)\]\]/
  Heading         = /^ *(=+.+=+) *$/
  Hyperlink       = /\A\[\[(?<link>[^|]+?)\|(?<name>[^|]+?)\]\]\Z/

  attr_reader :title

  def initialize(title: "", content: "")
    @title = title
    @content = content
    @children = []
    @expanded = false
  end

  def content()
    update_content
    @content
  end

  def children()
    update_content
    @children
  end

  def add_child(child)
    @children.push(child)
  end

  def subsection(path)
    return WikiBook.new(tree: self) if path.empty?
    children.each do |child|
      if path.first == child.title
        return child.subsection(path.slice(1, path.length))
      end
    end
    # TODO add a custom exception and a way to handle it
    raise StandardError
  end

  def splittable?
    @content.lines.reduce(true) do |accu, line|
      # TODO this is half-ass because of sitemap comments starting with `:`
      accu and (line.strip == "" or Hierarchy_Lower =~ line or line[0] == ":")
    end
  end

  def decomposable?
    @content.lines.reduce(false) do |accu, line|
      accu or (Hierarchy_Upper =~ line)
    end
  end

  def update_content()
    # only execute once
    return if @expanded
    @expanded = true

    # TODO this site is broken, but it's in "Buchanfänge"
    return if @title == "Der dreidimensionale euklidische Koordinatenraum"
    # TODO avoid endless recursion
    return if @title == "Sitemap: Übersicht aller Kapitel"

    # Check links first
    if Hyperlink =~ @content
      link = Regexp.last_match("link")
      @content = fetch(link)
    end

    if splittable?
      @content.lines.each do |line|
        next unless Hierarchy_Lower =~ line
        link = Regexp.last_match("link")
        name = Regexp.last_match("name")
        hyperlink = make_hyperlink(name, link)
        add_child(BookNode.new(title: name, content: hyperlink))
      end
      @content = ""

    elsif decomposable?
      # get highest hierarchy of headings
      headings = @content.lines.select { |line| Hierarchy_Upper =~ line }
      hierarchies = headings.map do |heading|
        0 if not (Hierarchy_Upper =~ heading)
        Regexp.last_match("level").length
      end
      top_level = hierarchies.min
      raise StandardError if top_level == 0

      # split text according to headings of that hierarchy
      new_body = ""
      subtree  = []
      @content.split(Heading).each do |elem|
        if subtree.empty? and not (Hierarchy_Upper =~ elem)
          new_body = elem
          next
        end
        if Hierarchy_Upper =~ elem
          level = Regexp.last_match("level")
          if level.length != top_level
            subtree.last.last.concat(elem)
            next
          end
          name = Regexp.last_match("name")
          subtree.push([name, ""])
        else
          subtree.last.last.concat(elem)
        end
      end

      # add the chunks as children and update the body
      @content = new_body
      subtree.each do |child|
        name, contents = child
        add_child(BookNode.new(title: strip_hyperlink(name.strip),
                               content: contents))
      end
    end
  end

  def to_s()
    update_content
    result = "#<BookNode"
    result << " title: " + @title if @title
    result << " content: " + @content[0..10] + "..."
    result << ">"
  end
end

def fetch(item)
  base = Base_Url
  what = URI.escape(item, /[^a-zA-Z\d\-._~!$&\'()*+,;=:@\/]/)
  url = URI(base + '?title=' + what + '&action=raw')
  Net::HTTP.get(url).force_encoding("UTF-8")
end

def strip_hyperlink(item)
  BookNode::Hyperlink =~ item ? Regexp.last_match["name"] : item
end

def make_hyperlink(name, link)
  "[[#{link}|#{name}]]"
end

