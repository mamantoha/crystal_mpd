module MPD
  class Filter
    @parts : Array(String)

    def initialize
      @parts = [] of String
    end

    private def add(tag : String, op : String, value : String)
      @parts << "(#{tag} #{op} '#{value}')"
      self
    end

    private def add_neg(tag : String, op : String, value : String)
      @parts << "(!(#{tag} #{op} '#{value}'))"
      self
    end

    # == / !=
    def eq(tag : String, value : String)
      add(tag, "==", value)
    end

    def not_eq(tag : String, value : String)
      add(tag, "!=", value)
    end

    def eq_cs(tag : String, value : String)
      add(tag, "eq_cs", value)
    end

    def eq_ci(tag : String, value : String)
      add(tag, "eq_ci", value)
    end

    def not_eq_cs(tag : String, value : String)
      add_neg(tag, "eq_cs", value)
    end

    def not_eq_ci(tag : String, value : String)
      add_neg(tag, "eq_ci", value)
    end

    # contains
    def contains(tag : String, value : String)
      add(tag, "contains", value)
    end

    def not_contains(tag : String, value : String)
      add_neg(tag, "contains", value)
    end

    def contains_cs(tag : String, value : String)
      add(tag, "contains_cs", value)
    end

    def contains_ci(tag : String, value : String)
      add(tag, "contains_ci", value)
    end

    def not_contains_cs(tag : String, value : String)
      add_neg(tag, "contains_cs", value)
    end

    def not_contains_ci(tag : String, value : String)
      add_neg(tag, "contains_ci", value)
    end

    # starts_with
    def starts_with(tag : String, value : String)
      add(tag, "starts_with", value)
    end

    def not_starts_with(tag : String, value : String)
      add_neg(tag, "starts_with", value)
    end

    def starts_with_cs(tag : String, value : String)
      add(tag, "starts_with_cs", value)
    end

    def starts_with_ci(tag : String, value : String)
      add(tag, "starts_with_ci", value)
    end

    def not_starts_with_cs(tag : String, value : String)
      add_neg(tag, "starts_with_cs", value)
    end

    def not_starts_with_ci(tag : String, value : String)
      add_neg(tag, "starts_with_ci", value)
    end

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
