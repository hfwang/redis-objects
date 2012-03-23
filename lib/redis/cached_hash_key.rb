require File.dirname(__FILE__) + '/base_object'
require File.dirname(__FILE__) + '/hash_key'

class Redis
  attr_reader :cached

  #
  # Class representing a Redis hash that locally caches the entire hash's
  # contents.
  #
  class CachedHashKey < ::Redis::HashKey
    def initialize(key, *args)
      super
      maybe_cache_values if self.options[:eager]
    end

    def store(field, value)
      @cached[field.to_s] = value if cached?
      super
    end
    alias_method :[]=, :store
    alias_method :fetch, :[]=

    def [](field)
      maybe_cache_values
      @cached[field.to_s]
    end

    def has_key?(field)
      maybe_cache_values
      @cached.has_key? field.to_s
    end
    alias_method :include?, :has_key?
    alias_method :key?, :has_key?
    alias_method :member?, :has_key?

    def delete(field)
      @cached.delete(field.to_s) if cached?
      super
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
      @cached = {}
      super
    end

    def bulk_set(*args)
      @cached.update(*args) if cached?
      super
    end
    alias_method :update, :bulk_set

    def incrby(field, val = 1)
      maybe_cache_values
      @cached[field.to_s] = super(field, val)
    end
    alias_method :incr, :incrby

    def cached?
      !@cached.nil?
    end

    def maybe_cache_values
      return if cached?

      @cached = self.all()
    end
  end
end
