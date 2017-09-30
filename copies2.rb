def filename_stem(filename)
  # what's before 'copy x' in the name
  extname = File.extname(filename)
  filename.sub(/( copy( \d)*)?#{extname}/, '')
end

p filename_stem("ron copy.txt")
p filename_stem("ron copy 3.txt")
p filename_stem("ron copy of toby.txt")
