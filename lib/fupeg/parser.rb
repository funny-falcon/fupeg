# frozen_string_literal: true

require "strscan"

module FuPeg
  class Parser
    attr_accessor :debug
    attr_accessor :file
    attr_reader :failed
    attr_reader :str

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
      @debug = false
      @cut = CutPoint.new
    end

    def bytepos
      @scan.pos
    end

    def charpos(pos = @scan.pos)
      @str_size - @str.byteslice(pos..).size
    end

    Fail = Struct.new(:stack, :bytepos, :pattern)

    def fail!(*, bytepos: @scan.pos, pat: nil, skip: 2)
      if debug || !@failed || bytepos > @failed.bytepos
        stack = caller_locations(skip)
        stack.delete_if do |loc|
          path = loc.path
          if path == __FILE__
            true
          elsif path.start_with?(__dir__)
            loc.label =~ /\b(backtrack|each|block)\b/
          end
        end
        @failed = Fail.new(stack, bytepos, pat)
        report_failed($stderr) if debug
      end
      nil
    end

    def failed_position
      position(bytepos: @failed.bytepos)
    end

    def report_failed(out)
      pos = position(bytepos: @failed.bytepos)
      out << if @failed.pattern
        "Failed #{failed.pattern.inspect} at #{pos.lineno}:#{pos.colno}"
      else
        "Failed at #{pos.lineno}:#{pos.colno}"
      end
      if @file
        out << " of #{@file}"
      end
      out << ":\n"
      out << pos.line.chomp + "\n"
      curpos = pos.line[...pos.colno].gsub("\t", " " * 8).size
      curpos = 1 if curpos == 0 && @failed.bytepos == @str.bytesize
      out << (" " * (curpos - 1) + "^\n")
      out << "Call stack:\n"
      @failed.stack.each do |loc|
        out << "#{loc.path}:#{loc.lineno} in #{loc.label}\n"
      end
      out
    end

    class CutPoint
      attr_accessor :next

      def initialize
        @cut = nil
        @next = nil
      end

      def cut!
        @next&.cut!
        @cut = true
      end

      def can_continue?
        @cut ? nil : true
      end
    end

    # for use with cut! and cont?
    def with_cut_point
      prev_cut = @cut
      @cut = CutPoint.new
      prev_cut.next = @cut
      yield @cut
    ensure
      prev_cut.next = nil
      @cut = prev_cut
    end

    def current_cutpoint
      @cut
    end

    # Position handling for failures

    Position = Struct.new(:lineno, :colno, :line, :charpos)

    def init_line_ends
      @line_ends = [-1]
      scan = StringScanner.new(@str)
      while scan.skip_until(/\n|\r\n?/)
        @line_ends << scan.pos - 1
      end
      @line_ends << @str.bytesize
    end

    def position(bytepos: @scan.pos)
      lineno = @line_ends.bsearch_index { |x| x >= bytepos }
      case lineno
      when nil
        raise "Position #{bytepos} is larger than string byte size #{@str.bytesize}"
      else
        prev_end = @line_ends[lineno - 1]
        line_start = prev_end + 1
        column = @str.byteslice(line_start, bytepos - prev_end).size
      end
      if bytepos == @str.bytesize
        if @str[-1] == "\n"
          lineno, column = lineno + 1, 1
        else
          column += 1
        end
      end
      line = @str.byteslice(line_start..@line_ends[lineno])
      Position.new(lineno, column, line, charpos(bytepos))
    end

    # helper methods

    begin
      StringScanner.new("x").skip("x")
      def match(lit = nil, &block)
        block ? backtrack(&block) : (!lit || @scan.skip(lit) && true || fail!(pat: lit))
      end
    rescue
      def match(lit = nil, &block)
        if String === lit
          @_lit_cache ||= {}
          lit = @_lit_cache[lit] ||= Regexp.new(Regexp.escape(lit))
        end
        block ? backtrack(&block) : (!lit || @scan.skip(lit) && true || fail!(pat: lit))
      end
    end

    def text(lit = nil, &block)
      pos = @scan.pos
      match(lit, &block) && @str.byteslice(pos, @scan.pos - pos)
    end

    def bounds(lit = nil, &block)
      pos = @scan.pos
      match(lit, &block) && pos...@scan.pos
    end

    def repetition(range = 0.., lit = nil, &block)
      range = range..range if Integer === range
      range = 0..range.max if range.begin.nil?
      unless Integer === range.min && (range.end.nil? || Integer === range.max)
        raise "Range malformed #{range}"
      end
      backtrack do
        max = range.end && range.max
        ar = []
        (1..max).each do |i|
          res = backtrack { yield i == 1 }
          break unless res
          ar << res
        end
        (ar.size >= range.min) ? ar : fail!
      end
    end

    def dot
      match(/./m)
    end

    def eof?
      @scan.eos?
    end

    def backtrack
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

    def look_ahead(positive, lit = nil, &block)
      if block
        p, f = @scan.pos, @failed
        r = yield
        @scan.pos = p
        if positive ? r : !r
          @failed = f
          true
        else
          fail!
        end
      else
        m = @scan.match?(lit)
        if positive ? m : !m
          true
        else
          fail!(pat: lit)
        end
      end
    end
  end
end
