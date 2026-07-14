import { RateLimiter, RequestLimitReachedError } from "../src/rate-limiter.js";
import { createClient } from "redis";

let redis, limiter;

beforeEach(async () => {
  redis = createClient()
  await redis.connect();
  await redis.flushDb();

  limiter = new RateLimiter({ limit: 10, time: 60, redis: redis })
});

afterEach(async () => {
  await redis.quit();
})

test("#redis_key", async () => {
  const limiter = new RateLimiter({ limit: 10, time: 60, redis: redis })
  const ip = "1.1.1.1";
  
  expect(limiter.redis_key(ip)).toBe("redis-key:1.1.1.1")
})

describe("check, on a within limits IP", () => {
  test("check on a newly requesting IP correctly registers the count", async () => {
    const ip = "1.1.1.1";
    expect(await limiter.check(ip)).toBe(1);
  })
  
  test("check on an already requeste IP increments count correctly", async () => {
    const ip = "1.1.1.1";
    for(let i = 0; i < 5; i++) {
      await limiter.check(ip);
    }
    
    expect(await limiter.check(ip)).toBe(6)
  })
})

describe("check, with an outside rate limit IP", () => {
  test("returns a RateLimitReachedError", async () => {
    const ip = "1.1.1.1";
    for(let i = 0; i < 10; i++) {
      await limiter.check(ip);
    }

    await expect(() => limiter.check(ip)).rejects.toThrow(RequestLimitReachedError);
  })
})

describe("ttl", () => {
  test("returns correct ttl on a fresh requesting IP", async () => {
    const ip = "1.1.1.1";
    await limiter.check(ip);
    expect(await limiter.ttl(ip)).toBe(60);
  })
  
  test("returns correct ttl on an as yet unrequested IP", async () => {
    const ip = "1.1.1.2";
    expect(await limiter.ttl(ip)).toBe(60);
  })
})

describe("resetAt", () => {
  test("returns correct remaining time in seconds to rate limit expiry", async () => {
    const ip = "1.1.1.1";
    await limiter.check(ip)
    const now = Math.floor(Date.now() / 1000)
    expect(await limiter.resetAt(ip)).toBe(now + 60);
  })
})

describe("allowed, with requests available in current rate window", () => {
  test("returns true", async () => {
    const ip = "1.1.1.1";
    await limiter.check(ip)
    expect(await limiter.allowed(ip)).toBeTruthy;
  })
})

describe("allowed, without requests available in current rate window", () => {
  test("returns false", async () => {
    const ip = "1.1.1.1";
    for(let i = 0; i < 10; i++) {
      await limiter.check(ip)
    }
    expect(await limiter.allowed(ip)).toBeFalsey;
  })
})

describe("#remaining, when IP does have requests remaining ", () => {
  test("when one made, a limit of 10, returns 9 remaining", async () => {
    const ip = "1.1.1.1";
    await limiter.check(ip)
    expect(await limiter.remaining(ip)).toBe(9);
  })
  
  test("when 10 made, a limit of 10, returns 0 remaining", async () => {
    const ip = "1.1.1.1";
    for(let i = 0; i < 10; i++) {
      await limiter.check(ip)
    }
    
    expect(await limiter.remaining(ip)).toBe(0);
  })
})