class Redis
  module Helpers
    module Serialize
      include Marshal

      def to_redis(value, marshal=false)
        return value unless marshal_option = options[:marshal] || marshal
        if marshal_option == true
          case value
          when String, Fixnum, Bignum, Float
            value
          else
            dump(value)
          end
        else
          marshal_option.dump(value)
        end
      end
    
      def from_redis(value, marshal=false)
        return value unless marshal_option = options[:marshal] || marshal
        if marshal_option == true
          case value
          when Array
            value.collect{|v| from_redis(v)}
          when Hash
            value.inject({}) { |h, (k, v)| h[k] = from_redis(v); h }
          else
            restore(value) rescue value
          end
        else
          marshal_option.restore(value) rescue value
        end
      end
    end
  end
end
