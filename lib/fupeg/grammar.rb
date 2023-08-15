# frozen_string_literal: true

require_relative "parser"

module FuPeg
  class Grammar
    def self.create(str, pos = 0)
      parser = Parser.new(str, pos)
      grammar = new(parser)
      [parser, grammar]
    end

    def self.parse(root, str)
      _, gr = create(str)
      gr.__send__(root)
    end

    def initialize(parser)
      @p = parser
    end

    def fail!
      @p.fail!(skip: 3)
    end

    def dot
      @p.match(/./m)
    end

    def `(str)
      @p.match(str)
    end

    def _(lit = nil, &block)
      @p.match(lit, &block)
    end

    def opt(arg = nil, &block)
      @p.match(arg, &block) || true
    end

    def will?(lit = nil, &block)
      @p.preserve(pos: true) { @p.match(lit, &block) }
    end

    def wont!(lit = nil, &block)
      @p.preserve(pos: true, failed: true) { !@p.match(lit, &block) } || @p.fail!
    end

    def text(lit = nil, &block)
      @p.text(lit, &block)
    end

    def bounds(lit = nil, &block)
      @p.bounds(lit, &block)
    end

    def cut(&block)
      @p.with_cut_point(&block)
    end

    def cut!
      @p.current_cutpoint.cut!
    end

    def cont?(&block)
      @p.current_cutpoint.can_continue? && (block ? @p.backtrack(&block) : true)
    end

    def rep(range = 0.., lit = nil, &block)
      range = range..range if Integer === range
      range = 0..range.max if range.begin.nil?
      unless Integer === range.min && (range.end.nil? || Integer === range.max)
        raise "Range malformed #{range}"
      end
      @p.backtrack do
        max = range.end && range.max
        ar = []
        (1..max).each do |i|
          res = @p.backtrack { yield i == 1 }
          break unless res
          ar << res
        end
        (ar.size >= range.min) ? ar : @p.fail!
      end
    end
  end
end
