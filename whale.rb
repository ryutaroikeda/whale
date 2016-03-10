#!/usr/bin/env ruby
# File: whale.rb

require 'set'

MAJOR_VERSION = 0
MINOR_VERSION = 0
REVISION      = 0

DEBUG = true

USAGE = <<ENDUSAGE
Usage:
  whale [-h] [-f tag] [-s tag] [-e id] files..
ENDUSAGE

HELP = <<ENDHELP
  -h, --help           View this message
  -f, --filter         List entries with the tag
  -s, --sort           Sort entries by the tag value
  -e, --edit           Open the editor to given entry
  -w, --write          Write the entries to file
  --version            Show the version

-f, --filter filter
  Show entries with tags satisfying the filter. The filter is a string 
  consisting of Ruby regexes and operators in reverse polish notation. 
  A regex evaluates to true if at least one tag name in an entry matches it.
  One can further match on the tag value by writing = followed by a regex.
  Options for regexes are specified by writing /(?option:regex)/.
  The symbols for AND, OR, and NOT are &, |, and *, respectively.

-s, --sort tag
  Sort the entries by tag.

-e, --edit id
  Edit the entry with id id using the text editor specified by the environment 
  EDITOR.

-w, --write
  Write the entries, including title, body, and tags, to stdout.
ENDHELP

def debug(msg)
  puts msg if DEBUG
end

def error(msg)
  puts "Error: #{msg}"
end

def warning(msg)
  puts "Warning: #{msg}"
end

$DEFAULT_TAGS = [:title, :body, :line, :file, :tags]

class Entry
  attr_accessor :tags

  def initialize()
    @tags = { title: '', body: '', line: 0, file: '', tags: '' }
  end

  def print()
    puts "#{@tags[:line]}, #{@tags[:file]}: #{@tags[:title]}"
  end

end

class Filter

  def initialize()
    @stack = []
  end

  # For regex options (e.g. ignorecase) use the (?opt:source) notation,
  # e.g. /(?i-mx:hEllo .*)/
  def parse_filter(f)
    debug("parsing #{f}")
    regex = false
    quote = nil
    escape = false
    # literal = false
    token = 0
    stack = []
    (0...f.length).each do |i|
      if f[i] == '\\' or escape
        escape ^= true
      elsif f[i] == '"' or f[i] == "'"
        unless regex
          if quote == f[i]
            stack << f[token, i - token]
            quote = nil
          else
            token = i + 1
            quote = f[i]
          end
        end
      elsif f[i] == '/'
        unless quote
          if regex
            stack << Regexp.new(f[token, i - token])
            regex = false
          else
            token = i + 1
            regex = true
          end
        end
      elsif !regex and !quote
        stack << :FILTER_AND if f[i] == '&'
        stack << :FILTER_OR if f[i] == '|'
        stack << :FILTER_NOT if f[i] == '*'
        stack << :FILTER_EQ if f[i] == '='
      end
    end
    debug(stack)
    @stack = stack
  end

  def match_token(entry, token)
    tags = []
    entry.tags.each do |t, v|
      tags << t if token.match t.to_s
    end
    return tags
  end

  # apply the stack to the entry tags
  def filter(entry)
    s = []
    last_tags = []
    eq = false
    @stack.each do |t|
      case t
      when :FILTER_AND then s << (s.pop & s.pop)
      when :FILTER_OR then s << (s.pop | s.pop)
      when :FILTER_NOT then s << !s.pop
      when :FILTER_EQ then eq = true
      else
        if eq
          debug("last tags: #{last_tags}")
          match = false
          s.pop
          last_tags.each do |u|
            if t.match entry.tags[u]
              match = true 
              debug("#{t} matches #{entry.tags[u]}")
              break
            end
          end
          s << match
          eq = false
        else
          last_tags = match_token entry, t
          s << !last_tags.empty?
        end
      end
    end
    debug(s)
    warning("malformed filter") if s.length != 1
    return s.first
  end

end

def filter_entries(entries, filter)
  entries.delete_if { |a| !filter.filter(a) }
end

def sort_entries_by(entries, tag)
  return entries.sort { |a, b| a.tags[tag] <=> b.tags[tag] }
end

$EDITOR_CMDS = {
  vim: "vim +%<line>d %<file>s",
  emacs: "emacs +%<line>d %<file>s",
  nano: "nano +%<line>d,1 %<file>s",
}
$EDITOR_CMDS.default = "ed %<file>s"

def open_editor(editor, path, lineno)
  debug("opening at #{lineno}")
  args = {line: lineno, file: path}
  cmd = $EDITOR_CMDS[editor] % args
  exec(cmd)
end

def write_entries(entries)
  entries.each do |e|
    printf("#{e.tags[:title]}\n")
    printf("#{e.tags[:body]}")
    # extension: implement wrapping
    e.tags.each do |t, v|
      next if $DEFAULT_TAGS.find_index(t) 
      printf(";#{t}")
      printf("=#{v}") if v != true
      printf("\n")
    end
  end
end

# Print the entries.
def list_entries(entries, tags, tags_format)
  id = 1
  header_format = "%6.6s "
  header = ["ID"]
  row_format = "%<id>6d "
  raise "tags and format length mismatch" if tags.length != tags_format.length
  tags.each_index do |i|
    w = tags_format[i]
    header_format += "%-#{w}.#{w}s "
    row_format += "%<#{tags[i]}>-#{w}.#{w}s "
    header << tags[i]
  end
  puts header_format % header
  entries.each do |e|
    h = e.tags.merge({ id: id })
    h.default = "--"
    puts row_format % h
    id += 1
  end
end

def parse_tag(entry, tag_str)
  a = tag_str.split("=", 2)
  tag = a[0].strip.to_sym
  if tag.length == 0
    return
  end
  if a.length != 2
    value = true 
  else
    value = a[1]
  end
  entry.tags[tag] = value
  entry.tags[:tags] << "," unless entry.tags[:tags].empty?
  entry.tags[:tags] << "#{tag}"
end

def parse_tags(entry, line)
  a = line.split(" ")
  a.each { |tag_str| parse_tag(entry, tag_str) }
end

def get_all_tags(entries)
  s = Set.new
  entries.each do |e|
    e.tags.each do |k, _|
      s.add(k)
    end
  end
  return s.to_a()
end

def list_tags(tags)
  s = ""
  tags.each do |tag|
    s << "#{tag}, "
  end
  puts s.slice(0, s.length - 2)
end


EMPTY_LINE = /\A\s*\Z/
LABEL_LINE = /\A;(.*)\Z/

# Extract entries from file.
# param @file String the path of the file to parse
# return Array the array of Entry
def parse_file(file)
  entries = []
  file_entry = Entry.new
  File.open(file, "r") do |f|
    entry = nil
    is_reading_tag = true
    lineno = 0
    f.each_line do |line|
      lineno += 1
      # skip if the line is whitespace
      next if EMPTY_LINE.match line
      if (m = LABEL_LINE.match line)
        debug("#{f.path}, #{lineno}, reading tag")
        is_reading_tag = true
        matched_line = m[1]
        if entry.nil?
          debug("adding file entry tags #{matched_line}")
          parse_tags file_entry, matched_line
        else
          parse_tags entry, matched_line
        end
      elsif is_reading_tag
        debug("#{f.path}, #{lineno}, new entry")
        is_reading_tag = false
        entries << entry if !entry.nil?
        entry = Entry.new
        entry.tags[:title] = line.strip
        entry.tags[:line] = lineno
        entry.tags[:file] = f.path
      else
        entry.tags[:body] << line
      end
    end
    entries << entry if !entry.nil?
    puts "Last entry is missing tag" if !is_reading_tag
  end
  # add the file level tags to each entry
  debug(file_entry.tags)
  entries.each { |e| e.tags = file_entry.tags.merge(e.tags) }
  return entries
end

if __FILE__ == $0
  args = { :files => [] }
  unflagged_args = [:files]
  next_arg = unflagged_args.first
  ARGV.each do |arg|
    case arg
    when '-h','--help'          then args[:help] = true
    when '-f','--filter'        then next_arg = :filter
    when '-s','--sort'          then next_arg = :sort
    when '-e','--edit'          then next_arg = :edit
    when '-w', '--write'        then args[:write] = true
    when '--version'            then args[:version] = true
    else
      if next_arg == :files
        args[:files] << arg
      else
        args[next_arg] = arg
        unflagged_args.delete next_arg
        next_arg = unflagged_args.first
      end
    end
  end
  if args[:version]
    puts "whale.rb version #{MAJOR_VERSION}.#{MINOR_VERSION}.#{REVISION}"
    exit
  end
  if args[:help] or args[:files].empty?
    puts USAGE
    puts HELP if args[:help]
    exit
  end
  entries = []
  args[:files].each { |f| entries += parse_file(f) }
  puts "Parsed #{args[:files].length} files and #{entries.length} entries"
  if args[:filter]
    filter = Filter.new
    filter.parse_filter args[:filter]
    filter_entries(entries, filter)
  end 
  sort_entries_by(entries, args[:sort]) if args[:sort]
  if args[:edit]
    i = args[:edit].to_i - 1
    e = entries[i]
    if e.nil?
      puts "Invalid ID"
      exit
    end
    open_editor(ENV['EDITOR'].to_sym, e.tags[:file], e.tags[:line])
  end
  write_entries(entries) if args[:write]
  if !args[:write]
    all_tags = get_all_tags entries
    debug(list_tags(all_tags))
    tags_to_list = [:title, :date, :tags]
    tags_format = [45, 10, 25]
    list_entries(entries, tags_to_list, tags_format)
  end
end
