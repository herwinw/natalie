require_relative 'string_to_cpp'
require_relative 'instructions'

include Natalie::Compiler::StringToCpp

puts <<~CPP
namespace Natalie {
namespace Instructions {
enum Instructions : uint8_t {
CPP
Natalie::Compiler::INSTRUCTIONS.each do |instruction|
  puts "#{instruction.to_s.gsub(/\A.*::/, '')},"
end
puts <<~CPP
_NUM_INSTRUCTIONS
};

const char *Names[] = {
CPP
Natalie::Compiler::INSTRUCTIONS.each do |instruction|
  puts "#{string_to_cpp(instruction.to_s.gsub(/\A.*::/, ''))},"
end
puts <<~CPP
};
}
}
CPP
