#! /usr/bin/env ruby
# coding: utf-8

require "net/http"

sitemap_url = URI.parse('https://de.wikibooks.org/w/index.php?title=Mathe_f%C3%BCr_Nicht-Freaks:_Sitemap&action=raw')

sitemap = Net::HTTP.get(sitemap_url)

puts sitemap.scan(/\[\[.*\]\]/)
