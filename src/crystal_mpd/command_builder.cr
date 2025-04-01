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
        "#{arg.begin || 0}:#{arg.end || -1}"
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
