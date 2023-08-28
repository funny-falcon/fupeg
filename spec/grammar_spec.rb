# frozen_string_literal: true

RSpec.describe FuPeg::Grammar do
  it "could be created" do
    expect { FuPeg::Parser.new("hello") }.not_to raise_error
  end

  context "simple actions" do
    let(:parser) { FuPeg::Parser.new("hello") }
    let(:gr) { FuPeg::Grammar.new(parser) }
    it "should match dot" do
      class << gr
        def root
          dot
        end
      end
      expect(gr.root).to be_truthy
      expect(parser.charpos).to eq 1
    end

    it "should match string" do
      class << gr
        def root
          _("hell")
        end
      end
      expect(gr.root).to be_truthy
      expect(parser.charpos).to eq 4
    end

    it "should fail string" do
      class << gr
        def root
          _("helo")
        end
      end
      expect(gr.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed_position.charpos).to eq 0
    end

    it "should match regexp" do
      class << gr
        def root
          _(/he?l*/)
        end
      end
      expect(gr.root).to be_truthy
      expect(parser.charpos).to eq 4
    end

    it "should fail regexp" do
      class << gr
        def root
          _(/h?el+a/)
        end
      end
      expect(gr.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed_position.charpos).to eq 0
    end

    it "should match ident token" do
      class << gr
        def root
          `hello`
        end
      end
      expect(gr.root).to be_truthy
      expect(parser.charpos).to eq 5
    end

    it "should fail ident token" do
      class << gr
        def root
          `hella`
        end
      end
      expect(gr.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed_position.charpos).to eq 0
    end

    it "should fail shorter ident token" do
      class << gr
        def root
          `hell`
        end
      end
      expect(gr.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed_position.charpos).to eq 0
    end

    it "should match choice" do
      class << gr
        def root
          _("hell") || _("sky")
        end
      end
      expect(gr.root).to be_truthy
      expect(parser.charpos).to eq 4
    end

    it "should match choice 2" do
      class << gr
        def root
          _("sky") || _("hell")
        end
      end
      expect(gr.root).to be_truthy
      expect(parser.charpos).to eq 4
    end

    it "should fail choice" do
      class << gr
        def root
          _("sky") || _("halo")
        end
      end
      expect(gr.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed_position.charpos).to eq 0
    end

    it "should match sequence" do
      class << gr
        def root
          _ { _(/[he]*/) && _("ll") }
        end
      end
      expect(gr.root).to be_truthy
      expect(parser.charpos).to eq 4
    end

    it "should fail sequence 1" do
      class << gr
        def root
          _ { _(/[ho]{2}/) && _("ll") }
        end
      end
      expect(gr.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed_position.charpos).to eq 0
    end

    it "should fail sequence 2" do
      class << gr
        def root
          _ { _(/[he]{2}/) && _("la") }
        end
      end
      expect(gr.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed_position.charpos).to eq 2
    end

    it "should match optional" do
      class << gr
        def root
          opt { _(/[he]*/) }
        end
      end
      expect(gr.root).to be_truthy
      expect(parser.charpos).to eq 2
      expect(parser.failed).to be_nil
    end

    it "should match optional 2" do
      class << gr
        def root
          opt { _(/[va]+/) }
        end
      end
      expect(gr.root).to be_truthy
      expect(parser.charpos).to eq 0
      # failed position is still remembered
      expect(parser.failed).to_not be_nil
    end

    it "should match look ahead" do
      class << gr
        def root
          _ { will? { _(/[he]+/) } && _("hell") }
        end
      end
      expect(gr.root).to be_truthy
      expect(parser.charpos).to eq 4
      expect(parser.failed).to be_nil
    end

    it "should fail look ahead" do
      class << gr
        def root
          _ { will? { _(/[va]+/) } && _("hell") }
        end
      end
      expect(gr.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed).to_not be_nil
    end

    it "should match negation" do
      class << gr
        def root
          _ { wont! { _(/[va]+/) } && _("hell") }
        end
      end
      expect(gr.root).to be_truthy
      expect(parser.charpos).to eq 4
      expect(parser.failed).to be_nil
    end

    it "should fail negation" do
      class << gr
        def root
          _ { wont! { _(/[he]+/) } && _("hell") }
        end
      end
      expect(gr.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed).to_not be_nil
    end

    it "should handle 0.. repetition" do
      class << gr
        def root
          rep { txt(/[helo]/) }
        end
      end

      expect(gr.root).to eq %w[h e l l o]
      expect(parser.charpos).to eq 5
      expect(parser.failed).to be_nil
    end

    it "should handle 0.. repetition 1" do
      class << gr
        def root
          rep { txt(/[zelo]/) }
        end
      end

      expect(gr.root).to eq %w[]
      expect(parser.charpos).to eq 0
      expect(parser.failed).to be_nil
    end

    it "should handle 1.. repetition" do
      class << gr
        def root
          rep(1..) { txt(/[helo]/) }
        end
      end

      expect(gr.root).to eq %w[h e l l o]
      expect(parser.charpos).to eq 5
      expect(parser.failed).to be_nil
    end

    it "should handle 1.. repetition 1" do
      class << gr
        def root
          rep(1..) { txt(/[hely]/) }
        end
      end

      expect(gr.root).to eq %w[h e l l]
      expect(parser.charpos).to eq 4
      expect(parser.failed).to be_nil
    end

    it "should fail 1.. repetition" do
      class << gr
        def root
          rep(1..) { txt(/[zelo]/) }
        end
      end

      expect(gr.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed).to_not be_nil
      # parser.report_failed($stderr)
    end

    it "should handle 1..3 repetition" do
      class << gr
        def root
          rep(1..3) { txt(/[helo]/) }
        end
      end

      expect(gr.root).to eq %w[h e l]
      expect(parser.charpos).to eq 3
      expect(parser.failed).to be_nil
    end

    it "should capture text" do
      class << gr
        def root
          _ { dot && (x = txt { rep(3) { dot } }) && dot && x }
        end
      end
      expect(gr.root).to eq "ell"
      expect(parser.charpos).to eq 5
      expect(parser.failed).to be_nil
    end

    it "should match cut" do
      class << gr
        def root
          cut {
            _ { _("he") && txt("llo") } ||
              cont? { dot && txt(/.*/) }
          }
        end
      end
      expect(gr.root).to eq "llo"
      expect(parser.charpos).to eq 5
      expect(parser.failed).to be_nil
    end

    it "should match cut 2" do
      class << gr
        def root
          cut {
            _ { dot && txt(/.*/) } ||
              cont? { `he` && `llo` }
          }
        end
      end
      expect(gr.root).to eq "ello"
      expect(parser.charpos).to eq 5
      expect(parser.failed).to be_nil
    end

    it "should properly cut" do
      class << gr
        def root
          cut {
            _ { _("he") && cut! && _("aven") } ||
              cont? { dot && txt(/.*/) }
          }
        end
      end
      expect(gr.root).to be_falsey
      expect(parser.charpos).to eq 0
      expect(parser.failed).to_not be_nil
      # parser.report_failed($stderr)
    end
  end

  context "positioning" do
    it "should position" do
      parser = FuPeg::Parser.new("abcd\nefgh")
      check = proc do |bytepos, lno, cno|
        pos = parser.position(bytepos: bytepos)
        expect(pos.lineno).to eq lno
        expect(pos.colno).to eq cno
      end
      check[0, 1, 1]
      check[1, 1, 2]
      check[2, 1, 3]
      check[3, 1, 4]
      check[4, 1, 5]
      check[5, 2, 1]
      check[6, 2, 2]
      check[7, 2, 3]
      check[8, 2, 4]
      check[9, 2, 5]
    end
  end
end
