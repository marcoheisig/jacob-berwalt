#! /usr/bin/env ruby
# coding: utf-8

require "net/http"

sitemap_url = URI.parse('https://de.wikibooks.org/w/index.php?title=Mathe_f%C3%BCr_Nicht-Freaks:_Sitemap&action=raw')

def fetch(uri_str, limit = 10)
  raise 'HTTP redirect too deep' if limit == 0

  puts uri_str
  url = URI.parse(uri_str)
  req = Net::HTTP::Get.new(url.path)
  response = Net::HTTP.start(url.host, url.port) { |http| http.request(req) }
  case response
  when Net::HTTPSuccess     then response
  when Net::HTTPRedirection then fetch(response['location'], limit - 1)
  else
    response.error!
  end
end

puts Net::HTTP.get(sitemap_url)
