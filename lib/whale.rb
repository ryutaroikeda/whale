# File: whale.rb

require 'set'
require 'logger'

MAJOR_VERSION = 0
MINOR_VERSION = 1
REVISION      = 0

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
  attr_reader :stack

  def initialize()
    @stack = []
  end

  # For regex options (e.g. ignorecase) use the (?opt:source) notation,
  # e.g. /(?i-mx:hEllo .*)/
  def parse_filter(f, logger)
    logger.debug("parsing #{f}")
    regex = false
    escape = false
    # literal = false
    token = 0
    stack = []
    (0...f.length).each do |i|
      if f[i] == '\\' or escape
        escape ^= true
      elsif f[i] == '/'
        if regex
          stack << Regexp.new(f[token, i - token])
          regex = false
        else
          token = i + 1
          regex = true
        end
      elsif !regex
        stack << :FILTER_AND if f[i] == '&'
        stack << :FILTER_OR if f[i] == '|'
        stack << :FILTER_NOT if f[i] == '*'
        stack << :FILTER_EQ if f[i] == '='
      end
    end
    logger.debug(stack)
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
  def filter(entry, logger)
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
          logger.debug("last tags: #{last_tags}")
          match = false
          s.pop
          last_tags.each do |u|
            if t.match entry.tags[u]
              match = true 
              logger.debug("#{t} matches #{entry.tags[u]}")
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
    logger.debug(s)
    logger.warn("Malformed filter") if s.length != 1
    return s.first
  end

end

def filter_entries(entries, filter, logger)
  entries.delete_if { |a| !filter.filter(a, logger) }
end

def sort_entries_by(entries, tag, logger)
  return entries.sort { |a, b| a.tags[tag] <=> b.tags[tag] }
end

$EDITOR_CMDS = {
  vim: "vim +%<line>d %<file>s",
  emacs: "emacs +%<line>d %<file>s",
  nano: "nano +%<line>d,1 %<file>s",
}
$EDITOR_CMDS.default = "ed %<file>s"

def open_editor(editor, path, lineno, logger)
  logger.debug("opening at #{lineno}")
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

# List files in the path with the given extension
def list_files_in_path(path, recursive, logger)
  file_glob = '*.{wl,whale}'
  if recursive
    glob_path = File.join(path, File.join('**', file_glob))
  else
    glob_path = File.join(path, file_glob)
  end
  return Dir.glob(glob_path)
end

EMPTY_LINE = /\A\s*\Z/
LABEL_LINE = /\A;(.*)\Z/

# Extract entries from file.
# param @file a file name to read
# return Array an array of Entry
def parse_file(file, logger)
  entries = []
  file_entry = Entry.new
  entry = nil
  is_reading_tag = true
  lineno = 0
  File.open(file, 'r') do |f|
    f.each_line do |line|
      lineno += 1
      # skip if the line is whitespace
      next if EMPTY_LINE.match line
      if (m = LABEL_LINE.match line)
        logger.debug("#{f.path}, #{lineno}, reading tag")
        is_reading_tag = true
        matched_line = m[1]
        if entry.nil?
          logger.debug("adding file entry tags #{matched_line}")
          parse_tags file_entry, matched_line
        else
          parse_tags entry, matched_line
        end
      elsif is_reading_tag
        logger.debug("#{f.path}, #{lineno}, new entry")
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
    logger.warn("#{file} missing last entry tags") if !is_reading_tag
  end
  # add the file level tags to each entry
  logger.debug(file_entry.tags)
  entries.each { |e| e.tags = file_entry.tags.merge(e.tags) }
  return entries
end
