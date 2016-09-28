#! /usr/bin/env ruby
# coding: utf-8

require "open-uri"
require "net/http"
require_relative "crawler"
require_relative "transpiler"


grundlagen, analysis, lag, *_ = wikipage_to_books(Wikibook + Sitemap)

puts lag.to_latex
