require_relative 'string_to_cpp'
require_relative 'instructions'

puts <<~CPP
namespace Natalie {
namespace Instructions {
enum Instructions : uint8_t {
CPP
Natalie::Compiler::INSTRUCTIONS.each_with_index do |instruction, index|
puts "#{instruction.to_s.gsub(/\A.*::/, '')} = #{index},"
end
puts <<~CPP
};
}
}
CPP
