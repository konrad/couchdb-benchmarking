# -*- coding: utf-8 -*-
#
# About: This is tiny script to test CouchDB's disk space usage
# depending on the settings.
# 
# Copyright (c) 2010 Konrad Förstner <konrad@foerstner.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

require 'rubygems'
require "couchrest"

class Benchmark
  
  def initialize
    @db_name = 'benchmark'
    @R_path = "/usr/bin/R"
    couchurl ="http://127.0.0.1:5984"
    couch = CouchRest.new(couchurl)
    @db = couch.database(@db_name)
    @db.delete! rescue nil
    @db = couch.create_db(@db_name)
    @repetitions = 1200
  end

  def run_benchmark
    @db_sizes = []
    doc_id = @db.save_doc({
                           'an_attribute' => 'pepper chilli salt ginger',
                           'a_number' => 1,
                           'something' => 'a' * 1000})['id']
    @repetitions.times do
      @db.update_doc(doc_id) do |doc|
        doc['a_number'] += 1
        doc
      end
    end
  end

  def change_revision_limit(no_of_revisions)
    system("curl -X PUT -d '#{no_of_revisions}' http://localhost:5984/#{@db_name}/_revs_limit")
  end

  def generate_R_script(file_name)
    puts Dir.pwd
    x_axis = (1..@db_sizes.length).to_a.join(', ')
    y_axis = @db_sizes.join(', ')
    fh = File.open(file_name, 'w')
    fh.puts "x <- c(#{x_axis})"
    fh.puts "y <- c(#{y_axis})" 
    fh.puts "png('#{file_name}.png')"
    fh.puts "plot(x, y, xlab='Revision', ylab='DB size', type='b')"
    puts "Run 'R --file=#{Dir.pwd}/#{file_name}' to generate a plot."
    # TODO - Does not work properly:
    #system("#{@R_path} --file=#{Dir.pwd}/#{file_name}") 
  end

  def compact_db
    puts "Size before compaction: #{@db.info["disk_size"]}"
    system("curl -X POST http://localhost:5984/#{@db_name}/_compact")
    puts "Size after compaction: #{@db.info["disk_size"]}"
    @db_sizes << @db.info["disk_size"]
  end

end

puts "Run with the default number of revisions (= 1000)"
benchmark = Benchmark.new
benchmark.run_benchmark
benchmark.compact_db
benchmark.generate_R_script('CouchDB_Benchmark-default_revs_limit.R')

puts "---------------------------------"
puts "Run with number of revisions to 1"
benchmark = Benchmark.new
benchmark.change_revision_limit(1)
benchmark.run_benchmark
benchmark.compact_db
benchmark.generate_R_script('CouchDB_Benchmark-revs_limit_1.R')
