class RateLimiter
  def initialize(limit:, time:,  redis:)
    @limit = limit.to_i
    @time = time.to_i
    @redis = redis
  end

  def allowed?(ip)
    if @redis.hexists(ip, "count")
      limit, count = @redis.hmget(ip, "limit", "count")
    
      return false if count.to_i >= limit.to_i
    end
    
    return true
  end
  
  def increment!(ip)
    if @redis.hexists(ip, "count")
      limit, count = @redis.hmget(ip, "limit", "count")
      
      if count.to_i >= limit.to_i
        raise RequestLimitReachedError, "You have breached your rate limit"
      else
        @redis.hincrby(ip, "count", 1)
        return @redis.hgetall(ip)
      end
    else
      @redis.multi do |r|
        r.hset(ip, { limit: @limit, count: 1 })
        r.expire(ip, @time)
      end
      return @redis.hgetall(ip)
    end
  end

  
end

class RequestLimitReachedError < StandardError; end

# logic idea:
# - each request set an Expire at the time value
# - every request increment by one
# - only increment if count is < limit
# - if count >= limit then return RequestLimitReachedError