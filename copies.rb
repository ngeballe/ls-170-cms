
def copy_number(filename)
  extname = File.extname(filename)
  return 0 unless filename =~ /copy( \d+)?#{extname}$/
  
  $1.nil? ? 1 : $1.to_i
end

def filename_stem(filename)
  # what's before 'copy x' in the name
  extname = File.extname(filename)
  filename.sub(/( copy( \d)*)?#{extname}/, '')
end

def next_integer(integers)
  # find missing integer in a series. If none are missing, take the max + 1

  raise ArgumentError unless integers.instance_of?(Array) &&
    integers.all? { |number| number.instance_of?(Integer) }

  integers.sort!
  integers_in_range = [*integers.min..integers.max]
  if integers_in_range == integers
    integers.max + 1
  else
    (integers_in_range - integers).first
  end
end

def next_copy_name(files, filename_being_copied)
  # extname = File.extname(filename_being_copied)
  filename_being_copied_stem = filename_stem(filename_being_copied)
  # p filename_being_copied_stem

  existing_copies = files.select do |file|
    filename_stem(file) == filename_being_copied_stem
  end

  existing_copy_numbers = existing_copies.map { |filename| copy_number(filename) }

  next_copy_number = next_integer(existing_copy_numbers)

  extname = File.extname(filename_being_copied)
  if next_copy_number == 1
    "#{filename_being_copied_stem} copy#{extname}"
  else
    "#{filename_being_copied_stem} copy #{next_copy_number}#{extname}"
  end
end

files = ["tom.txt", "ron.txt", "keith.txt", "katy.txt", "sarah.txt", "sarah copy.txt", "katy copy.txt", "ron copy 2.txt", "i will copy you on the email.txt"]

# p files.map { |filename| copy_number(filename) }

p next_copy_name(files, 'tom.txt') == 'tom copy.txt'
p next_copy_name(files, 'ron copy 2.txt') == 'ron copy.txt'
p next_copy_name(files, 'sarah copy.txt') == 'sarah copy 2.txt'
p next_copy_name(files, 'sarah.txt') == 'sarah copy 2.txt'
