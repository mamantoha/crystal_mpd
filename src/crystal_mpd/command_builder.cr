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
        MPD.parse_range(arg)
      when Hash
        arg.map { |key, value| "#{key} #{value}" }.join(" ")
      when String
        %{"#{arg.gsub(%{\\}, %{\\\\}).gsub(%{"}, %{\\"})}"}
      when Int32
        arg.to_s
      else
        ""
      end
    end
  end
end
