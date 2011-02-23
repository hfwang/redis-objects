
# If available, use the superfast YAJL lib to parse JSON.
begin
  require 'yajl/json_gem'
rescue LoadError
  require 'json'
end
require 'digest/md5'

# Inherit from Redis::Objects::Model for model like behavior.
class Redis
  module Objects
    module V
      class AttributeRequired < StandardError; end #:nodoc:
      class AttributeNotSpecified < StandardError; end #:nodoc:
      class ValidationError < StandardError; end #:nodoc:

      def self.required
        lambda { |k,v| 
          raise AttributeRequired, "Required attribute #{k} is missing" unless v
        }
      end

      def self.length(min=0, max=1000)
        lambda { |k,v| raise ValidationError, "#{k} should be between #{min} and #{max} but is #{v.length}" unless !v || min <= v.length && v.length <= max }
      end
    end

    # A schema defines allowed keys and validations for saving to a 
    # Redis::Object::Hash in `attrs`
    class Schema
      attr_reader :marshal_options

      def initialize(klass=nil, &block)
        @klass = klass
        @marshal_options = {}
        @keys = {}
        self.instance_eval(&block)
      end

      def validate(attrs)
        raise Redis::Objects::V::ValidationError, "Invalid attributes provided" unless attrs
        attrs.each do |k,v|
          raise Redis::Objects::V::AttributeNotSpecified, "Attribute #{k} is not in the schema" unless @keys.include?(k)
        end
        @keys.each do |k,validations|
          (validations || []).each do |v|
            if v.respond_to?(:call) 
              v.call(k, attrs[k])
            else
              raise unless !attrs[k] || attrs[k].is_a?(v)
            end
          end
        end
        true
      end

      def method_missing(name, *args)
        name = if name[-1]=="!"
          args.insert(0, Redis::Objects::V.required) 
          name[0..-2]
        else
          name.to_s
        end
        options = args.last.is_a?(::Hash) ? args.pop : {}
        if options[:marshal]
          @marshal_options[name] = options[:marshal]
        end
        @keys[name] = args
      end
    end

    # Inherit from Model for model like behavior.
    # Attributes will be stored in a Hash in the attribute :attrs
    class Model 
      include Redis::Objects

      def self.inherited(c)
        c.send(:include, Redis::Objects)
      end

      def self.prefix(key)
        #redis_field_key(key)
        "#{self.redis_prefix(self)}::#{key}"
      end

      class << self
        attr_accessor :key_length
      end

      # Specify that keys should be handled here
      def self.key(type)
        define_method(:id) {
          @id ||= redis.incr(self.class.prefix('ids'))
        }
        if type.respond_to?(:has_key?) && type.has_key?(:length)
          self.key_length = type[:length]
        end
      end

      # Return the keys newest to oldest
      def self.keys(first=0, num=100)
        redis.zrevrange(prefix('created_at'), first, first+num)
      end

      # Return instances of the model, newest to oldest
      def self.all(first=0, num=100)
        keys(first, num).map { |key| self.new(key) }
      end

      # Number of objects
      def self.count
        redis.zcard(prefix('created_at'))
      end

      # Pass in a block to define the model schema
      def self.schema(&block)
        @schema = Schema.new(self, &block) if block_given?
        @schema
      end

      def self.create(id, attrs)
        m = self.new(id)
        raise "Already exists" if m.exists?
        m.save(attrs)
      end

      # Returns a new model instance if the key exists, else nil
      def self.get(id)
        m = self.new(id)
        m.exists? ? m : nil
      end

      # Default is an optional id
      def initialize(id=nil)
        @id = id
      end

      def exists?
        self.redis.exists(attrs.key) 
      end

      def prefix(key, theid=nil)
        "#{self.class.redis_prefix(self.class)}:#{theid || id}:#{key}"
      end

      def attrs
        @attrs ||= Redis::Hash.new(prefix('attrs'), Model.redis,
          {:marshal_keys=>self.class.schema.marshal_options}
        )
      end

      def to_json
        {:id => id}.merge(self.attrs.all).to_json
      end

      # validate and save
      def save(attrs)
        self.class.schema.validate(attrs)
        new = !exists?
        self.attrs.bulk_set(attrs)
        if new
          if self.class.key_length
            i=0; found=false
            while !found && i < 1000 do
              newid = Digest::MD5.hexdigest(rand.to_s)[0..self.class.key_length-1]
              if redis.renamenx(self.attrs.key, prefix('attrs', newid))
                @id = newid
                @attrs = nil
                found = true
              end
              i += 1
            end
          end
          redis.zadd(self.class.prefix('created_at'), Time.now.to_i, id)
        end
        self
      end

      def destroy
        return unless exists?
        self.attrs.clear
        redis.zrem(self.class.prefix('created_at'), id)
      end
    end
  end
end



