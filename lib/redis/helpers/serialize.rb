class Redis
  module Helpers
    module Serialize
      include Marshal

      def to_redis(value, marshal=false)
        return value unless marshal_option = options[:marshal] || marshal
        if [String, Integer, Float].any? { |k| marshal_option == k }
          return value
        elsif marshal_option == true
          return dump(value)
        else
          return marshal_option.dump(value)
        end
      end

      def from_redis(value, marshal=false)
        return value unless marshal_option = options[:marshal] || marshal
        if marshal_option.equal? true
          case value
          when Array
            value.collect{|v| from_redis(v, marshal_option)}
          when Hash
            value.inject({}) { |h, (k, v)| h[k] = from_redis(v, marshal_option); h }
          else
            restore(value) rescue value
          end
        else
          if marshal_option == Integer
            value.to_i
          elsif marshal_option == Float
            value.to_f
          else
            marshal_option.restore(value) rescue value
          end
        end
      end
    end
  end
end
