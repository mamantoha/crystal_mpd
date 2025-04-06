module MPD
  class Filter
    @parts : Array(String)
    getter sort : String?
    getter window : MPD::Range?

    def initialize
      @parts = [] of String
    end

    # sorts the result by the specified tag
    def sort(tag : String)
      @sort = tag
      self
    end

    # :ditto:
    def sort(tag : MPD::Tag)
      @sort = tag.to_s.downcase
      self
    end

    # can be used to query only a portion of the real response
    def window(range : MPD::Range)
      @window = range
      self
    end

    # https://mpd.readthedocs.io/en/latest/protocol.html#escaping-string-values
    private def escape(value : String) : String
      value
        .gsub("\\", "\\\\")
        .gsub("'", "\\'")
        .gsub("\"", "\\\"")
    end

    private def add(tag : String, op : String, value : String)
      escaped = escape(value)
      @parts << "(#{tag} #{op} \"#{escaped}\")"
      self
    end

    private def add_neg(tag : String, op : String, value : String)
      escaped = escape(value)
      @parts << "(!(#{tag} #{op} \"#{escaped}\"))"
      self
    end

    # :nodoc:
    private COMPARISON_OPS = [
      {method: "eq", op: "=="},
      {method: "not_eq", op: "!="},
      {method: "match", op: "=~"},
      {method: "not_match", op: "!~"},
    ]

    {% for operator in COMPARISON_OPS %}
      def {{operator[:method].id}}(tag : String, value : String)
        add(tag, "{{operator[:op].id}}", value)
      end

      def {{operator[:method].id}}(tag : Tag, value : String)
        add(tag.to_s.downcase, "{{operator[:op].id}}", value)
      end

      def self.{{operator[:method].id}}(tag : String, value : String) : Filter
        new.{{operator[:method].id}}(tag, value)
      end

      def self.{{operator[:method].id}}(tag : Tag, value : String) : Filter
        new.{{operator[:method].id}}(tag.to_s.downcase, value)
      end
    {% end %}

    # :nodoc:
    private STRING_MATCH_OPS = [
      "eq_cs",
      "eq_ci",
      "contains",
      "contains_cs",
      "contains_ci",
      "starts_with",
      "starts_with_cs",
      "starts_with_ci",
    ]

    {% for operator in STRING_MATCH_OPS %}
      def {{operator.id}}(tag : String, value : String)
        add(tag, "{{operator.id}}", value)
      end

      def {{operator.id}}(tag : Tag, value : String)
        add(tag.to_s.downcase, "{{operator.id}}", value)
      end

      def self.{{operator.id}}(tag : String, value : String)
        new.{{operator.id}}(tag, value)
      end

      def self.{{operator.id}}(tag : Tag, value : String)
        new.{{operator.id}}(tag.to_s.downcase, value)
      end

      def not_{{operator.id}}(tag : String, value : String)
        add_neg(tag, "{{operator.id}}", value)
      end

      def not_{{operator.id}}(tag : Tag, value : String)
        add_neg(tag.to_s.downcase, "{{operator.id}}", value)
      end

      def self.not_{{operator.id}}(tag : String, value : String)
        new.not_{{operator.id}}(tag, value)
      end

      def self.not_{{operator.id}}(tag : Tag, value : String)
        new.not_{{operator.id}}(tag.to_s.downcase, value)
      end
    {% end %}

    # Logical NOT for nested filters
    def not(expr : Filter)
      @parts << "(!#{expr})"
      self
    end

    def self.not(expr : Filter)
      new.not(expr)
    end

    def to_s : String
      case @parts.size
      when 0
        ""
      when 1
        @parts.first
      else
        "(#{@parts.join(" AND ")})"
      end
    end

    def to_s(io : IO) : Nil
      io << to_s
    end
  end
end
