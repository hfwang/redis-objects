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
      @cached[to_field_name(field)] = value if cached?
      super
    end
    alias_method :[]=, :store
    alias_method :fetch, :[]=

    def [](field)
      maybe_cache_values
      @cached[to_field_name(field)]
    end

    def has_key?(field)
      maybe_cache_values
      @cached.has_key?(to_field_name(field))
    end
    alias_method :include?, :has_key?
    alias_method :key?, :has_key?
    alias_method :member?, :has_key?

    def delete(field)
      @cached.delete(to_field_name(field)) if cached?
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

    def bulk_set(other_hash)
      if cached?
        other_hash.each do |k, v|
          @cached[to_field_name(k)] = v
        end
      end
      super
    end
    alias_method :update, :bulk_set

    def incrby(field, val = 1)
      maybe_cache_values
      @cached[to_field_name(field)] = super(field, val)
    end
    alias_method :incr, :incrby

    def cached?
      !@cached.nil?
    end

    def maybe_cache_values
      return @cached if cached?

      @cached = {}
      self.all().each do |k, v|
        @cached[to_field_name(k)] = v
      end
    end
  end
end
