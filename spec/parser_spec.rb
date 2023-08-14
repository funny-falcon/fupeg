# frozen_string_literal: true

RSpec.describe FuPeg::Parser do
  it "could be created" do
    expect { FuPeg::Parser.new("hello") }.not_to raise_error
  end

  context "simple actions" do
    let(:parser) { FuPeg::Parser.new("hello") }
    it "should match dot" do
      class << parser
        def root
          dot
        end
      end
      expect(parser.root).to be_truthy
      expect(parser.charpos).to eq 1
    end

    it "should match string" do
      class << parser
        def root
          lit("hell")
        end
      end
      expect(parser.root).to be_truthy
      expect(parser.charpos).to eq 4
    end

    it "should fail string" do
      class << parser
        def root
          lit("helo")
        end
      end
      expect(parser.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed.pos.charpos).to eq 0
    end

    it "should match regexp" do
      class << parser
        def root
          lit(/he?l*/)
        end
      end
      expect(parser.root).to be_truthy
      expect(parser.charpos).to eq 4
    end

    it "should fail regexp" do
      class << parser
        def root
          lit(/h?el+a/)
        end
      end
      expect(parser.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed.pos.charpos).to eq 0
    end

    it "should match choice" do
      class << parser
        def root
          lit("hell") || lit("sky")
        end
      end
      expect(parser.root).to be_truthy
      expect(parser.charpos).to eq 4
    end

    it "should match choice 2" do
      class << parser
        def root
          lit("sky") || lit("hell")
        end
      end
      expect(parser.root).to be_truthy
      expect(parser.charpos).to eq 4
    end

    it "should fail choice" do
      class << parser
        def root
          lit("sky") || lit("halo")
        end
      end
      expect(parser.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed.pos.charpos).to eq 0
    end

    it "should match sequence" do
      class << parser
        def root
          seq { lit(/[he]*/) && lit("ll") }
        end
      end
      expect(parser.root).to be_truthy
      expect(parser.charpos).to eq 4
    end

    it "should fail sequence 1" do
      class << parser
        def root
          seq { lit(/[ho]{2}/) && lit("ll") }
        end
      end
      expect(parser.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed.pos.charpos).to eq 0
    end

    it "should fail sequence 2" do
      class << parser
        def root
          seq { lit(/[he]{2}/) && lit("la") }
        end
      end
      expect(parser.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed.pos.charpos).to eq 2
    end

    it "should match optional" do
      class << parser
        def root
          opt { lit(/[he]*/) }
        end
      end
      expect(parser.root).to be_truthy
      expect(parser.charpos).to eq 2
      expect(parser.failed).to be_nil
    end

    it "should match optional 2" do
      class << parser
        def root
          opt { lit(/[va]+/) }
        end
      end
      expect(parser.root).to be_truthy
      expect(parser.charpos).to eq 0
      expect(parser.failed).to be_nil
    end

    it "should match look ahead" do
      class << parser
        def root
          seq {
            will? { lit(/[he]+/) } &&
              lit("hell")
          }
        end
      end
      expect(parser.root).to be_truthy
      expect(parser.charpos).to eq 4
      expect(parser.failed).to be_nil
    end

    it "should fail look ahead" do
      class << parser
        def root
          seq {
            will? { lit(/[va]+/) } &&
              lit("hell")
          }
        end
      end
      expect(parser.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed).to_not be_nil
    end

    it "should match negation" do
      class << parser
        def root
          seq {
            wont! { lit(/[va]+/) } &&
              lit("hell")
          }
        end
      end
      expect(parser.root).to be_truthy
      expect(parser.charpos).to eq 4
      expect(parser.failed).to be_nil
    end

    it "should fail negation" do
      class << parser
        def root
          seq {
            wont! { lit(/[he]+/) } &&
              lit("hell")
          }
        end
      end
      expect(parser.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed).to_not be_nil
    end

    it "should handle 0.. repetition" do
      class << parser
        def root
          rep { lit(/[helo]/) }
        end
      end

      expect(parser.root).to eq %w[h e l l o]
      expect(parser.charpos).to eq 5
      expect(parser.failed).to be_nil
    end

    it "should handle 0.. repetition 1" do
      class << parser
        def root
          rep { lit(/[zelo]/) }
        end
      end

      expect(parser.root).to eq %w[]
      expect(parser.charpos).to eq 0
      expect(parser.failed).to be_nil
    end

    it "should handle 1.. repetition" do
      class << parser
        def root
          rep(1..) { lit(/[helo]/) }
        end
      end

      expect(parser.root).to eq %w[h e l l o]
      expect(parser.charpos).to eq 5
      expect(parser.failed).to be_nil
    end

    it "should handle 1.. repetition 1" do
      class << parser
        def root
          rep(1..) { lit(/[hely]/) }
        end
      end

      expect(parser.root).to eq %w[h e l l]
      expect(parser.charpos).to eq 4
      expect(parser.failed).to be_nil
    end

    it "should fail 1.. repetition" do
      class << parser
        def root
          rep(1..) { lit(/[zelo]/) }
        end
      end

      expect(parser.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed).to_not be_nil
      parser.report_failed($stderr)
    end

    it "should handle 1..3 repetition" do
      class << parser
        def root
          rep(1..3) { lit(/[helo]/) }
        end
      end

      expect(parser.root).to eq %w[h e l]
      expect(parser.charpos).to eq 3
      expect(parser.failed).to be_nil
    end

    it "should capture text" do
      class << parser
        def root
          seq { dot && (x = text { rep(3) { dot } }) && dot && x }
        end
      end
      expect(parser.root).to eq "ell"
      expect(parser.charpos).to eq 5
      expect(parser.failed).to be_nil
    end
  end
end
