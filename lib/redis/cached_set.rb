require File.dirname(__FILE__) + '/base_object'

class Redis
  attr_reader :cached
  #
  # Class representing a Redis set that locally caches the entire set's
  # contents.
  #
  class CachedSet < Set
    def initialize(key, *args)
      super

      maybe_cache_values if self.options[:eager]
    end

    alias_method :uncached_members, :members

    def <<(value)
      maybe_cache_values
      @cached << value
      super
    end

    def add(value)
      maybe_cache_values
      @cached.add(value)
      super
    end

    def pop
      maybe_cache_values
      e = super
      @cached.delete(e)
      return e
    end

    def members
      maybe_cache_values
      return @cached.dup
    end
    alias_method :get, :members

    def member?(value)
      maybe_cache_values
      return @cached.member?(value)
    end
    alias_method :include?, :member?

    def delete(value)
      maybe_cache_values
      @cached.delete(value)
      super
    end

    # Delete if matches block
    def delete_if(&block)
      maybe_cache_values
      res = false
      @cached.each do |m|
        if block.call(m)
          @cached.delete(m)
          res = redis.srem(key, to_redis(m))
        end
      end
      res
    end

    def each(&block)
      maybe_cache_values
      @cached.each(&block)
    end

    def length
      maybe_cache_values
      @cached.size
    end
    alias_method :size, :length
    alias_method :count, :length

    def del
      @cached = []
      redis.del key
    end
    alias_method :clear, :del

    def cached?
      !@cached.nil?
    end

    def maybe_cache_values
      return if cached?
      @cached = ::Set.new(uncached_members)
    end
  end
end
