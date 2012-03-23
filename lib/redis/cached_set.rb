require File.dirname(__FILE__) + '/base_object'
require File.dirname(__FILE__) + '/set'

class Redis
  #
  # Class representing a Redis set that locally caches the entire set's
  # contents.
  #
  class CachedSet < ::Redis::Set
    attr_reader :cache

    def initialize(key, *args)
      super

      maybe_cache_values if self.options[:eager]
    end

    alias_method :uncached_members, :members

    def <<(value)
      @cache << value if cached?
      super
    end

    def add(value)
      @cache.add(value) if cached?
      super
    end

    def pop
      e = super
      @cache.delete(e) if cached?
      return e
    end

    def members
      maybe_cache_values
      return @cache.dup
    end
    alias_method :get, :members

    def member?(value)
      maybe_cache_values
      return @cache.member?(value)
    end
    alias_method :include?, :member?

    def delete(value)
      @cache.delete(value) if cached?
      super
    end

    # Delete if matches block
    def delete_if(&block)
      maybe_cache_values
      res = false
      @cache.each do |m|
        if block.call(m)
          @cache.delete(m)
          res = redis.srem(key, to_redis(m))
        end
      end
      res
    end

    def each(&block)
      maybe_cache_values
      @cache.each(&block)
    end

    def length
      maybe_cache_values
      @cache.size
    end
    alias_method :size, :length
    alias_method :count, :length

    def del
      @cache = []
      redis.del key
    end
    alias_method :clear, :del

    def cached?
      !@cache.nil?
    end

    def maybe_cache_values
      return if cached?
      @cache = ::Set.new(uncached_members)
    end
  end
end
