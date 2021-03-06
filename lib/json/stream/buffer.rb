# encoding: UTF-8

module JSON
  module Stream

    # A character buffer that expects a UTF-8 encoded stream of bytes.
    # This handles truncated multi-byte characters properly so we can just
    # feed it binary data and receive a properly formatted UTF-8 String as
    # output. See here for UTF-8 parsing details:
    # http://en.wikipedia.org/wiki/UTF-8
    # http://tools.ietf.org/html/rfc3629#section-3
    class Buffer
      def initialize
        @state = :start
        @incomplete_buffer, @need = [], 0
        @complete_buffer = ''
      end

      # Fill the buffer with a String of binary UTF-8 encoded bytes. Returns
      # as much of the data in a UTF-8 String as we have. Truncated multi-byte
      # characters are saved in the buffer until the next call to this method
      # where we expect to receive the rest of the multi-byte character.
      def <<(data)
        bytes = []
        data.bytes.each do |b|
          case @state
          when :start
            if b < 128
              bytes << b
            elsif b >= 192
              @state = :multi_byte
              @incomplete_buffer << b
              @need = case
                when b >= 240 then 4
                when b >= 224 then 3
                when b >= 192 then 2 end
            else
              error('Expected start of multi-byte or single byte char')
            end
          when :multi_byte
            if b > 127 && b < 192
              @incomplete_buffer << b
              if @incomplete_buffer.size == @need
                bytes += @incomplete_buffer.slice!(0, @incomplete_buffer.size)
                @state = :start
              end
            else
              error('Expected continuation byte')
            end
          end
        end
        @complete_buffer << bytes.pack('C*').force_encoding(Encoding::UTF_8).tap do |str|
          error('Invalid UTF-8 byte sequence') unless str.valid_encoding?
        end
        nil
      end

      def next_character
        @complete_buffer.slice!(0)
      end

      def empty?
        @complete_buffer.size == 0
      end

      private

      def error(message)
        raise ParserError, message
      end
    end

  end
end
