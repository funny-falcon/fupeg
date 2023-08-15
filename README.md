# Fupeg - simplest parser combinator

PEG like parser combinator as simple as possible, but still useful.
- backtracking, manually specified by user.
- no memoization (yet).
- no left recursion (yet).
- built with StringScanner.
- pattern sequences and alteration are implemented with logical operators.

Grammar code is pure-ruby and is executed as it is written.
No grammar tree is built and evaluated.

As bonus, "cut" operator is implemented.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add fupeg

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install fupeg

## Usage

First you should define grammar:

```ruby
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
    #
    # use `||` for alternatives
    number || _ { _("(") && sp? && (sub = sum) && sp? && `)` && [:sub, sub] }
  end

  def fact
    # repetition returns array of block results
    # it stops if block returns falsey (`nil` or `false`)
    rep { |fst| # fst == true for first element
      op = nil
      # don't expect operator before first term
      (fst || (op = `*` || _("/") || _(/%/)) && sp?) &&
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
```

Then either parse string directly, or create parser and grammar:

```ruby
# Direct parsing
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
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/funny-falcon/fupeg .

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
