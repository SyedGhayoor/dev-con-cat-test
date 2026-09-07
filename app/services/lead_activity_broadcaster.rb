# In-process pub/sub for the live pixel-activity SSE stream. Each open
# connection gets its own Queue; ActivityEvent pushes onto every subscriber
# queue for the lead it belongs to as soon as it's created.
class LeadActivityBroadcaster
  @subscribers = Hash.new { |h, k| h[k] = [] }
  @mutex = Mutex.new

  class << self
    def subscribe(lead_id)
      queue = Queue.new
      @mutex.synchronize { @subscribers[lead_id] << queue }
      queue
    end

    def unsubscribe(lead_id, queue)
      @mutex.synchronize { @subscribers[lead_id].delete(queue) }
    end

    def publish(lead_id, event)
      @mutex.synchronize { @subscribers[lead_id].dup }.each { |queue| queue << event }
    end
  end
end
