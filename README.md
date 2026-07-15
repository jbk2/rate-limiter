# RateLimiter

A simple rate limiting service backed by Redis. Tracks requests per IP address and enforces a maximum number of requests within a time window.

Implemented in both **Ruby** and **JavaScript**.

## Requirements

- Redis running locally (default: `127.0.0.1:6379`)
- **Ruby:** Ruby 3.x
- **JavaScript:** Node.js 18+

Both test suites use a real Redis connection and call `flushdb` / `flushDb` before each example to keep state isolated.

## Ruby ↔ JavaScript methods

| Ruby            | JavaScript       |
|-----------------|------------------|
| `allowed?`      | `allowed`        |
| `check!`        | `check`          |
| `reset_at`      | `resetAt`        |
| `ttl`           | `ttl`            |
| `remaining`     | `remaining`      |

Both implementations share the same logic: increment a Redis counter per IP, set a TTL on first request, and reject once the count exceeds the limit.

---

## Ruby

### Setup & tests

```bash
cd ruby
bundle install
bundle exec rspec
```

### Quick start

```ruby
require_relative "lib/rate_limiter"
require "redis"

limiter = RateLimiter.new(limit: 10, time: 60, redis: Redis.new)
ip = "1.2.3.4"

limiter.allowed?(ip)   # => true (read-only check)
limiter.check!(ip)      # => 1 (records request, returns count)
```

### API

- `RateLimiter.new(limit:, time:, redis:)` — create a limiter (`limit` = max requests per window, `time` = window in seconds).
- `#allowed?(ip)` — read-only; returns `true` if under limit (or no record yet).
- `#check!(ip)` — increment and return count; raises `RequestLimitReachedError` when over limit.
- `#ttl(ip)` — seconds until window resets; returns `time` if IP has no record.
- `#remaining(ip)` — requests left in the current window.
- `#reset_at(ip)` — Unix timestamp when the window expires.

Redis keys: `rate-limit:<ip>`.

---

## JavaScript

### Setup & tests

```bash
cd javascript
npm install
npm test
```

Tests are written with Jest and use ES modules.

### Quick start

```javascript
import { createClient } from "redis";
import { RateLimiter } from "./src/rate-limiter.js";

const redis = createClient();
await redis.connect();

const limiter = new RateLimiter({ limit: 10, time: 60, redis });
const ip = "1.2.3.4";

await limiter.allowed(ip);  // => true (read-only check)
await limiter.check(ip);    // => 1 (records request, returns count)

await redis.quit();
```

All Redis methods are async — use `await` on every call.

### API

All methods are `async` — use `await`.

- `new RateLimiter({ limit, time, redis })` — create a limiter (`limit` = max requests per window, `time` = window in seconds).
- `allowed(ip)` — read-only; returns `true` if under limit (or no record yet).
- `check(ip)` — increment and return count; throws `RequestLimitReachedError` when over limit.
- `ttl(ip)` — seconds until window resets; returns `time` if IP has no record.
- `remaining(ip)` — requests left in the current window.
- `resetAt(ip)` — Unix timestamp when the window expires.

Redis keys: `redis-key:<ip>`. Test async errors: `await expect(limiter.check(ip)).rejects.toThrow(RequestLimitReachedError)`.

---