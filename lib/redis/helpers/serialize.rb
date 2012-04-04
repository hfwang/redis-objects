class Redis
  module Helpers
    module Serialize
      include Marshal

      def to_redis(value, marshal=nil)
        to_redis!(value, marshal.nil? ? options[:marshal] : marshal)
      end

      def to_redis!(value, marshal_option)
        return value unless marshal_option
        if [Symbol, String, Integer, Float].any? { |k| marshal_option == k }
          return value.to_s
        elsif marshal_option == true
          return dump(value)
        else
          return marshal_option.dump(value)
        end
      end

      def from_redis(value, marshal=nil)
        from_redis!(value, marshal.nil? ? options[:marshal] : marshal)
      end

      def from_redis!(value, marshal_option)
        return value unless marshal_option

        case value
        when NilClass
          nil
        when Array
          value.collect{|v| from_redis!(v, marshal_option)}
        when Hash
          value.inject({}) { |h, (k, v)| h[k] = from_redis!(v, marshal_option); h }
        else
          if marshal_option == Symbol
            value.to_sym
          elsif marshal_option == Integer
            value.to_i
          elsif marshal_option == Float
            value.to_f
          elsif marshal_option === true
            restore(value) rescue value
          elsif marshal_option.respond_to?(:load)
            marshal_option.load(value) rescue value
          else
            marshal_option.restore(value) rescue value
          end
        end
      end
    end
  end
end
