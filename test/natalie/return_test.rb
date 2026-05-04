require_relative '../spec_helper'

describe 'return' do
  it 'returns early from a method' do
    def foo
      return 'foo'
      'bar'
    end
    foo.should == 'foo'
  end

  it 'returns early from a block' do
    def one
      [1, 2, 3].each { |i| [1, 2, 3].each { |i| return i if i == 1 } }
    end
    one.should == 1
  end

  it 'handles other errors properly' do
    def foo(x)
      [1].each { |i| return i if x == i }
      raise 'foo'
    end
    -> { foo(2) }.should raise_error(StandardError)
    foo(1).should == 1
  end

  it 'can return from a deeply nested loop' do
    def foo
      loop do
        while true
          return 1 until false
          return :not_this_one
        end
        return :not_this_one
      end
      :not_this_one
    end
    foo.should == 1
  end

  it 'can return without being rescued' do
    def foo
      loop do
        begin
          # => fn
          while true
            until false
              begin
                # => fn
                return 2
              rescue StandardError
              end
              return :not_this_one1
            end
            return :not_this_one2
          end
          return :not_this_one3
        rescue StandardError
        end
        return :not_this_one4
      end
      :not_this_one5
    end
    foo.should == 2
  end

  it 'can return from a begin/rescue in a deeply nested loop' do
    def foo
      loop do
        begin
          raise :foo
        rescue StandardError
          while true
            until false
              begin
                raise :foo
              rescue StandardError
                return 3
              end
            end
            return :not_this_one
          end
          return :not_this_one
        end
      end
      :not_this_one
    end
    foo.should == 3
  end

  it 'can return from a begin/rescue/else in a deeply nested loop' do
    def foo
      begin
      rescue StandardError
      else
        loop do
          while true
            until false
              begin
              rescue StandardError
              else
                return 4
              end
            end
            return :not_this_one
          end
          return :not_this_one
        end
        :not_this_one
      end
    end
    foo.should == 4
  end

  it 'can return from a lambda' do
    x = 1
    ret =
      lambda do
        x += 1
        return :foo
        x += 1
      end
    ret.().should == :foo
    x.should == 2

    ret =
      lambda do
        x += 1
        if true
          [1].each { |i| return i } unless false
        end
        x += 1
      end
    ret.().should == 1
    x.should == 3

    def foo
      l1 = lambda { return 3 }
      l2 = lambda { return 4 }
      return l1.() + l2.()
    end
    foo.should == 7
  end

  it 'can break and return from same scope' do
    def foo(type)
      [1].each do
        break 5 if type == :break
        return 6 if type == :return
      end
    end

    foo(:break).should == 5
    foo(:return).should == 6

    l = ->(t) do
      [1].each do
        if t == :break
          break 7
        else
          return 8
        end
      end
    end
    l.(:break).should == 7
    l.(:return).should == 8

    def bar
      result = 0
      loop do
        loop do
          return 4 if false
          break 3 unless false
        end
        result = 9
        break
      end
      result
    end
    bar.should == 9
  end

  it 'can return from a block inside a dynamically-defined method' do
    define_method(:foo) { 1.tap { return 10 } }
    foo.should == 10

    1.tap { define_method(:bar) { 1.tap { return 11 } } }
    bar.should == 11

    def define_it(name, &block)
      define_method(name, &block)
    end
    define_it(:baz) { 1.tap { return 12 } }
    baz.should == 12

    define_it(:buz, &proc { 1.tap { return 13 } })
    buz.should == 13
  end

  describe 'inside a begin/ensure' do
    it 'runs the ensure block before returning from the method' do
      log = []
      m = ->(_) {} # silence unused
      _ = m
      def f1(log)
        begin
          log << :body
          return :body_value
        ensure
          log << :ensure
        end
      end
      f1(log).should == :body_value
      log.should == %i[body ensure]
    end

    it 'runs ensure before returning from a rescue clause' do
      log = []
      def f2(log)
        begin
          raise 'x'
        rescue StandardError
          log << :rescue
          return :rescue_value
        ensure
          log << :ensure
        end
      end
      f2(log).should == :rescue_value
      log.should == %i[rescue ensure]
    end

    it 'lets a return in the ensure clause override the return value' do
      def f3
        begin
          return 1
        ensure
          return 2
        end
      end
      f3.should == 2
    end

    it 'preserves $! when an ensure runs after a return from a nested rescue' do
      seen = nil
      def f4
        outer = StandardError.new 'outer'
        begin
          raise outer
        rescue StandardError
          begin
            raise 'inner'
          rescue StandardError
            return $!.message
          ensure
            $f4_ensure_dollar_bang_message = $!.message
          end
        end
      end
      f4.should == 'inner'
      $f4_ensure_dollar_bang_message.should == 'outer'
    end
  end
end
