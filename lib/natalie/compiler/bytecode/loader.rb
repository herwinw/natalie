require_relative 'header'
require_relative 'ro_data'
require_relative 'sections'
require_relative '../instruction_manager'
require_relative '../instructions'
require_relative '../../vm'

module Natalie
  class Compiler
    module Bytecode
      class Loader
        INSTRUCTIONS = Natalie::Compiler::INSTRUCTIONS

        def initialize(io)
          @io = IO.new(io)
          header = Bytecode::Header.load(@io)
          sections = Bytecode::Sections.load(@io)
          if sections.rodata?
            size = @io.read(4).unpack1('N')
            @rodata = RoData.load(@io.read(size))
          end
          @io.read(4) # Ignore section size for now
          @instructions = load_instructions
        end

        attr_reader :instructions

        class IO
          def initialize(io)
            @io = io
          end

          def getbool
            getbyte == 1
          end

          def getbyte
            @io.getbyte
          end

          def read(size)
            @io.read(size)
          end

          def read_ber_integer
            result = 0
            loop do
              byte = getbyte
              result += (byte & 0x7f)
              break if (byte & 0x80) == 0
              result <<= 7
            end
            result
          end
        end

        private

        def load_instructions
          instructions = []
          loop do
            num = @io.getbyte
            break if num.nil?

            instruction_class = INSTRUCTIONS.fetch(num)
            instructions << instruction_class.deserialize(@io, @rodata)
          end
          instructions
        end
      end
    end
  end
end
