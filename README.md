# RateLimiter
A simple Ruby rate limiting service backed by Redis. Tracks requests per IP address and enforces a maximum number of requests within a time window.

## Requirements
- Ruby 3.x
- Redis running locally (default: `127.0.0.1:6379`)

## Setup, Tests & Quick Start
```bash
bundle install
```

Tests use a real Redis connection and call `flushdb` before each example to keep state isolated.
```bash
rspec spec
```

```ruby
require_relative "rate_limiter"
require "redis"
limiter = RateLimiter.new(
  limit: 10,
  time: 60,              # window in seconds
  redis: Redis.new
)
ip = "1.2.3.4"
limiter.allowed?(ip)       # => true (read-only check)
limiter.increment!(ip)     # => { "limit" => "10", "count" => "1" }
```

---

## API

### `RateLimiter.new(limit:, time:, redis:)`

Creates a rate limiter instance.
| Argument | Type    | Description                                |
|----------|---------|--------------------------------------------|
| `limit`  | Integer | Maximum requests allowed per IP per window |
| `time`   | Integer | Window length in seconds (Redis key TTL)   |
| `redis`  | Redis   | An existing Redis connection               |


### `#allowed?(ip_address)`

- **Read-only check** - Use when you want to check without recording a request.
— does not increment the counter.

|            |                                                                 |
|------------|-----------------------------------------------------------------|
| **Param**  | `ip_address` (String)                                           |
| **Returns**| `true` if under limit or no record exists yet                   |
|            | `false` if at or over limit                                     |
| **Raises** | Nothing                                                         |


### `#increment!(ip_address)`

-**Records a request** — increments the counter for the IP.

|            |                                                                 |
|------------|-----------------------------------------------------------------|
| **Param**  | `ip_address` (String)                                           |
| **Returns**| Hash of the Redis record, e.g. `{ "limit" => "10", "count" => "3" }` |
| **Raises** | `RequestLimitReachedError` when the limit is exceeded           |
The `!` indicates this method mutates state (increments the count) and raises on failure.


### `RequestLimitReachedError`

Top-level exception raised by `#increment!` when an IP has hit its limit.

```ruby
  begin
    limiter.increment!(ip)
  rescue RequestLimitReachedError => e
    puts e.message  # "You have breached your rate limit"
  end
```