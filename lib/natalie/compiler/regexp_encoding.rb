module Natalie
  class Compiler
    module RegexpEncoding
      private

      def encoding
        case @encoding
        when Encoding::EUC_JP
          'EncodingObject::get(Encoding::EUC_JP)'
        when Encoding::ASCII_8BIT
          'EncodingObject::get(Encoding::ASCII_8BIT)'
        else
          'nullptr';
        end
      end
    end
  end
end
