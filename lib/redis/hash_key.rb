require File.dirname(__FILE__) + '/base_object'

class Redis
  #
  # Class representing a Redis hash.
  #
  class HashKey < BaseObject
    require 'enumerator'
    include Enumerable
    require 'redis/helpers/core_commands'
    include Redis::Helpers::CoreCommands
    require 'redis/helpers/serialize'
    include Redis::Helpers::Serialize

    attr_reader :key, :options, :redis

    def initialize(key, *args)
      super
      marshal_keys = Hash.new { |hash, key| @options[:marshal] }
      marshal_keys.update(@options[:marshal_keys]) if @options[:marshal_keys]
      @options[:marshal_keys] = marshal_keys
      @options[:key_marshaller] ||= String
    end

    # Needed since Redis::Hash masks bare Hash in redis.rb
    def self.[](*args)
      ::Hash[*args]
    end

    # Sets a field to value
    def []=(field, value)
      store(field, value)
      return value
    end

    # Redis: HSET
    def store(field, value)
      redis.hset(key, to_field_name(field),
                 to_redis(value, options[:marshal_keys][field]))
    end

    # Redis: HGET
    def fetch(field)
      from_redis(redis.hget(key, to_field_name(field)),
                 options[:marshal_keys][field])
    end
    alias_method :[], :fetch

    # Verify that a field exists. Redis: HEXISTS
    def has_key?(field)
      redis.hexists(key, to_field_name(field))
    end
    alias_method :include?, :has_key?
    alias_method :key?, :has_key?
    alias_method :member?, :has_key?

    # Delete field. Redis: HDEL
    def delete(field)
      redis.hdel(key, to_field_name(field))
    end

    # Return all the keys of the hash. Redis: HKEYS
    def keys
      redis.hkeys(key)
    end

    # Return all the values of the hash. Redis: HVALS
    def values
      from_redis redis.hvals(key)
    end
    alias_method :vals, :values

    # Retrieve the entire hash.  Redis: HGETALL
    def all
      h = {}
      (redis.hgetall(key) || {}).each do |k,v|
        k = from_field_name(k)
        h[k] = from_redis(v, options[:marshal_keys][k])
      end
      h
    end
    alias_method :clone, :all

    # Enumerate through all fields. Redis: HGETALL
    def each(&block)
      all.each(&block)
    end

    # Enumerate through each keys. Redis: HKEYS
    def each_key(&block)
      keys.each(&block)
    end

    # Enumerate through all values. Redis: HVALS
    def each_value(&block)
      values.each(&block)
    end

    # Return the size of the dict. Redis: HLEN
    def size
      redis.hlen(key)
    end
    alias_method :length, :size
    alias_method :count, :size

    # Returns true if dict is empty
    def empty?
      true if size == 0
    end

    # Clears the dict of all keys/values. Redis: DEL
    def clear
      redis.del(key)
    end

    # Set keys in bulk, takes a hash of field/values {'field1' => 'val1'}. Redis: HMSET
    def bulk_set(*args)
      raise ArgumentError, "Argument to bulk_set must be hash of key/value pairs" unless args.last.is_a?(::Hash)
      redis.hmset(key, *args.last.inject([]){ |arr, kv|
        k = to_field_name(kv[0])
        arr + [k, to_redis(kv[1], options[:marshal_keys][kv[0]])]
      })
    end
    alias_method :update, :bulk_set

    # Set keys in bulk if they do not exist. Takes a hash of field/values {'field1' => 'val1'}. Redis: HSETNX
    def fill(pairs={})
      raise ArgumentError, "Argument to fill must be a hash of key/value pairs" unless pairs.is_a?(::Hash)
      pairs.each do |field, value|
        redis.hsetnx(key, to_field_name(field),
                     to_redis(value, options[:marshal_keys][field]))
      end
    end

    # Get keys in bulk, takes an array of fields as arguments. Redis: HMGET
    def bulk_get(*fields)
      hsh = {}
      res = redis.hmget(key, *fields.flatten.map {|k| to_field_name(k)})
      fields.each do |k|
        hsh[k] = from_redis(res.shift, options[:marshal_keys][k])
      end
      hsh
    end

    # Increment value by integer at field. Redis: HINCRBY
    def incrby(field, val = 1)
      ret = redis.hincrby(key, to_field_name(field), val)
      unless ret.is_a? Array
        ret.to_i
      else
        nil
      end
    end
    alias_method :incr, :incrby

    def to_field_name(field)
      to_redis!(field, options[:key_marshaller])
    end

    def from_field_name(field)
      from_redis!(field, options[:key_marshaller])
    end
  end
end
