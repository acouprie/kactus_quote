require "rails_helper"

# Applied to every scenario below, so the invariant is checked on every shape of quote rather
# than on one of them.
RSpec.shared_examples "consistent quote totals" do
  it "keeps the lines and the totals consistent, column by column" do
    totals = QuoteTotals.new(quote)

    # This is the load-bearing assertion of the file. total_vat_amount is the sum of the
    # per-rate authoritative amounts, while the line VAT amounts come out of the cent
    # allocation. The two agreeing is a property the allocation has to produce, not a
    # definition, so this is the only one of the three that can actually fail. Do not drop it
    # as redundant with the two below.
    expect(totals.lines.sum(&:line_vat_amount)).to eq(totals.total_vat_amount)

    # These two hold by construction (BR-CO-10 and BR-CO-15). They document the definitions
    # rather than test them.
    expect(totals.lines.sum(&:line_net_amount)).to eq(totals.total_net_amount)
    expect(totals.lines.sum(&:line_gross_amount)).to eq(totals.total_gross_amount)
  end
end

RSpec.describe QuoteTotals do
  describe "a quote with no item" do
    let(:quote) { create(:quote) }

    it_behaves_like "consistent quote totals"

    it "returns zero for the three totals and no lines" do
      totals = described_class.new(quote)

      expect(totals.lines).to eq([])
      expect(totals.total_net_amount).to eq(BigDecimal("0"))
      expect(totals.total_vat_amount).to eq(BigDecimal("0"))
      expect(totals.total_gross_amount).to eq(BigDecimal("0"))
    end
  end

  describe "a single line, one rate, no rounding involved" do
    let(:quote) { create(:quote) }
    let!(:item) do
      create(:quote_item, quote: quote, quantity: 2, unit_price_excl_vat: 50, vat_rate: 20)
    end

    it_behaves_like "consistent quote totals"

    it "computes the line and the totals directly" do
      totals = described_class.new(quote)
      line = totals.lines.sole

      expect(line.item).to eq(item)
      expect(line.line_net_amount).to eq(BigDecimal("100"))
      expect(line.line_vat_amount).to eq(BigDecimal("20"))
      expect(line.line_gross_amount).to eq(BigDecimal("120"))

      expect(totals.total_net_amount).to eq(BigDecimal("100"))
      expect(totals.total_vat_amount).to eq(BigDecimal("20"))
      expect(totals.total_gross_amount).to eq(BigDecimal("120"))
    end
  end

  describe "a quote made entirely of 0 % lines" do
    let(:quote) { create(:quote) }

    before do
      create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: 30, vat_rate: 0)
      create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: 45, vat_rate: 0)
    end

    it_behaves_like "consistent quote totals"

    it "produces zero VAT everywhere without special-casing" do
      totals = described_class.new(quote)

      expect(totals.lines.map(&:line_vat_amount)).to all(eq(BigDecimal("0")))
      expect(totals.lines.map(&:line_gross_amount)).to eq(totals.lines.map(&:line_net_amount))
      expect(totals.total_vat_amount).to eq(BigDecimal("0"))
      expect(totals.total_net_amount).to eq(BigDecimal("75"))
      expect(totals.total_gross_amount).to eq(BigDecimal("75"))
    end
  end

  describe "several rates on one quote" do
    let(:quote) { create(:quote) }

    before do
      create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: 100, vat_rate: 20)
      create(:quote_item, quote: quote, quantity: 3, unit_price_excl_vat: 10, vat_rate: 10)
      create(:quote_item, quote: quote, quantity: 2, unit_price_excl_vat: "12.5", vat_rate: "5.5")
    end

    it_behaves_like "consistent quote totals"

    it "computes each rate group on its own base and aggregates them" do
      totals = described_class.new(quote)

      # 20 % on 100.00 gives 20.00, 10 % on 30.00 gives 3.00, and 5.5 % on 25.00 gives
      # 1.375, rounded half-up to 1.38.
      expect(totals.lines.map(&:line_vat_amount))
        .to eq([ BigDecimal("20"), BigDecimal("3"), BigDecimal("1.38") ])

      expect(totals.total_net_amount).to eq(BigDecimal("155"))
      expect(totals.total_vat_amount).to eq(BigDecimal("24.38"))
      expect(totals.total_gross_amount).to eq(BigDecimal("179.38"))
    end
  end

  describe "a rate group where naive per-line rounding would not sum to the group's VAT" do
    let(:quote) { create(:quote) }

    before do
      3.times { create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: "0.03", vat_rate: 20) }
    end

    it_behaves_like "consistent quote totals"

    it "reconciles the lines to the group's authoritative VAT instead" do
      totals = described_class.new(quote)

      # Naive per-line rounding: round(0.03 * 0.20, 2) = 0.01, three times, sums to 0.03.
      # Authoritative group VAT: round(0.09 * 0.20, 2) = 0.02.
      expect(totals.total_vat_amount).to eq(BigDecimal("0.02"))
      expect(totals.lines.map(&:line_vat_amount))
        .to eq([ BigDecimal("0.01"), BigDecimal("0.01"), BigDecimal("0") ])
    end
  end

  describe "a group where the full k cents have to be distributed" do
    let(:quote) { create(:quote) }

    before do
      12.times { create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: "1.09", vat_rate: "5.5") }
    end

    it_behaves_like "consistent quote totals"

    it "allocates one cent to every one of the twelve lines at 5.5 %" do
      totals = described_class.new(quote)

      # Each line's exact VAT is 5.995 cents, so every floor discards almost a full cent and
      # all twelve have to be given back. At 20 % the remainder never exceeds 0.8 cents and
      # this upper bound would not be reachable, so the rate is part of the test.
      expect(totals.lines.map(&:line_vat_amount)).to all(eq(BigDecimal("0.06")))
      expect(totals.total_vat_amount).to eq(BigDecimal("0.72"))
    end
  end

  describe "a tie on the remainder" do
    let(:quote) { create(:quote) }
    let!(:first_item) do
      create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: "0.17", vat_rate: 10)
    end
    let!(:second_item) do
      create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: "0.57", vat_rate: 10)
    end

    it_behaves_like "consistent quote totals"

    it "breaks the tie by item id ascending, deterministically" do
      # Both lines have an exact VAT fractional remainder of 0.7 cents, and only one cent is
      # left to distribute after flooring, so the tie-break is what decides the outcome. The
      # id is the only ordering the allocation depends on, which is what makes the result
      # reproducible across runs.
      totals = described_class.new(quote)
      lines_by_item = totals.lines.index_by(&:item)

      expect(lines_by_item[first_item].line_vat_amount).to eq(BigDecimal("0.02"))
      expect(lines_by_item[second_item].line_vat_amount).to eq(BigDecimal("0.05"))
    end
  end

  describe "the rounding mode" do
    # Every rounding in QuoteTotals passes ROUND_HALF_UP explicitly. These two scenarios are
    # the only ones in the file whose amounts land exactly on half a cent, so they are the
    # only ones that would fail if the mode were left implicit and a future contributor
    # switched the process to banker's rounding.

    context "on a line's net amount" do
      let(:quote) { create(:quote) }

      before do
        create(:quote_item, quote: quote, quantity: "1.5", unit_price_excl_vat: "2.43", vat_rate: 20)
      end

      it_behaves_like "consistent quote totals"

      it "rounds half-up rather than half-even" do
        # 1.5 x 2.43 = 3.645 exactly. Half-up gives 3.65, banker's rounding gives 3.64.
        expect(described_class.new(quote).total_net_amount).to eq(BigDecimal("3.65"))
      end
    end

    context "on a rate group's VAT" do
      let(:quote) { create(:quote) }

      before do
        create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: "13.65", vat_rate: 10)
      end

      it_behaves_like "consistent quote totals"

      it "rounds half-up rather than half-even" do
        # 13.65 x 10 / 100 = 1.365 exactly. Half-up gives 1.37, banker's rounding gives 1.36.
        expect(described_class.new(quote).total_vat_amount).to eq(BigDecimal("1.37"))
      end
    end
  end
end
