# frozen_string_literal: true

#get path to input file (or pipe) from ARGV.shift

require 'csv'
require 'Date'
require 'isbn'

def parse_isbns(isbns_str, row)
  #e.g. 9781407333977 (ebook); 9781407303697 (paperback)
  isbns_formats = isbns_str.split('; ')
  n = 1
  isbns_formats.each {|i|
    isbn = ''
    i.match(/^(\d+)/) { isbn = $1}
    if ISBN.valid?(isbn)
      isbn = ISBN.thirteen(isbn)
      row["ISBN#{n}"]=isbn
    else
      next
    end
    n+=1
    return if n > 3
  }
end

def parse_identifiers(ids_str, row)
  ids=ids_str.split('; ')
  ids.each { |i|
    if i.match(/^heb_id: ?heb((\d\d\d\d\d)\.\d\d\d\d\.\d\d\d)/)
      row['HEB ID']="HEB#{$1}"
      return
    end
  }
end

header = [
"Author Last",
"Author First",
"Title",
"ISBN1",
"ISBN2",
"ISBN3",
"Pub City",
"Publisher",
"Pub Date",
"HEB ID",
"Subject Category",
]

CSV.open('data/ACLS HEB Removed Titles List.csv', 'w') do |output|
  output << header
  CSV.foreach(ARGV.shift, headers: true) do |input|
    next unless(input['Published?'].match(/TRUE/i))
    next unless(input['Tombstone?'])
    row = CSV::Row.new(header,[])
    row['Title'] = input['Title']
    parse_isbns(input['ISBN(s)'], row) if input['ISBN(s)']
    row['Pub Date'] = input['Pub Year'].tr('c','') if input['Pub Year']
    parse_identifiers(input['Identifier(s)'], row)
    if input['Creator(s)']
      input['Creator(s)'].gsub!(/\(.+?\)/,'')
      input['Creator(s)'].gsub!(/;.*?$/,'')
      input['Creator(s)'].to_s.match(/^(.+?),/) {row['Author Last'] = $1}
      input['Creator(s)'].to_s.match(/^.+?,(.+?)$/) {row['Author First'] = $1}
    elsif input['Additional Creator(s)']
      input['Additional Creator(s)'].gsub!(/\(.+?\)/,'')
      input['Additional Creator(s)'].gsub!(/;.*?$/,'')
      input['Additional Creator(s)'].to_s.match(/^(.+?),/) {row['Author Last'] = $1}
      input['Additional Creator(s)'].to_s.match(/^.+?,(.+?)$/) {row['Author First'] = $1}
    elsif input['Contributor(s)']
      input['Contributor(s)'].gsub!(/\(.+?\)/,'')
      input['Contributor(s)'].gsub!(/;.*?$/,'')
      input['Contributor(s)'].to_s.match(/^(.+?),/) {row['Author Last'] = $1}
      input['Contributor(s)'].to_s.match(/^.+?,(.+?)$/) {row['Author First'] = $1}
    end
    row['Pub City']=input['Pub Location']
    row['Publisher']=input['Publisher']
    row['Subject Category']=input['Subject']
    output << row
  end
end
