require 'natalie/inline'

class Thread
  # Run +block+ with an interrupt-mask in effect. The mask is a
  # +{Module/Class => :immediate|:on_blocking|:never}+ Hash that controls
  # what happens when this thread is the target of +Thread#raise+:
  #
  # * +:immediate+ -- deliver right away (the default with no mask).
  # * +:on_blocking+ -- queue the exception, deliver at the next blocking
  #   primitive (Mutex#sleep, Queue#pop, etc).
  # * +:never+ -- queue the exception until the mask frame ends. When the
  #   block returns and the frame is popped, any item the now-outer mask
  #   resolves to :immediate is delivered, which is why a deferred raise
  #   can fire *after* the user block.
  #
  # Items deferred while the user block runs are walked again on pop. If
  # the block also raised, the deferred interrupt replaces it (Ruby's
  # ensure-replaces-exception semantics, which is why the drain has to be
  # in a Ruby +ensure+ rather than a C++ destructor).
  def self.handle_interrupt(mask)
    raise ArgumentError, 'block is needed.' unless block_given?
    __inline__ 'ThreadObject::current()->push_interrupt_mask(env, mask_var);'
    begin
      # Drain inside +begin+ so a delivered :immediate exception still
      # triggers the +ensure+ that pops the mask we just pushed; if we
      # drained before the begin, an exception there would leak the frame.
      __inline__ 'ThreadObject::current()->deliver_pending(env, ThreadObject::CheckpointKind::Blocking);'
      yield
    ensure
      __inline__ 'ThreadObject::current()->pop_interrupt_mask(env);'
    end
  end

  def self.pending_interrupt?(*args)
    Thread.current.pending_interrupt?(*args)
  end
end
