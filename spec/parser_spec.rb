# frozen_string_literal: true

RSpec.describe FuPeg::Parser do
  it "could be created" do
    expect{ FuPeg::Parser.new("hello") }.not_to raise_error
  end

  it "should match dot" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_dot
      end
    end
    expect(parser.parse(:root)).to be true
    expect(parser.charpos).to eq 1
  end

  it "should match string" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_lit('hell')
      end
    end
    expect(parser.parse(:root)).to be true
    expect(parser.charpos).to eq 4
  end

  it "should detect not matched regexp" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_lit('helo')
      end
    end
    expect(parser.parse(:root)).to be_falsey
    expect(parser.charpos).to eq 0
  end

  it "should match regexp" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_lit(/he?l*/)
      end
    end
    expect(parser.parse(:root)).to be true
    expect(parser.charpos).to eq 4
  end

  it "should detect not matched regexp" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_lit(/h?el+a/)
      end
    end
    expect(parser.parse(:root)).to be_falsey
    expect(parser.charpos).to eq 0
  end

  it "should match choice 1" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_choices([
          [:match_lit, "hell"],
          [:match_lit, "sky"]
        ])
      end
    end
    expect(parser.parse(:root)).to be true
    expect(parser.charpos).to eq 4
  end

  it "should match choice 2" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_choices([
          ->{ match_lit("sky") },
          ->{ match_lit("hell") },
        ])
      end
    end
    expect(parser.parse(:root)).to be true
    expect(parser.charpos).to eq 4
  end

  it "should match sequence" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_sequence([
          ->{ match_lit(/[he]*/) },
          [:match_lit, "ll"]
        ])
      end
    end
    expect(parser.parse(:root)).to be true
    expect(parser.charpos).to eq 4
  end

  it "should match sequence (simple)" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_lit(/[he]*/) &&
        match_lit("ll")
      end
    end
    expect(parser.parse(:root)).to be true
    expect(parser.charpos).to eq 4
  end

  it "should detect not matched sequence 1" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_sequence([
          ->{ match_lit(/[ho]{2}/) },
          [:match_lit, "ll"]
        ])
      end
    end
    expect(parser.parse(:root)).to be_falsey
    expect(parser.charpos).to eq 0
  end

  it "should detect not matched sequence 2" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_sequence([
          ->{ match_lit(/[he]{2}/) },
          [:match_lit, "la"]
        ])
      end
    end
    expect(parser.parse(:root)).to be_falsey
    expect(parser.charpos).to eq 0
  end

  it "should detect not matched sequence 1 (simple)" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_lit(/[ho]{2}/) &&
        match_lit("ll")
      end
    end
    expect(parser.parse(:root)).to be_falsey
    expect(parser.charpos).to eq 0
  end

  it "should detect not matched sequence 2 (simple)" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_lit(/[he]{2}/) &&
        match_lit("la")
      end
    end
    expect(parser.parse(:root)).to be_falsey
    expect(parser.charpos).to eq 0
  end

  it "should match optional" do
    parser = FuPeg::Parser.new("hello")
    class << parser
      def root
        match_opt([:match_lit, /[he]*/])
      end
    end
    expect(parser.parse(:root)).to be true
    expect(parser.charpos).to eq 2
  end
end
