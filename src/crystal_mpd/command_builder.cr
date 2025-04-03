module MPD
  class CommandBuilder
    def self.build(command : String, *args) : String
      parts = [command]
      args.each { |arg| parts << parse_arg(arg) }
      parts.join(" ")
    end

    private def self.parse_arg(arg) : String
      case arg
      when MPD::Range
        parse_range(arg)
      when Hash
        arg.join(" ") do |key, value|
          value = parse_range(value) if value.is_a?(MPD::Range)

          "#{key} #{value}"
        end
      when String
        %{"#{arg.gsub(%{\\}, %{\\\\}).gsub(%{"}, %{\\"})}"}
      when Int32
        arg.to_s
      else
        ""
      end
    end

    # Converts a Crystal Range into an MPD-compatible "START:END" string.
    #
    # `(0..20)` -> "0:20"
    # `(0...20)` -> "0:19"
    # `(..5)` -> "0:5"
    # `(5..)` -> "5:"
    def self.parse_range(range : MPD::Range) : String
      start = range.begin || 0
      end_ = range.end || nil

      if end_
        end_ -= 1 if range.exclusive?
        "#{start}:#{end_}"
      else
        "#{start}:"
      end
    end
  end
end
