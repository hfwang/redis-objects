require File.dirname(__FILE__) + '/base_object'

class Redis
  attr_reader :hash_key, :cached

  #
  # Class representing a Redis hash that locally caches the entire hash's
  # contents.
  #
  class CachedHashKey
    def initialize(key, *args)
      @hash_key = Redis::HashKey.new(key, *args)

      maybe_cache_values if @hash_key.options[:eager]
    end

    def []=(field, value)
      maybe_cache_values
      @cached[field.to_s] = value
      @hash_key[field.to_s] = value
    end
    alias_method :store, :[]=

    def [](field)
      maybe_cache_values
      @cached[field.to_s]
    end
    alias_method :fetch, :[]=

    def has_key?(field)
      maybe_cache_values
      @cached.has_key? field.to_s
    end
    alias_method :include?, :has_key?
    alias_method :key?, :has_key?
    alias_method :member?, :has_key?

    def delete(field)
      maybe_cache_values
      @cached.delete(field.to_s)
      @hash_key.delete(field)
    end

    def keys
      maybe_cache_values
      @cached.keys
    end

    def values
      maybe_cache_values
      @cached.values
    end

    def each(&block)
      maybe_cache_values
      @cached.each(&block)
    end

    def each_key(&block)
      keys.each(&block)
    end

    def each_value(&block)
      values.each(&block)
    end

    def size
      maybe_cache_values
      @cached.size
    end
    alias_method :length, :size
    alias_method :count, :size

    def empty?
      true if size == 0
    end

    def clear
      @cached = nil
      @hash_key.clear
    end

    def bulk_set(*args)
      maybe_cache_values
      @cached.update(*args)
      @hash_key.bulk_set(*args)
    end
    alias_method :update, :bulk_set

    def incrby(field, val = 1)
      maybe_cache_values
      @cached[field.to_s] = @hash_key.incrby(field, val)
    end
    alias_method :incr, :incrby

    def cached?
      !@cached.nil?
    end

    def maybe_cache_values
      return if cached?

      @cached = @hash_key.all()
    end
  end
end
