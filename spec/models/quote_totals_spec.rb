require "rails_helper"

RSpec.describe QuoteTotals do
  describe "a quote with no item" do
    it "returns zero for the three totals and no lines" do
      quote = create(:quote)
      totals = described_class.new(quote)

      expect(totals.lines).to eq([])
      expect(totals.total_net_amount).to eq(0)
      expect(totals.total_vat_amount).to eq(0)
      expect(totals.total_gross_amount).to eq(0)
    end
  end

  describe "a single line, one rate, no rounding involved" do
    it "computes the line and the totals directly" do
      quote = create(:quote)
      item = create(:quote_item, quote: quote, quantity: 2, unit_price_excl_vat: 50, vat_rate: 20)

      totals = described_class.new(quote)
      line = totals.lines.sole

      expect(line.item).to eq(item)
      expect(line.line_net_amount).to eq(100)
      expect(line.line_vat_amount).to eq(20)
      expect(line.line_gross_amount).to eq(120)

      expect(totals.total_net_amount).to eq(100)
      expect(totals.total_vat_amount).to eq(20)
      expect(totals.total_gross_amount).to eq(120)
    end
  end

  describe "a quote made entirely of 0 % lines" do
    it "produces zero VAT everywhere without special-casing" do
      quote = create(:quote)
      create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: 30, vat_rate: 0)
      create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: 45, vat_rate: 0)

      totals = described_class.new(quote)

      expect(totals.lines.map(&:line_vat_amount)).to all(eq(0))
      expect(totals.lines.map { |line| line.line_gross_amount }).to eq(totals.lines.map(&:line_net_amount))
      expect(totals.total_vat_amount).to eq(0)
      expect(totals.total_gross_amount).to eq(totals.total_net_amount)
    end
  end

  describe "several rates on one quote" do
    it "computes each line and total against concrete expected figures" do
      quote = create(:quote)
      create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: 100, vat_rate: 20)
      create(:quote_item, quote: quote, quantity: 3, unit_price_excl_vat: 10, vat_rate: 10)
      create(:quote_item, quote: quote, quantity: 2, unit_price_excl_vat: 12.5, vat_rate: 5.5)

      totals = described_class.new(quote)

      # 20 % line: net 1 * 100 = 100.00, vat 20.00, gross 120.00.
      # 10 % line: net 3 * 10 = 30.00, vat 3.00, gross 33.00.
      # 5.5 % line: net 2 * 12.5 = 25.00, vat round_half_up(25.00 * 5.5 / 100) = 1.38, gross 26.38.
      expect(totals.lines.map(&:line_net_amount)).to eq([ BigDecimal("100"), BigDecimal("30"), BigDecimal("25") ])
      expect(totals.lines.map(&:line_vat_amount)).to eq([ BigDecimal("20"), BigDecimal("3"), BigDecimal("1.38") ])
      expect(totals.lines.map(&:line_gross_amount)).to eq([ BigDecimal("120"), BigDecimal("33"), BigDecimal("26.38") ])

      expect(totals.total_net_amount).to eq(BigDecimal("155"))
      expect(totals.total_vat_amount).to eq(BigDecimal("24.38"))
      expect(totals.total_gross_amount).to eq(BigDecimal("179.38"))
    end

    it "satisfies both invariants: gross = net + vat, and lines sum to totals column by column" do
      quote = create(:quote)
      create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: 100, vat_rate: 20)
      create(:quote_item, quote: quote, quantity: 3, unit_price_excl_vat: 10, vat_rate: 10)
      create(:quote_item, quote: quote, quantity: 2, unit_price_excl_vat: 12.5, vat_rate: 5.5)

      totals = described_class.new(quote)

      expect(totals.total_gross_amount).to eq(totals.total_net_amount + totals.total_vat_amount)

      expect(totals.lines.sum(&:line_net_amount)).to eq(totals.total_net_amount)
      expect(totals.lines.sum(&:line_vat_amount)).to eq(totals.total_vat_amount)
      expect(totals.lines.sum(&:line_gross_amount)).to eq(totals.total_gross_amount)
    end
  end

  describe "a rate group where naive per-line rounding would not sum to the group's VAT" do
    it "reconciles the lines to the group's authoritative VAT instead" do
      quote = create(:quote)
      3.times { create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: 0.03, vat_rate: 20) }

      totals = described_class.new(quote)

      # Naive per-line rounding: round(0.03 * 0.20, 2) = 0.01, three times, sums to 0.03.
      # Authoritative group VAT: round(0.09 * 0.20, 2) = 0.02.
      expect(totals.total_vat_amount).to eq(BigDecimal("0.02"))
      expect(totals.lines.sum(&:line_vat_amount)).to eq(BigDecimal("0.02"))
    end
  end

  describe "a group where the full k cents have to be distributed" do
    it "allocates one cent to every one of the twelve lines at 5.5 %" do
      quote = create(:quote)
      12.times { create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: 1.09, vat_rate: 5.5) }

      totals = described_class.new(quote)

      expect(totals.lines.map(&:line_vat_amount)).to all(eq(BigDecimal("0.06")))
      expect(totals.total_vat_amount).to eq(BigDecimal("0.72"))
    end
  end

  describe "a tie on the remainder" do
    it "breaks the tie by item id ascending, deterministically" do
      quote = create(:quote)
      first_item = create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: 0.17, vat_rate: 10)
      second_item = create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: 0.57, vat_rate: 10)

      # Both lines have an exact VAT fractional remainder of 0.7 cents, and only
      # one cent is left to distribute after flooring, so the tie-break decides.
      totals = described_class.new(quote)
      lines_by_item = totals.lines.index_by(&:item)

      expect(lines_by_item[first_item].line_vat_amount).to eq(BigDecimal("0.02"))
      expect(lines_by_item[second_item].line_vat_amount).to eq(BigDecimal("0.05"))
    end
  end
end
