require_relative './base_instruction'

module Natalie
  class Compiler
    class PushFalseInstruction < BaseInstruction
      def to_s
        'push_false'
      end

      def generate(transform)
        transform.push('Value::False()')
      end

      def execute(vm)
        vm.push(false)
      end

      def serialize(_)
        [instruction_number].pack('C')
      end

      def self.deserialize(_, _)
        new
      end
    end
  end
end
