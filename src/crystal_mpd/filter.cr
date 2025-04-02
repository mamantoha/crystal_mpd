module MPD
  class Filter
    @parts : Array(String)

    def initialize
      @parts = [] of String
    end

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

    # == / !=
    def eq(tag : String, value : String)
      add(tag, "==", value)
    end

    def not_eq(tag : String, value : String)
      add(tag, "!=", value)
    end

    # =~ / !~
    def match(tag : String, value : String)
      add(tag, "=~", value)
    end

    def not_match(tag : String, value : String)
      add(tag, "!~", value)
    end

    OPERATORS = [
      "eq_cs",
      "eq_ci",
      "contains",
      "contains_cs",
      "contains_ci",
      "starts_with",
      "starts_with_cs",
      "starts_with_ci",
    ]

    {% for operator in OPERATORS %}
      def {{operator.id}}(tag : String, value : String)
        add(tag, "{{operator.id}}", value)
      end

      def not_{{operator.id}}(tag : String, value : String)
        add_neg(tag, "{{operator.id}}", value)
      end
    {% end %}

    # Logical NOT for nested filters
    def not(expr : Filter)
      @parts << "(!#{expr.to_s})"
      self
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

    # Static constructor usage
    def self.eq(tag : String, value : String) : Filter
      new.eq(tag, value)
    end
  end
end
