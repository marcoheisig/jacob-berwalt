# String constants
Wikibook = 'Mathe für Nicht-Freaks'
Sitemap  = ': Sitemap'
Base_Url = 'https://de.wikibooks.org/w/index.php'

# Regex for sitemap processing
Sitemap_Section = /^\*(?<section>.+)$/
Sitemap_Book    = /^==(?<book>[^=]+)== *$/
Sitemap_Chapter = /^===(?<chapter>[^=]+)=== *$/
Link            = /\[\[(?<link>[^|]+?)\|(?<name>[^|]+?)\]\]/

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
    @children.push(child)
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
          subtree.last.push(elem)
      end
    end

    # built the tree
    return if subtree.empty?
    top_level = subtree[0][0]
    subtree.each do |child|
      current_node = self
      level, title, body = child
      while level > top_level do
        level -= 1
        current_node = current_node.children.last
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
end

class Book
  def initialize(title, tocdepth = 2)
    @tocdepth = tocdepth
    @tree = BookNode.new(title: title)
  end

  def add_node(level, **rest)
    tree = @tree
    1..level.times do
      tree = tree.children.last
    end
    tree.add_child(BookNode.new(**rest))
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

    tocgen = lambda { |tree|
      lines.push tocnum.join(".").ljust(5) + " "  + tree.title
      tocnum.push(1)
      tree.children.each { |child|
        tocgen.call(child)
        tocnum.last += 1
      }
      tocnum.pop()
    }

    tocgen.call(@tree)
    lines.join("\n")
  end
end

def fetch(item)
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
def wikipage_to_books(item)
  books = []
  fetch(item).lines.each do |line|
    if Sitemap_Section =~ line
      section = Regexp.last_match['section']
      name, link = expand_link(section)
      books.last.add_section(title: name, link: link)
    elsif Sitemap_Book =~ line
      book = Regexp.last_match["book"]
      name, link = expand_link(book)
      books.push Book.new(name, 2)
    elsif Sitemap_Chapter =~ line
      chapter = Regexp.last_match["chapter"]
      name, link = expand_link(chapter)
      books.last.add_chapter(title: name)
    end
  end
  books
end

