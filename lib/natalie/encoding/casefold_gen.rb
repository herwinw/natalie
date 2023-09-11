# This file generates the casefold.cpp source used by Natalie.
# To regenerate, run:
#
#     ruby lib/natalie/encoding/casefold_gen.rb > src/encoding/casefold.cpp

require 'open-uri'

EMPTY_BLOCK = [0] * 256

def generate_function(name, statuses, data)
  puts "Value EncodingObject::#{name}(nat_int_t codepoint) {"
  puts '    switch (codepoint) {'
  data.each do |code, status, mapping|
    next if code.nil?
    next unless statuses.include?(status)
    mapping = mapping.split
    if mapping.size > 1
      puts "        case 0x#{code}: return new ArrayObject({ #{mapping.map { |c| "Value::integer(0x#{c})" }.join(', ')} });"
    else
      puts "        case 0x#{code}: return Value::integer(0x#{mapping.first});"
    end
  end
  puts '    }'
  if statuses.include?('C')
    puts '    return NilObject::the();'
  else
    puts '    return casefold_common(codepoint);'
  end
  puts '}'
end

unless File.exist?('/tmp/CaseFolding.txt')
  File.write(
    '/tmp/CaseFolding.txt',
    URI.open('https://www.unicode.org/Public/UCD/latest/ucd/CaseFolding.txt').read
  )
end

data = File.read('/tmp/CaseFolding.txt').split(/\n/).grep_v(/^#/).map { |l| l.split('; ') }

puts '// This file is auto-generated from https://www.unicode.org/Public/UCD/latest/ucd/CaseFolding.txt'
puts '// See casefold_gen.rb in this repository for instructions regenerating it.'
puts '// DO NOT EDIT THIS FILE BY HAND!'
puts
puts '#include "natalie/encoding_object.hpp"'
puts '#include "natalie/nil_object.hpp"'
puts '#include "natalie/types.hpp"'
puts
puts 'namespace Natalie {'
puts
generate_function('casefold_common', ['C'], data)
puts
generate_function('casefold_full', ['F'], data)
puts
generate_function('casefold_simple', ['S'], data)
puts
puts '}'