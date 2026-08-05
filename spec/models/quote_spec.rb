require "rails_helper"

RSpec.describe Quote, type: :model do
  it { is_expected.to validate_presence_of(:name) }

  it {
    is_expected.to define_enum_for(:status)
      .with_values(draft: "draft", validated: "validated")
      .backed_by_column_of_type(:string)
      .with_default(:draft)
  }

  it { is_expected.to have_many(:quote_items).dependent(:destroy) }

  it "orders quote_items by id ascending, regardless of update order" do
    quote = create(:quote)
    first_item = create(:quote_item, quote: quote)
    second_item = create(:quote_item, quote: quote)

    first_item.touch

    expect(quote.reload.quote_items.to_a).to eq([ first_item, second_item ])
  end

  it "deletes its items when destroyed" do
    quote = create(:quote)
    item = create(:quote_item, quote: quote)

    expect { quote.destroy }.to change(QuoteItem, :count).by(-1)
    expect { item.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end

  describe "#finalize" do
    it "sets the quote validated with a validation timestamp when it has at least one item" do
      quote = create(:quote, status: :draft)
      create(:quote_item, quote: quote)

      quote.finalize

      expect(quote).to be_validated
      expect(quote.validated_at).to be_present
    end

    it "refuses a quote with no item, leaving it a draft in the database" do
      quote = create(:quote, status: :draft)

      quote.finalize

      expect(quote.errors[:base]).to be_present
      expect(quote.reload).to be_draft
      expect(quote.validated_at).to be_nil
    end

    it "does not run the no-item check on an ordinary save" do
      quote = create(:quote, status: :draft)

      expect(quote.update(name: "Nouveau nom")).to be(true)
    end

    it "refuses to finalize a quote already validated in the database" do
      quote = create(:quote, status: :draft)
      create(:quote_item, quote: quote)
      quote.finalize

      expect { quote.finalize }.to raise_error(Quote::ImmutableError)
    end
  end

  describe "immutability once validated" do
    it "refuses to update a quote already validated in the database" do
      quote = create(:quote, name: "Ancien nom", status: :validated, validated_at: Time.current)

      expect { quote.update(name: "Nouveau nom") }.to raise_error(Quote::ImmutableError)
      expect(quote.reload.name).to eq("Ancien nom")
    end

    it "refuses to destroy a quote already validated in the database" do
      quote = create(:quote, status: :validated, validated_at: Time.current)

      expect { quote.destroy }.to raise_error(Quote::ImmutableError)
      expect(Quote.exists?(quote.id)).to be(true)
    end

    it "reads the persisted status rather than the in-memory one, so the draft-to-validated " \
       "transition does not refuse itself" do
      quote = create(:quote, status: :draft)
      quote.status = :validated

      expect { quote.update(name: "Nouveau nom") }.not_to raise_error
      expect(quote.reload.name).to eq("Nouveau nom")
    end
  end
end
