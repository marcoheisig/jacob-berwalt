#! /usr/bin/env ruby
# coding: utf-8

require "open-uri"
require "net/http"
require_relative "Book"
require_relative "to_tex"


Wikibook = 'Mathe für Nicht-Freaks'
Sitemap  = ': Sitemap'

grundlagen, analysis, lag, *_ = wikipage_to_books(Wikibook + Sitemap)

# puts lag.to_tex

puts ["<foo>", "if", "(|", "{{[[((<<"].collect{|s| s.flip}
