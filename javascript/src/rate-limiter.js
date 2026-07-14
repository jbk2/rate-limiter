import { createClient } from "redis";

class RequestLimitReachedError extends Error {
  constructor(message = "You've breached the rate limit") {
    super(message);
    this.name = "RequestLimitReachedError";
  }
}

class RateLimiter {

  constructor( {limit, time, redis} ) {
    this.limit = Number(limit);
    this.time = Number(time);
    this.redis = redis;
  }

  async allowed(ip) {
    const count = Number(await this.redis.get(this.redis_key(ip))) || 0
    return count < this.limit ? true : false;
  }

  async check(ip) {
    const key = this.redis_key(ip)
    
    const [count] = await this.redis
      .multi()  
      .incr(key)
      .expire(key, this.time, "NX")
      .exec();

    if(count > this.limit) {
      throw new RequestLimitReachedError();
    }

    return count;
  }
 
  async ttl(ip) {
    const ttl = await this.redis.ttl(this.redis_key(ip))
    return ttl > -1 ? ttl: this.time;
  }

  async resetAt(ip) {
    const now = Math.floor(Date.now() / 1000);
    const ttl = await this.ttl(this.redis_key(ip));
    return now + ttl;
  }
 
  async remaining(ip) {
     const count = Number(await this.redis.get(this.redis_key(ip))) || 0;
     return Math.max(this.limit - count, 0);
  }

  redis_key(ip) {
    return `redis-key:${ip}`
  }

}

export { RateLimiter, RequestLimitReachedError }