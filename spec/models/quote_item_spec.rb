require "rails_helper"

RSpec.describe QuoteItem, type: :model do
  it { is_expected.to belong_to(:quote) }
  it { is_expected.to validate_presence_of(:name) }

  it { is_expected.to validate_inclusion_of(:vat_rate).in_array(QuoteItem::ALLOWED_VAT_RATES) }

  describe "quantity" do
    it {
      is_expected.to validate_numericality_of(:quantity)
        .is_greater_than(0)
        .is_less_than_or_equal_to(QuoteItem::MAX_INPUT_VALUE)
    }

    it "rejects zero" do
      expect(build(:quote_item, quantity: 0)).not_to be_valid
    end

    it "rejects a negative value" do
      expect(build(:quote_item, quantity: -1)).not_to be_valid
    end

    it "reads a French decimal separator, normalized before assignment" do
      item = build(:quote_item, quantity: "12,50")
      expect(item.quantity).to eq(BigDecimal("12.50"))
    end

    it "rejects a French-formatted value with too many decimals" do
      item = build(:quote_item, quantity: "1,755")
      expect(item).not_to be_valid
      expect(item.errors[:quantity]).to be_present
    end

    it "rejects a value with more decimals than the column scale, instead of silently saving it rounded" do
      item = build(:quote_item, quantity: "1.755")
      expect(item).not_to be_valid
      expect(item.errors[:quantity]).to be_present
      expect(item.save).to be(false)
    end

    it "rejects a value above the upper bound as a validation error, never a database exception" do
      item = build(:quote_item, quantity: 100_000)
      expect { item.valid? }.not_to raise_error
      expect(item).not_to be_valid
    end
  end

  describe "unit_price_excl_vat" do
    it {
      is_expected.to validate_numericality_of(:unit_price_excl_vat)
        .is_greater_than_or_equal_to(0)
        .is_less_than_or_equal_to(QuoteItem::MAX_INPUT_VALUE)
    }

    it "accepts zero" do
      expect(build(:quote_item, unit_price_excl_vat: 0)).to be_valid
    end

    it "rejects a negative value" do
      expect(build(:quote_item, unit_price_excl_vat: -1)).not_to be_valid
    end

    it "reads a French decimal separator, normalized before assignment" do
      item = build(:quote_item, unit_price_excl_vat: "12,50")
      expect(item.unit_price_excl_vat).to eq(BigDecimal("12.50"))
    end

    it "rejects a value with more decimals than the column scale, instead of silently saving it rounded" do
      item = build(:quote_item, unit_price_excl_vat: "1.755")
      expect(item).not_to be_valid
      expect(item.errors[:unit_price_excl_vat]).to be_present
      expect(item.save).to be(false)
    end

    it "rejects a value above the upper bound as a validation error, never a database exception" do
      item = build(:quote_item, unit_price_excl_vat: 100_000)
      expect { item.valid? }.not_to raise_error
      expect(item).not_to be_valid
    end
  end

  describe "immutability once its quote is validated" do
    it "refuses to create an item on a quote already validated in the database" do
      quote = create(:quote, status: :validated, validated_at: Time.current)

      expect { create(:quote_item, quote: quote) }.to raise_error(Quote::ImmutableError)
    end

    it "refuses to update or destroy an item once its quote has been validated, even when the " \
       "item is loaded independently of the quote, without going through Quotes::ItemsController" do
      quote = create(:quote, status: :draft)
      item = create(:quote_item, quote: quote)
      quote.finalize

      fresh_item = QuoteItem.find(item.id)
      expect { fresh_item.update(name: "Nouveau nom") }.to raise_error(Quote::ImmutableError)
      expect(item.reload.name).not_to eq("Nouveau nom")

      expect { QuoteItem.find(item.id).destroy }.to raise_error(Quote::ImmutableError)
      expect(QuoteItem.exists?(item.id)).to be(true)
    end
  end
end
