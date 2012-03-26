require File.dirname(__FILE__) + '/base_object'
require File.dirname(__FILE__) + '/hash_key'

class Redis
  #
  # Class representing a Redis hash that locally caches the entire hash's
  # contents.
  #
  class CachedHashKey < ::Redis::HashKey
    attr_reader :cache

    def initialize(key, *args)
      super
      maybe_cache_values if self.options[:eager]
    end

    def store(field, value)
      @cache[to_field_name(field)] = value if cached?
      super
    end
    alias_method :[]=, :store
    alias_method :fetch, :[]=

    def [](field)
      maybe_cache_values
      @cache[to_field_name(field)]
    end

    def has_key?(field)
      maybe_cache_values
      @cache.has_key?(to_field_name(field))
    end
    alias_method :include?, :has_key?
    alias_method :key?, :has_key?
    alias_method :member?, :has_key?

    def delete(field)
      @cache.delete(to_field_name(field)) if cached?
      super
    end

    def keys
      maybe_cache_values
      @cache.keys.map { |k| from_field_name(k) }
    end

    def values
      maybe_cache_values
      @cache.values
    end

    def each
      maybe_cache_values
      @cache.each do |k, v|
        yield from_field_name(k), v
      end
    end

    def each_key(&block)
      keys.each(&block)
    end

    def each_value(&block)
      values.each(&block)
    end

    def size
      maybe_cache_values
      @cache.size
    end
    alias_method :length, :size
    alias_method :count, :size

    def empty?
      true if size == 0
    end

    def clear
      @cache = {}
      super
    end

    def bulk_set(other_hash)
      if cached?
        other_hash.each do |k, v|
          @cache[to_field_name(k)] = v
        end
      end
      super
    end
    alias_method :update, :bulk_set

    def incrby(field, val = 1)
      maybe_cache_values
      @cache[to_field_name(field)] = super(field, val)
    end
    alias_method :incr, :incrby

    def cached?
      !@cache.nil?
    end

    def maybe_cache_values
      return @cache if cached?

      @cache = {}
      self.all().each do |k, v|
        @cache[to_field_name(k)] = v
      end
    end
  end
end
