# frozen_string_literal: true

require "strscan"

module FuPeg
  class Parser
    class PositionSearcher
      Position = Struct.new(:lineno, :colno, :line, :char)

      def initialize(str)
        @str = str
        @line_starts = []
        pos = 0
        while pos = str.index("\n", pos)
          pos += 1
          @line_starts << @pos
        end
        @line_starts << @str.size
      end

      def position(pos)
        lineno = @line_starts.bsearch_index { |x| x > pos }
        case lineno
        when nil
          raise "Position #{pos} is larger than string size #{@str.size}"
        when 0
          line_start = 0
          column = pos
        else
          line_start = @line_starts[lineno - 1]
          column = pos - line_start
        end
        line = @str[line_start...@line_starts[lineno]]
        char = @str[@pos]
        Position.new(lineno + 1, column + 1, line, char)
      end
    end

    class Memoizer
      class Item
        def initialize(rule, args, nxt)
          @rule = rule
          @args = args
          @result = nil
          @state = :new
          @next = nxt
        end

        attr_reader :rule, :args, :result, :_next

        def find(rule, args)
          i = @self
          i = i._next until i.nil? || i.match?(rule, args)
          i
        end

        def match?(rule, args)
          @rule == rule && @args == args
        end

        def state
          case @state
          when Number
            :success
          else
            @state
          end
        end

        def delay!
          @state = :delay
        end

        def left_recursive!
          @state = :left_recursive
        end

        def set(endpos, result)
          @state = endpos
          @result = result
        end

        def fail!
          @state = :fail
        end
      end

      def initialize
        @map = {}
      end

      def [](pos, rule, args = nil)
        list = @map[pos]
        item = list&.find(rule, args)
        item || (@map[pos] = Item.new(rule, args, list))
      end
    end

    class ChoiceStack
      ChoicePoint = Struct.new(:pos, :cut, :sno)

      def initialize(scan)
        @scan = scan
        @stack = []
        @cur = nil
        @sno = 0
      end

      def with
        point = ChoicePoint.new(@scan.pos, false, (@sno += 1))
        @stack << point
        prev, @cur = @cur, point
        yield point
      ensure
        @stack.pop if @stack.last == point
        if @stack.last && (@stack.last.sno >= point.sno || @stack.last.pos > point.pos)
          raise "ChoiceStack logic error: #{@stack.last} > #{point}"
        end
        @cur = prev
      end

      def cut!
        @cur.cut = true
        @stack.pop while @stack.last&.cut
        @stack.empty?
      end
    end

    def initialize(str, pos = 0)
      reset(str, pos)
    end

    def reset(str, pos = 0)
      @str = str
      @str_size = str.size
      @pos_searcher = PositionSearcher.new(str)
      @scan = StringScanner.new(str)
      @scan.pos = pos
      @memoize = Memoizer.new
      @current_rule = nil
      @failed = nil
      @result = nil

      @choice_stack = ChoiceStack.new(@scan)
    end

    attr_reader :result
    attr_reader :failed

    def parse(rule = :root)
      @failed = nil
      match_rule(rule)
    end

    def bytepos
      @scan.pos
    end

    def charpos
      @str_size - @str.byteslice(@scan.pos..).size
    end

    Fail = Struct.new(:rule, :pos)

    def set_failed(rule)
      if !@failed || @scan.pos > @failed.pos
        @failed = Fail.new(rule, @scan.pos)
      end
    end

    def match_fail
      false
    end

    def match_empty
      true
    end

    def match_dot
      @scan.skip(/./) && true
    end

    begin
      StringScanner.new("x").skip("x")
      def match_lit(reg_or_str)
        @scan.skip(reg_or_str) && true
      end
    rescue
      def match_lit(reg_or_str)
        if String === reg_or_str
          @__match_lit_cache ||= Hash.new { |h, s| h[s] = Regexp.new(Regexp.escape(s)) }
          reg_or_str = @__match_lit_cache[reg_or_str]
        end
        @scan.skip(reg_or_str) && true
      end
    end

    def match_rule(rule)
      save_pos = @scan.pos
      @result = nil
      name = nil
      res = case rule
      when Symbol
        name = rule
        __send__(rule)
      when Array
        name = rule[0]
        __send__(*rule)
      else
        rule.call
      end
      unless res
        set_failed(name) if name
        @scan.pos = save_pos
      end
      res
    end

    def assert_pos(pos)
      if pos != @scan.pos
        raise "Fail didn't return pos from #{@scan.pos} to #{point.pos}"
      end
    end

    def match_choices(choices)
      @choice_stack.with do |point|
        choices.each do |choice|
          return true if match_rule(choice)
          assert_pos(point.pos)
          return false if point.cut
        end
      end
      false
    end

    def match_opt(rule)
      @choice_stack.with do |point|
        return true if match_rule(rule)
        assert_pos(point.pos)
        return false if point.cut
      end
      true
    end

    def match_rep(range, seq)
      raise "Range malformed #{range}" unless Integer === r.min && (r.end.nil? || Integer === r.max)
      @choice_stack.with do |point|
        arr = (1..range.min).map do
          save_pos = @scan.pos
          unless match_rule(seq)
            assert_pos(save_pos)
            @scan.pos = point.pos
            return false
          end
          @result
        end
        (range.min..(range.end && range.max)).each do
          point.cut = false
          save_pos = @scan.pos
          unless match_rule(seq)
            assert_pos(save_pos)
            if point.cut
              @scan.pos = point.pos
              return false
            end
            return true
          end
          arr << @result
        end
      end
      @result = arr
      true
    end

    def cut!
      if @choice_stack.cut!
        # @memoize.clear
      end
    end

    def match_sequence(sequence)
      save_pos = @scan.pos
      sequence.each do |seq|
        spos = @scan.pos
        unless match_rule(seq)
          assert_pos(spos)
          @scan.pos = save_pos
          return false
        end
      end
      true
    end
  end
end
