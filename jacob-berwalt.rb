#! /usr/bin/env ruby
# coding: utf-8

require "open-uri"
require "net/http"
require_relative "Book"
require_relative "to_tex"


Wikibook = 'Mathe für Nicht-Freaks'
Sitemap  = ': Sitemap'

mfnf = WikiBook.new(Wikibook, Wikibook + Sitemap)

# puts lag.to_tex

puts ["<foo>", "if", "(|", "{{[[((<<"].collect{|s| s.flip}

# test of new crawler
def print_tree(tree, depth = 0)
  depth.times { print "  " }
  print tree, "\n"
  depth += 1
  tree.children.each { |subtree| print_tree(subtree, depth + 1) }
end

# print_tree(mfnf)
puts mfnf
