# frozen_string_literal: true

require "strscan"

module FuPeg
  class Parser
    def initialize(str, pos = 0)
      reset!(str, pos)
    end

    def reset!(str = nil, pos = nil)
      if str
        @str = str.dup
        @str_size = str.size
        init_line_ends
        @scan = StringScanner.new(str)
      end
      if pos
        @scan.pos = pos
      end
      @failed = nil
      @cut = CutPoint.new
    end

    attr_reader :failed

    def bytepos
      @scan.pos
    end

    def charpos
      @str_size - @str.byteslice(@scan.pos..).size
    end

    Fail = Struct.new(:stack, :pos, :bytepos)

    def fail!(skip = 2)
      if !@failed || bytepos > @failed.bytepos
        stack = caller_locations(skip)
        stack.delete_if do |loc|
          if loc.path == __FILE__
            loc.label =~ /\b(_bt|each|block)\b/
          end
        end
        pos = position_for_charpos(charpos)
        @failed = Fail.new(stack, pos, bytepos)
      end
      nil
    end

    def report_failed(out)
      pos = @failed.pos
      out << "Failed at #{pos.lineno}:#{pos.colno} :\n"
      out << pos.line + "\n"
      out << (" " * (pos.colno - 1) + "^\n")
      out << "Call stack:\n"
      @failed.stack.each do |loc|
        out << "#{loc.path}:#{loc.lineno} in #{loc.label}\n"
      end
      out
    end

    def dot
      @scan.scan(/./m) || fail!
    end

    begin
      StringScanner.new("x").skip("x")
      def lit(reg_or_str)
        @scan.scan(reg_or_str) || fail!
      end
    rescue
      def lit(reg_or_str)
        if String === reg_or_str
          @__match_lit_cache ||= Hash.new { |h, s| h[s] = Regexp.new(Regexp.escape(s)) }
          reg_or_str = @__match_lit_cache[reg_or_str]
        end
        @scan.scan(reg_or_str) || fail!
      end
    end

    def seq(*args, &block)
      _bt(&block)
    end

    def opt(&block)
      _rewind(nil, @failed, _bt(&block) || true)
    end

    def rep(range = 0.., &block)
      range = range..range if Integer === range
      range = 0..range.max if range.begin.nil?
      unless Integer === range.min && (range.end.nil? || Integer === range.max)
        raise "Range malformed #{range}"
      end
      _bt do
        max = range.end && range.max
        ar = []
        (1..max).each do
          res = _bt(&block)
          break unless res
          ar << res
        end
        (ar.size >= range.min) ? ar : fail!
      end
    end

    def text(&block)
      pos = @scan.pos
      _bt(&block) && @str.byteslice(pos, @scan.pos - pos)
    end

    def will?(&block)
      _rewind(@scan.pos, false, _bt(&block))
    end

    def wont!(&block)
      _rewind(@scan.pos, @failed, !_bt(&block)) || fail!
    end

    # cut point handling
    #   cut do
    #     seq { lit("{") && cut! && lit("}") } ||
    #     !cut? && seq { lit("[") && cut! && lit("]") } ||
    #     !cut? && dot
    #   end
    class CutPoint
      attr_accessor :next

      def initialize
        @cut = false
        @next = nil
      end

      def cut!
        @next&.cut!
        @cut = true
      end

      def cut?
        @cut
      end
    end

    # for use with cut! and cut?
    def cut
      prev_cut = @cut
      @cut = CutPoint.new
      prev_cut.next = @cut
      yield @cut
    ensure
      prev_cut.next = nil
      @cut = prev_cut
    end

    def cut!
      @cut.cut!
    end

    def cut?
      @cut.cut?
    end

    # Position handling for failures

    Position = Struct.new(:lineno, :colno, :line, :charpos)

    private

    def init_line_ends
      @line_ends = [-1]
      pos = 0
      while (pos = @str.index("\n", pos))
        @line_ends << @pos
        pos += 1
      end
      @line_ends << @str.size
    end

    public

    def position_for_charpos(charpos)
      lineno = @line_ends.bsearch_index { |x| x >= charpos }
      case lineno
      when nil
        raise "Position #{charpos} is larger than string size #{@str.size}"
      else
        prev_end = @line_ends[lineno - 1]
        line_start = prev_end + 1
        column = charpos - prev_end
      end
      line = @str[line_start..@line_ends[lineno]]
      Position.new(lineno, column, line, charpos)
    end

    # helper methods

    private

    def _bt
      pos = @scan.pos
      res = yield
      if res
        @failed = nil if @failed && @failed.bytepos <= @scan.pos
        res
      else
        @scan.pos = pos
        nil
      end
    rescue
      @scan.pos = pos
      raise
    end

    def _rewind(pos, failed, val)
      @scan.pos = pos if pos
      @failed = failed if failed != false
      val
    end
  end
end
