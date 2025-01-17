module RailsStuff
  # Provides parsing and type-casting functions.
  # Reraises all ocured errors with Error class, so you can handle it together:
  #
  #     rescue_from RailsStuff::ParamsParser::Error, with: :render_bad_request
  #
  # You can define more parsing methods by extending with this module
  # and using .parse:
  #
  #     # models/params_parser
  #     module ParamsParser
  #       extend RailsStuff::ParamsParser
  #       extend self
  #
  #       def parse_money(val)
  #         parse(val) { your_stuff(val) }
  #       end
  #     end
  #
  module ParamsParser
    # This exceptions is wrapper for any exception occured in parser.
    # Original exception message can be retrieved with `original_message` method.
    class Error < ::StandardError
      attr_reader :original_message, :value

      def initialize(original_message = nil, value = nil)
        message = "Error while parsing: #{value.inspect}"
        @original_message = original_message || message
        @value = value
        super(message)
      end

      # Keeps message when passing instance to `raise`.
      def exception(*)
        self
      end

      # Show original messages in tests.
      def to_s
        "#{super} (#{original_message})"
      end
    end

    extend self

    # Parses value with specified block. Reraises occured error with Error.
    def parse(val)
      yield(val) unless val.nil?
    rescue => e
      raise Error.new(e.message, val), nil, e.backtrace
    end

    # Parses each value in array with specified block.
    # Returns `nil` if `val` is not an array.
    def parse_array(val)
      parse(val) { val.map { |x| yield x unless x.nil? } } if val.is_a?(Array)
    end

    # :method: parse_int
    # :call-seq: parse_int(val)
    #
    # Parse int value.

    # :method: parse_int_array
    # :call-seq: parse_int_array(val)
    #
    # Parses array of ints. Returns `nil` if `val` is not an array.

    # :method: parse_float
    # :call-seq: parse_float(val)
    #
    # Parse float value.

    # :method: parse_float_array
    # :call-seq: parse_float_array(val)
    #
    # Parses array of floats. Returns `nil` if `val` is not an array.

    # :method: parse_string
    # :call-seq: parse_string(val)
    #
    # Parse string value.

    # :method: parse_string_array
    # :call-seq: parse_string_array(val)
    #
    # Parses array of strings. Returns `nil` if `val` is not an array.

    # Parsers for generic types, which are implemented with #to_i, #to_f & #to_s
    # methods.
    %w(string int float).each do |type|
      block = :"to_#{type[0]}".to_proc

      define_method "parse_#{type}" do |val|
        parse(val, &block)
      end

      define_method "parse_#{type}_array" do |val|
        parse_array(val, &block)
      end
    end

    # Parse boolean using ActiveResord's parser.
    def parse_boolean(val)
      parse(val) do
        @boolean_parser ||= ActiveRecord::Type::Boolean.new
        @boolean_parser.type_cast_from_user(val)
      end
    end

    # Parse time in current TZ using `Time.parse`.
    def parse_datetime(val)
      parse(val) { Time.zone.parse(val) || raise('Invalid datetime') }
    end

    # Parse JSON string.
    def parse_json(val)
      parse(val) { JSON.parse(val) if val.present? }
    end
  end
end
