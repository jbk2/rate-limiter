class RateLimiter
  attr_reader :time
  
  def initialize(limit:, time:,  redis:)
    @limit = limit.to_i
    @time = time.to_i
    @redis = redis
  end

  def allowed?(ip)
    @redis.get(redis_key(ip)).to_i < @limit
  end
  
  def check!(ip)
    key = redis_key(ip)

    count = @redis.multi do |r|
      r.incr(key)
      r.expire(key, @time, nx: true)
    end.first

    raise RequestLimitReachedError if count > @limit

    count
  end

  def ttl(ip)
    key = redis_key(ip)
    ttl = @redis.ttl(key)
    
    ttl > -1 ? ttl : @time
  end

  private
  
  def redis_key(ip)
    "rate-limit:#{ip}"
  end
  
end

class RequestLimitReachedError < StandardError; end