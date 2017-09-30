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

p next_integer([0, 1])
p next_integer([0, 1, 2, 8, 3, 4, 6, 7])
p next_integer([0, 2])
