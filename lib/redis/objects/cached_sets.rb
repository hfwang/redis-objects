# This is the class loader, for use as "include Redis::Objects::CachedSets"
# For the object itself, see "Redis::CachedSet"
require 'redis/cached_set'
class Redis
  module Objects
    module CachedSets
      def self.included(klass)
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end

      # Class methods that appear in your class when you include Redis::Objects.
      module ClassMethods
        # Define a new simple cached_set.  It will function like a regular instance
        # method, so it can be used alongside ActiveRecord, DataMapper, etc.
        def cached_set(name, options={})
          @redis_objects[name.to_sym] = options.merge(:type => :cached_set)
          klass_name = '::' + self.name
          if options[:global]
            instance_eval <<-EndMethods
              def #{name}
                @#{name} ||= Redis::CachedSet.new(redis_field_key(:#{name}), #{klass_name}.redis, #{klass_name}.redis_objects[:#{name}])
              end
            EndMethods
            class_eval <<-EndMethods
              def #{name}
                self.class.#{name}
              end
            EndMethods
          else
            class_eval <<-EndMethods
              def #{name}
                @#{name} ||= Redis::CachedSet.new(redis_field_key(:#{name}), #{klass_name}.redis, #{klass_name}.redis_objects[:#{name}])
              end
            EndMethods
          end

        end
      end

      # Instance methods that appear in your class when you include Redis::Objects.
      module InstanceMethods
      end
    end
  end
end
