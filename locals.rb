#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  gem 'prism'
end

class Visitor
  def initialize
    @locals_stack = []
  end

  def push_locals(locals) = @locals_stack.push(locals)
  def pop_locals = @locals_stack.pop
  def locals = @locals_stack.last

  def visit_program_node(node)
    push_locals(node.locals)
    [
      "locals = Array.new(#{node.locals.size}) # #{node.locals}",
      *node.statements.accept(self),
    ]
  ensure
    pop_locals
  end

  def visit_statements_node(node)
    node.body.map { _1.accept(self) }
  end

  def visit_local_variable_write_node(node)
    "locals[#{locals.index(node.name)}] = #{node.value.accept(self)} # #{node.name}"
  end

  def visit_local_variable_read_node(node)
    "locals[#{locals.index(node.name)}]"
  end

  def visit_integer_node(node)
    node.value
  end

  def visit_call_node(node)
    case node.name
    when :local_variables
      locals.inspect
    when :local_variable_get
      raise 'expected 1 argument' unless node.arguments.arguments.size == 1
      name = node.arguments.arguments.first.unescaped.to_sym
      "locals[#{locals.index(name)}]"
    else
      arguments = node.arguments&.arguments || []
      "#{node.receiver.nil? ? '' : "#{node.receiver.accept(self)}."}#{node.name}(#{arguments.map { _1.accept(self) }.join(', ')})"
    end
  end

  def visit_def_node(node)
    raise NotImplementedError, 'parameters not supported' unless node.parameters.nil?

    push_locals(node.locals)
    [
      "def #{node.name}",
      "  locals = Array.new(#{node.locals.size}) # #{node.locals}",
      *node.body.accept(self).map { "  #{_1}" },
      'end',
    ]
  ensure
    pop_locals
  end
end

require 'prism'
code = <<~RUBY
  a = 1
  p binding.local_variables

  def foo
    b = 2
    p binding.local_variables
    c = 3
    c = 4
    p c
    p binding.local_variables
  end

  b = 3
  p binding.local_variables
  p binding.local_variable_get(:a)

  foo
RUBY
puts code
puts '------'
eval(<<~"RUBY")
module NewNamespace
  instance_eval do
  #{code}
  end
end
RUBY
puts '------'
parsed = Prism.parse(code)
output = parsed.value.accept(v = Visitor.new)
raise 'locals stack inconsistency' unless v.locals.nil?
code = output.join("\n")
puts code
puts '------'
eval(code)
