#! /usr/bin/env ruby
# coding: utf-8

require "open-uri"
require "net/http"
require_relative "WikiBook"
require_relative "to_tex"

# Test tag flipping
puts ["<foo>", "if", "(|", "{{[[((<<"].collect{|s| s.flip}

# Download the book description
book = WikiBook.new(title: ARGV.first, base_url: ARGV.first)

# Until the translation is finished, we just print the TOC
puts book.subsection(ARGV).toc
