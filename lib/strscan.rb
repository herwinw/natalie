# frozen_string_literal: true

class StringScanner
  Version = '3.1.3'

  class Error < StandardError
  end

  private def initialize(string, fixed_anchor: false)
    @string = string.to_str
    @pos = 0
    @prev_pos = nil
    @matched = nil
    @fixed_anchor = fixed_anchor
  end

  attr_reader :string, :matched, :pos
  alias charpos pos

  def inspect
    if @pos >= @string.size
      '#<StringScanner fin>'
    else
      before = @pos == 0 ? nil : "#{@string[0...@pos].inspect} "
      after = " #{@string[@pos...@pos + 5].inspect[0..-2]}...\""
      "#<StringScanner #{@pos}/#{@string.size} #{before}@#{after}>"
    end
  end

  def pos=(index)
    index = @string.size + index if index < 0
    raise RangeError, 'pos negative' if index < 0
    raise RangeError, 'pos too far' if index > @string.size
    @pos = index
  end

  def string=(str)
    @string = str.to_str
    @pos = 0
  end

  def pointer
    pos
  end

  def pointer=(index)
    self.pos = index
  end

  def eos?
    @pos >= @string.size
  end

  def empty?
    warn('warning: StringScanner#empty? is obsolete; use #eos? instead') if $VERBOSE
    eos?
  end

  def fixed_anchor?
    @fixed_anchor
  end

  def captures
    @match.captures if @matched
  end

  def check(pattern)
    if pattern.is_a?(Regexp)
      anchored_pattern = Regexp.new('^' + pattern.source, pattern.options)
    else
      raise TypeError, "no implicit conversion of #{pattern.class.name} into String" unless pattern.respond_to?(:to_str)
      anchored_pattern = Regexp.new('^' + pattern.to_str)
    end
    if (@match = rest.match(anchored_pattern))
      @matched = @match.to_s
    else
      @matched = nil
    end
  end

  def check_until(pattern)
    unless pattern.is_a?(Regexp)
      pattern = pattern.to_str if !pattern.is_a?(String) && pattern.respond_to?(:to_str)
      raise TypeError, "no implicit conversion of #{pattern.class} into String" unless pattern.is_a?(String)
      pattern = Regexp.new(Regexp.quote(pattern))
    end
    start = @pos
    until (matched = check(pattern))
      @pos += 1
      return nil if @pos >= @string.size
    end
    @pos += matched.size
    accumulated = @string[start...@pos]
    @pos = start
    accumulated
  end

  def scan(pattern)
    unless pattern.is_a?(Regexp)
      pattern = pattern.to_str if !pattern.is_a?(String) && pattern.respond_to?(:to_str)
      raise TypeError, "no implicit conversion of #{pattern.class} into String" unless pattern.is_a?(String)
      pattern = Regexp.new(Regexp.quote(pattern))
    end
    @match =
      if @fixed_anchor
        @string.match(pattern, @pos)
      else
        anchored_pattern = Regexp.new('^' + pattern.source, pattern.options)
        rest.match(anchored_pattern)
      end
    if @match
      if @fixed_anchor && pattern.source.start_with?('^') && @match.pre_match.size > @pos
        @match = nil
        @matched = nil
        return nil
      end
      @matched = @match.to_s
      @prev_pos = @pos
      @pos += @matched.size
      @matched
    else
      @matched = nil
    end
  end

  def scan_until(pattern)
    pattern = /#{Regexp.quote(pattern)}/ if pattern.is_a?(String)
    raise TypeError, "wrong argument type #{pattern.class.name} (expected Regexp)" unless pattern.is_a?(Regexp)
    start = @pos
    until (matched = scan(pattern))
      return nil if @pos > @string.size
      @pos += 1
    end
    index = matched.empty? ? @pos : @pos + matched.size - 1
    @string[start...index]
  end

  def skip(pattern)
    anchored_pattern = Regexp.new('^' + pattern.source, pattern.options)
    if (match = rest.match(anchored_pattern))
      matched = match.to_s
      @pos += matched.size
      matched.size
    end
  end

  def skip_until(pattern)
    pattern = /#{Regexp.quote(pattern)}/ if pattern.is_a?(String)
    raise TypeError, "wrong argument type #{pattern.class.name} (expected Regexp)" unless pattern.is_a?(Regexp)
    start = @pos
    until scan(pattern)
      return nil if @pos > @string.size
      @pos += 1
    end
    @pos - start
  end

  def match?(pattern)
    anchored_pattern = Regexp.new('^' + pattern.source, pattern.options)
    @prev_pos = @pos
    if (@match = rest.match(anchored_pattern))
      @matched = @match.to_s
      @matched.size
    else
      @matched = nil
    end
  end

  def unscan
    if @match
      @pos = @prev_pos
      @match = nil
      @matched = nil
    else
      raise ScanError, 'no previous match'
    end
  end

  def peek(length)
    raise ArgumentError, 'length is negative' if length < 0
    @string.bytes[@pos...(@pos + length)].map(&:chr).join
  end

  def peep(length)
    warn('warning: StringScanner#peep is obsolete; use #peek instead') if $VERBOSE
    peek(length)
  end

  def peek_byte
    @string.bytes[@pos]
  end

  def scan_full(pattern, advance_pointer_p, return_string_p)
    pattern = /#{Regexp.quote(pattern)}/ if pattern.is_a?(String)
    raise TypeError, "wrong argument type #{pattern.class.name} (expected Regexp)" unless pattern.is_a?(Regexp)
    start = @pos
    scan(pattern)
    distance = @pos - start
    @pos = start unless advance_pointer_p
    return_string_p ? @matched : distance
  end

  alias search_full scan_full

  def get_byte
    @matched = scan(/./)
  end

  def scan_byte
    get_byte&.ord
  end

  def getch
    c = @string.chars[@pos]
    @prev_pos = @pos
    @pos += 1
    @matched = c
  end

  def getbyte
    warn('warning: StringScanner#getbyte is obsolete; use #get_byte instead') if $VERBOSE
    get_byte
  end

  def [](index)
    return nil unless @match
    raise TypeError, "no implicit conversion of #{index.class} into Integer" if index.is_a?(Range)

    @match[index]
  end

  def exist?(pattern)
    pattern = /#{Regexp.quote(pattern)}/ if pattern.is_a?(String)
    raise TypeError, "wrong argument type #{pattern.class.name} (expected Regexp)" unless pattern.is_a?(Regexp)
    return 0 if pattern == //
    start = @pos
    loop do
      if check(pattern)
        found_at = @pos - start + 1
        @pos = start
        return found_at
      end
      if @pos >= @string.size
        @pos = start
        return nil
      end
      @pos += 1
    end
    @pos = start
    nil
  end

  def pre_match
    @string[0...@prev_pos] if @prev_pos
  end

  def post_match
    return nil if @prev_pos.nil?
    @string[@pos..]
  end

  def named_captures
    return {} unless @match
    @match.named_captures
  end

  def values_at(...)
    @match&.values_at(...)
  end

  def matched?
    !!@matched
  end

  def matched_size
    @matched ? @matched.size : nil
  end

  def <<(str)
    raise TypeError, 'cannot convert argument to string' unless str.is_a?(String)
    @string << str
    self
  end

  alias concat <<

  def beginning_of_line?
    @pos == 0 || (@pos > 0 && @string[@pos - 1] == "\n")
  end

  alias bol? beginning_of_line?

  def rest
    @string[@pos..] || ''
  end

  def rest_size
    rest.size
  end

  def restsize
    warn('warning: StringScanner#restsize is obsolete; use #rest_size instead') if $VERBOSE
    rest_size
  end

  def rest?
    @pos < @string.size
  end

  def reset
    @pos = 0
    @match = nil
    @matched = nil
  end

  def size
    @match.size if @match
  end

  def terminate
    @pos = @string.size
  end

  def clear
    warn('warning: StringScanner#clear is obsolete; use #terminate instead') if $VERBOSE
    terminate
  end

  def self.must_C_version
    self
  end
end

ScanError = StringScanner::Error
