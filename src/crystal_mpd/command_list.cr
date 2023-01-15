module MPD
  struct CommandList
    property commands = [] of String
    property? active : Bool = false

    def add(command : String)
      @commands << command
    end

    def begin
      @active = true
    end

    def reset
      @commands.clear
      @active = false
    end
  end
end
