require 'rspec'
require 'redis'
require_relative '../rate_limiter'

RSpec.describe "Rate Limiter Class" do
  let(:ip) { "011.011.01.01" }
  let(:redis_instance) { Redis.new }
  let(:limiter) { RateLimiter.new(limit: 10, time: 60, redis: redis_instance )}

  before do
    redis_instance.flushdb
  end

  context "instantiates with :limit, :time and :redis" do
    it "errors without these params" do
      expect { RateLimiter.new() }.to raise_error(ArgumentError)
    end

    it "creates a RateLimiter instance if given the correct params" do
      expect(limiter).to be_kind_of(RateLimiter)
    end
  end

  describe ":allowed?" do
    context "ip already requested" do
      context "within limt" do
        it "returns true if within limit" do
          limiter.check!(ip)
          expect(limiter.allowed?(ip)).to eq(true)
        end
      end
      context "outside of limit" do
        it "returns false if outside of limit" do
          10.times { limiter.check!(ip) }
          expect(limiter.allowed?(ip)).to eq(false)
        end
      end
    end

    context "new ip requesting" do
      it "returns true" do
        expect(limiter.allowed?("1.1.1.1")).to eq(true)
      end
    end
  end

  describe "#check!" do
    context "newly requesting ip" do
      it "is allowed and logs request correctly in redis" do
        new_ip = "2.2.2.2"
        new_record_count = limiter.check!(new_ip)
        expect(new_record_count).to eq(1)
      end
    end

    context "already requested ip" do
      context "inside of rate limit" do
        five_req_ip = "5.5.5.5"
        it "increments correctly" do
          4.times { limiter.check!(five_req_ip) }
          count = limiter.check!(five_req_ip)
          expect(count).to eq(5)
        end
      end
      
      context "outside of rate limit" do
        ten_req_ip = "10.10.10.10"
        it "raises RequestLimitReachedError" do
          9.times { limiter.check!(ten_req_ip) }
          count = limiter.check!(ten_req_ip)
          expect(count).to eq(10)
          expect { limiter.check!(ten_req_ip) }.to raise_error(RequestLimitReachedError)
        end

        it "the timeout allows the limit to reset" do
          short_limiter = RateLimiter.new(limit: 2, time: 1, redis: redis_instance)
          ip = "11.11.11.11"
          2.times { short_limiter.check!(ip) }

          expect(short_limiter.allowed?(ip)).to eq(false)
          sleep 1.1
          
          expect(short_limiter.allowed?(ip)).to eq(true)
        end
      end
    end
  end

  describe "#ttl" do
    context "for an IP that has requested" do
      it "returns the correct time to live until limit window resets" do
        fresh_ip = "12.12.1.1"
        limiter.check!(fresh_ip)
        expect(limiter.ttl(fresh_ip)).to eq(60)
        sleep 1.1
        expect(limiter.ttl(fresh_ip)).to eq(59)
      end
    end
    
    context "for an IP which has never requested" do
      it "returns the time value set on the limiter" do
        limiter_time_val = limiter.time
        new_ip = "13.13.1.1"

        expect(limiter.ttl(new_ip)).to eq(60)
      end
    end
  end

end