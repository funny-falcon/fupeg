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

    def self.use_gram(gram, *, as: nil)
      if as.nil?
        name = gram.name[/\w+$/]
        name = name.gsub(/(?<!^)(?=[A-Z](?![A-Z\d_]))/, "_").downcase
        as = :"@#{name}"
      elsif !as.start_with?("@")
        as = :"@#{as}"
      end
      @used_grams ||= {}
      @used_grams[as] = gram
    end

    def self.proxy(*meths, to:)
      meths.each do |meth|
        define_method(meth) { |*args, &block|
          instance_variable_get(to).__send__(meth, *args, &block)
        }
      end
    end

    def self.used_grams
      @used_grams&.dup || {}
    end

    def initialize(parser)
      @p = parser
      self.class.used_grams.each do |iv, v|
        instance_variable_set(iv, v.new(parser))
      end
    end

    def fail!(bytepos: @p.bytepos, pat: nil)
      @p.fail!(bytepos: bytepos, pat: pat, skip: 3)
    end

    def dot
      @p.dot
    end

    def _(lit = nil, &block)
      @p.match(lit, &block)
    end

    def opt(arg = nil, &block)
      @p.match(arg, &block) || true
    end

    def will?(lit = nil, &block)
      @p.look_ahead(true, lit, &block)
    end

    def wont!(lit = nil, &block)
      @p.look_ahead(false, lit, &block)
    end

    def txt(lit = nil, &block)
      @p.text(lit, &block)
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
      @p.repetition(range, lit, &block)
    end

    # specialized matchers

    def eof
      @p.eof? && :eof
    end

    def nl
      _(/\r\n|\r|\n/)
    end

    def eol
      _ { lnsp? && nl && :eol }
    end

    def lnsp?
      _(/[ \t]*/)
    end

    def lnsp!
      _(/[ \t]+/)
    end

    def sp!
      _(/\s+/)
    end

    def sp?
      _(/\s*/)
    end

    def ident
      (w = ident_only) && token_sp? && w
    end

    # raw token match
    # if token is ident, then exact match performed with whole next ident
    # else only string match
    # and then whitespace is consumed
    def `(token)
      @p.match {
        if self.class._is_ident?(token)
          pos = @p.bytepos
          ident_only == token || fail!(bytepos: pos, pat: token)
        else
          @p.match(token)
        end && token_sp? && token
      }
    end

    def self._is_ident?(tok)
      @_is_ident ||= Hash.new { |h, k|
        h[k] = parse(:ident_only, k) == k
      }
      @_is_ident[tok]
    end

    def ident_only
      txt(/[a-zA-Z_]\w*/)
    end

    def token_sp?
      _(/\s*/)
    end
  end
end
