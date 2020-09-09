#!/usr/bin/env ruby
# -*- encoding: utf-8; -*-

$: << File.dirname(__FILE__)

require 'rss'
require 'net/http'
require 'http_cache.rb'
require 'cgi'
require 'uri'
require 'yaml'

require 'rubygems'
require 'bundler/setup'
require 'mysql2'
require 'grackle'
require 'nokogiri'

require 'credentials.rb'

URL = 'https://www.2nn.jp/rss/news4plus.rdf'
REGEXP_HANIHANI = /(ちょーはにはにちゃんｗ|HONEY MILK(　)?|ハニィみるく（17歳）)φ? ★/

COLUMNS = %w(id server board thread date creator title last_checked)

SQL_CHECK = sprintf("SELECT %s " +
                    "FROM daily_hanihani " +
                    "WHERE board = ? AND thread = ? LIMIT 1",
                    COLUMNS.join(","))
SQL_INSERT = sprintf("INSERT INTO daily_hanihani (%s) " +
                     "VALUES (NULL, ?, ?, ?, ?, ?, ?, NOW())",
                     COLUMNS.join(","))
SQL_UPDATE = "UPDATE daily_hanihani SET last_checked = NOW() " +
  "WHERE id = ? LIMIT 1"

def post_to_twitter(grackle, title, url)
  status = sprintf('%s %s', title, url)
  grackle.statuses.update! :status => status
end

mysql = Mysql2::Client.new(host: MYSQL_HOST, username: MYSQL_USER, password: MYSQL_PASS, database: MYSQL_DB)
mysql.query("SET CHARACTER SET utf8")
mysql.query("SET NAMES utf8")

stmt_check = mysql.prepare(SQL_CHECK)
stmt_insert = mysql.prepare(SQL_INSERT)
stmt_update = mysql.prepare(SQL_UPDATE)

Grackle::Transport.ca_cert_file = "/etc/ssl/certs/ca-certificates.crt"
grackle = Grackle::Client.new(:ssl => true, :auth => GRACKLE_OAUTH)

body = HTTPCache.get(URL)
if body then
  rss = RSS::Parser.parse(body, false)
  rss.items.each do |item|
    if REGEXP_HANIHANI =~ item.dc_creator then
      # eg: http://yutori7.2ch.net/test/read.cgi/news4plus/1259175497/

      doc = Nokogiri::HTML(item.description)
      uri = URI.parse(doc.xpath("//a/@href").first)
      server = uri.host.split(/[.]/).first
      _, _, _, board, thread = *uri.path.split(/\//)
      next unless (board && thread)
      row = stmt_check.execute(board, thread)
      if row.count > 0 then
        id = row.to_a.first["id"]
        printf("UPDATE[%d]: %s  http://%s.2ch.net/test/read.cgi/%s/%d/\n", id, item.title.to_s, server, board, thread)
        stmt_update.execute(id)
      else
        printf("INSERT: %s  http://%s.2ch.net/test/read.cgi/%s/%d/\n", item.title.to_s, server, board, thread)
        stmt_insert.execute(server, board, thread,
                            item.dc_date.strftime("%Y-%m-%d %H:%M:%S"),
                            item.dc_creator.to_s, item.title.to_s)
        post_to_twitter(grackle, item.title, item.link)
      end
    end
  end
end

stmt_update.close
stmt_insert.close
stmt_check.close
mysql.close

