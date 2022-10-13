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
      row['URL']="https://hdl.handle.net/2027/heb#{$1}"
      row['HEB ID']="HEB#{$1}"
      return
    end
  }
end

def get_hebid(ids_str)
  ids=ids_str.split('; ')
  ids.each { |i|
    if i.match(/^heb_id: ?heb((\d\d\d\d\d)\.\d\d\d\d\.\d\d\d)/)
      return "HEB#{$1}"
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
"URL"
]

manifest = ARGV.shift
hebids_file = ARGV.shift

CSV.open('data/ACLS HEB New Title List.csv', 'w') do |output|
  output << header
  hebid_filter = File.readlines(hebids_file)
  CSV.foreach(manifest, headers: true) do |input|
    next unless(input['Published?'].match(/TRUE/i))
    this_hebid = get_hebid(input['Identifier(s)'])
    #include? not matching for some reason so using grep
    next unless hebid_filter.grep(/#{this_hebid}/).length > 0
    next if(input['Tombstone?'])
    row = CSV::Row.new(header,[])
    parse_identifiers(input['Identifier(s)'], row)
    row['Title'] = input['Title']
    parse_isbns(input['ISBN(s)'], row) if input['ISBN(s)']
    row['Pub Date'] = input['Pub Year'].tr('c','') if input['Pub Year']
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
