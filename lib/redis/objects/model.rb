# 
# Inherit from Redis::Objects::Model for model like behavior.
class Redis
  module Objects
    module V
      def self.required
        lambda { |val| raise unless val }
      end

      def self.length(min=0, max=1000)
        lambda { |v| raise unless !v || min <= v.length && v.length <= max }
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
        attrs.each do |k,v|
          raise unless @keys.include?(k)
        end
        @keys.each do |k,validations|
          (validations || []).each do |v|
            if v.respond_to?(:call) 
              v.call(attrs[k])
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
          @marshal_options[name] = true
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

      # Pass in a block to define the model schema
      def self.schema(&block)
        @schema = Schema.new(self, &block) if block_given?
        @schema
      end

      # Returns a new model instance if the key exists, else nil
      def self.get(id)
        m = self.new(id)
        self.redis.exists(m.attrs.key) ? m : nil
      end

      def attrs
        @attrs ||= Redis::Hash.new(
          "#{self.class.redis_prefix(self.class)}:#{id}:attrs",
          Model.redis,
          {:marshal_keys=>self.class.schema.marshal_options}
        )
      end

      # validate and save
      def save(attrs)
        self.class.schema.validate(attrs)
        self.attrs.bulk_set(attrs)
      end

    end
  end
end



