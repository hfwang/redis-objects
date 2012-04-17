require File.dirname(__FILE__) + '/base_object'
require 'active_model'

class Redis
  module Model
    # Generic Redis::Model exception class
    class RecordNotFound < StandardError
    end

    def self.included(klass)
      klass.send :include, Redis::Objects
      klass.extend ClassMethods
      klass.send :counter, :id_generator, :global => true

      klass.extend ActiveModel::Callbacks
      klass.define_model_callbacks :create
      klass.define_model_callbacks :save
      klass.define_model_callbacks :destroy
    end

    def initialize(new_attrs = {})
      @attributes = Hash.new { |h, k|
        old_attributes[k] || self.class.defaults[k]
      }

      # Symbolize keys and merge in preset values
      symbolized_keys = {}
      new_attrs.each do |k, v|
        symbolized_keys[k.to_sym] = v
      end
      @attributes.update(symbolized_keys)

      old_attributes.maybe_cache_values if @attributes.has_key?(:id)
    end

    def save
      run_callbacks :save do

        if !@attributes.has_key?(:id)
          run_callbacks :create do
            self.id = self.class.claim_next_id
          end
        end

        old_attributes.update(@attributes)
        @attributes.clear
      end
    end

    def destroy
      run_callbacks :destroy do
        old_attributes.clear
      end
    end

    def redis_key
      old_attributes.key
    end

    module ClassMethods
      def create(attrs)
        m = self.new(attrs)
        m.save
        return m
      end

      def find(id)
        record = self.new(:id => id)
        unless record.old_attributes.has_key? :id
          raise RecordNotFound, "Couldn't find #{name} with id=#{id}"
        end
        return record
      end

      def last_generated_id
        return self.id_generator.value
      end

      def claim_next_id
        return self.id_generator.increment
      end

      def attributes
        @attributes
      end

      def defaults
        @defaults ||= {}
      end

      def defaults=(value)
        @defaults = value
      end

      def persistent_attributes(attributes = {}, redis_options = {})
        raise "Already defined the persistent attributes!" if @attributes

        @attributes = {:id => Integer}.update(attributes)
        if @attributes.respond_to? :with_indifferent_access
          @attributes = @attributes.with_indifferent_access
        end

        @attributes.keys.each do |attribute_name|
          name = attribute_name.to_s
          self.class_eval <<-EndMethods
            def #{name}
              @attributes[:#{name}]
            end

            def #{name}=(value)
              @attributes[:#{name}] = value
            end
          EndMethods
        end
        default_opts = {
            :eager_load => true,
            :key_marshaller => Symbol,
            :marshal_keys => @attributes,
            :key => Proc.new { |r| "#{r.class.to_s}:#{r.id}" }
          }
        self.send(:cached_hash_key, :old_attributes,
                  default_opts.merge(redis_options))
      end
    end
  end
end
