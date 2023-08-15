require "fupeg"

class Calc < FuPeg::Grammar
  def eof
    wont! { dot } && :eof
  end

  def lnsp?
    # match regular expression
    _(/[ \t]*/)
  end

  # Ruby 3.0 flavour
  def sp? = _(/\s*/)

  def number = (n = _(/\d+/)) && [:num, n]

  def atom
    # match raw string: _("(") is aliased to `(`
    #
    # match sequence of patterns with backtracking:
    #   `_{ x && y && z }` will rewind position, if block returns `nil` or `false`
    #
    # store value, returned by subpattern: just stor it into variable
    number || _ { _("(") && sp? && (sub = sum) && sp? && `)` && [:sub, sub] }
  end

  def fact
    # repetition returns array of block results
    # it stops if block returns falsey (`nil` or `false`)
    rep { |fst| # fst == true for first element
      op = nil
      (fst || (op = `*` || `/` || "%") && sp?) &&
        (a = atom) && lnsp? &&
        [op, a].compact
      # flat AST tree, returns [:fact, at, op, at, op, at, op] if matched
    }&.flatten(1)&.unshift(:fact)
  end

  def sum
    _ {
      op = rest = nil
      (f = fact) &&
        # optional matches pattern always succeed
        opt { lnsp? && (op = `+` || `-`) && sp? && (rest = sum) } &&
        # recursive AST tree
        (rest ? [:sum, f, op, rest] : f)
    }
  end

  def root
    _ { sum || eof }
  end
end

pp Calc.parse(:root, "1")
pp Calc.parse(:root, "1 + 2")

# separate parser and grammar initialization
parser = FuPeg::Parser.new("1 - 2*4/7 + 5")
grammar = Calc.new(parser)
pp grammar.root

# combined parser and grammar initialization
_parser, grammar = Calc.create("(1 -
                        2)*
                      (4 -10) +
11")
pp grammar.root
