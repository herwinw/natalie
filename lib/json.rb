# frozen_string_literal: true

require 'natalie/inline'
require 'json.cpp'

__ld_flags__ '-ljson-c'

module JSON
  class JSONError < StandardError; end
  class ParserError < JSONError; end

  __bind_static_method__ :generate, :JSON_generate, 1
  __bind_static_method__ :parse, :JSON_parse, -2
end
