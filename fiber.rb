#!/usr/bin/env ruby
# frozen_string_literal: true

# Docs: https://ruby-doc.org/core-3.1.1/Fiber/SchedulerInterface.html

class Scheduler
  attr_reader :consumers, :producers

  def initialize
    @consumers = []
    @producers = []
  end

  # Wait for the given io readiness to match the specified events within
  # the specified timeout.
  # @parameter event [Integer] A bit mask of `IO::READABLE`,
  #   `IO::WRITABLE` and `IO::PRIORITY`.
  # @parameter timeout [Numeric] The amount of time to wait for the event in seconds.
  # @returns [Integer] The subset of events that are ready.
  def io_wait(io, events, timeout)
  end

  # Read from the given io into the specified buffer.
  # WARNING: Experimental hook! Do not use in production code!
  # @parameter io [IO] The io to read from.
  # @parameter buffer [IO::Buffer] The buffer to read into.
  # @parameter length [Integer] The minimum amount to read.
  def io_read(io, buffer, length)
  end

  # Write from the given buffer into the specified IO.
  # WARNING: Experimental hook! Do not use in production code!
  # @parameter io [IO] The io to write to.
  # @parameter buffer [IO::Buffer] The buffer to write from.
  # @parameter length [Integer] The minimum amount to write.
  def io_write(io, buffer, length)
  end

  # Sleep the current task for the specified duration, or forever if not
  # specified.
  # @parameter duration [Numeric] The amount of time to sleep in seconds.
  def kernel_sleep(duration = nil)
  end

  # Execute the given block. If the block execution exceeds the given timeout,
  # the specified exception `klass` will be raised. Typically, only non-blocking
  # methods which enter the scheduler will raise such exceptions.
  # @parameter duration [Integer] The amount of time to wait, after which an exception will be raised.
  # @parameter klass [Class] The exception class to raise.
  # @parameter *arguments [Array] The arguments to send to the constructor of the exception.
  # @yields {...} The user code to execute.
  def timeout_after(duration, klass, *arguments, &block)
  end

  # Resolve hostname to an array of IP addresses.
  # This hook is optional.
  # @parameter hostname [String] Example: "www.ruby-lang.org".
  # @returns [Array] An array of IPv4 and/or IPv6 address strings that the hostname resolves to.
  def address_resolve(hostname)
  end

  # Block the calling fiber.
  # @parameter blocker [Object] What we are waiting on, informational only.
  # @parameter timeout [Numeric | Nil] The amount of time to wait for in seconds.
  # @returns [Boolean] Whether the blocking operation was successful or not.
  def block(blocker, timeout = nil)
    warn("Block: #{blocker}, #{timeout}")
    @producers.each(&:resume)
  end

  # Unblock the specified fiber.
  # @parameter blocker [Object] What we are waiting on, informational only.
  # @parameter fiber [Fiber] The fiber to unblock.
  # @reentrant Thread safe.
  def unblock(blocker, fiber)
    warn("Unblock: #{blocker}, #{fiber}")
  end

  # Intercept the creation of a non-blocking fiber.
  # @returns [Fiber]
  def fiber(&block)
    Fiber.new(blocking: false, &block)
  end

  # Invoked when the thread exits.
  def close
    self.run
  end

  def run
    # Implement event loop here.
    warn("Closing the scheduler (why the indirection with run?)")
  end
end

scheduler = Scheduler.new
Fiber.set_scheduler(scheduler)
queue = Queue.new
producer = Fiber.new { queue << :value }
scheduler.producers << producer
consumer = Fiber.new { queue.pop }
scheduler.consumers << consumer
warn consumer.resume
warn scheduler.inspect
