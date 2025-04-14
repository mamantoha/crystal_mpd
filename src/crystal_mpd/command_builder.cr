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
        escape_string(arg)
      when MPD::Filter
        escape_string(arg.to_s)
      when Int32
        arg.to_s
      else
        ""
      end
    end

    private def self.escape_string(str)
      %{"#{str.gsub(%(\\), %(\\\\)).gsub(%("), %(\\"))}"}
    end

    # Converts a Crystal Range into an MPD-compatible "START:END" string.
    #
    # MPD treats the range as exclusive, so:
    # - Inclusive ranges (e.g., 0..2) must be converted to "0:3" to include index 2
    # - Exclusive ranges (e.g., 0...2) are used directly as "0:2"
    #
    # Examples:
    #   `(0..20)`   -> "0:21"
    #   `(0...20)`  -> "0:20"
    #   `(..5)`     -> "0:6"
    #   `(5..)`     -> "5:"
    def self.parse_range(range : MPD::Range) : String
      start = range.begin || 0
      finish = range.end

      if finish
        finish += 1 unless range.exclusive?
        "#{start}:#{finish}"
      else
        "#{start}:"
      end
    end
  end
end
