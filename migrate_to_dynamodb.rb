#!/usr/bin/env ruby
# -*- encoding: utf-8; -*-

$: << File.dirname(__FILE__)

require 'uri'
require 'yaml'

require 'rubygems'
require 'bundler/setup'
require 'mysql2'
require 'aws-sdk-dynamodb'

require 'credentials.rb'

COLUMNS = %w(id server board thread date creator title last_checked)
ROWS_PER_PAGE = 25

SQL_CHECK = sprintf("SELECT %s " +
                    "FROM daily_hanihani " +
                    "WHERE board = ? AND thread = ? LIMIT 1",
                    COLUMNS.join(","))

client = Aws::DynamoDB::Client.new(region: 'ap-northeast-1')

mysql = Mysql2::Client.new(host: MYSQL_HOST, username: MYSQL_USER, password: MYSQL_PASS, database: MYSQL_DB)
mysql.query("SET CHARACTER SET utf8")
mysql.query("SET NAMES utf8")
stmt_query = mysql.prepare(sprintf("SELECT %s FROM daily_hanihani ORDER BY date ASC LIMIT ?, ?", COLUMNS.join(',')))
begin
  offset = 0
  loop do
    rows = stmt_query.execute(offset, ROWS_PER_PAGE)
    offset += rows.count

    p [offset, rows.count]

    batch_insert_items = []
    
    rows.each do |row|
      batch_insert_items << {
        put_request: {
          item: {
            'url' => "http://%s.2ch.net/test/read.cgi/%s/%s/" % [row['server'], row['board'], row['thread']],
            'date' => row['date'].strftime('%Y-%m-%d %H:%M:%S'),
            'creator' => row['creator'],
            'title' => row['title'],
            'last_checked' => row['last_checked'].strftime('%Y-%m-%d %H:%M:%S')
          }
        }
      }
#      p row
    end

    client.batch_write_item({
                              request_items: {
                                'daily_hanihani' => batch_insert_items
                              }
                            })    
    
    break if rows.count < ROWS_PER_PAGE
  end
ensure
  stmt_query.close()
  mysql.close()
end
