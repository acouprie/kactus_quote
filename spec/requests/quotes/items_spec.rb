require "rails_helper"

RSpec.describe "Quotes::Items", type: :request do
  let(:quote) { create(:quote) }

  describe "GET /quotes/:quote_id/items/new" do
    it "renders the add-item form inside the new_item frame" do
      get new_quote_item_path(quote)

      expect(response).to have_http_status(:ok)
      rendered = Capybara.string(response.body)
      expect(rendered).to have_css("turbo-frame#new_item")
      expect(rendered).to have_css("form input[name='quote_item[name]']")
    end
  end

  describe "POST /quotes/:quote_id/items" do
    context "with valid attributes" do
      it "creates the item and responds with a multi-target turbo stream" do
        expect {
          post quote_items_path(quote),
               params: { quote_item: { name: "Location de salle", quantity: "2", unit_price_excl_vat: "150", vat_rate: "20" } },
               as: :turbo_stream
        }.to change(QuoteItem, :count).by(1)

        expect(response).to have_http_status(:ok)
        item = QuoteItem.last
        rendered = Capybara.string(response.body)

        expect(rendered).to have_css("turbo-stream[action='append'][target='quote_items']")
        expect(rendered).to have_css("turbo-stream[action='replace'][target='new_item']")
        expect(rendered).to have_css("turbo-stream[action='replace'][target='quote_totals']")
        expect(response.body).to include(item.name)
      end

      it "reads a French decimal separator on quantity and unit price" do
        post quote_items_path(quote),
             params: { quote_item: { name: "Location de salle", quantity: "1,5", unit_price_excl_vat: "12,50", vat_rate: "20" } },
             as: :turbo_stream

        item = QuoteItem.last
        expect(item.quantity).to eq(BigDecimal("1.5"))
        expect(item.unit_price_excl_vat).to eq(BigDecimal("12.50"))
      end
    end

    context "with a blank name" do
      it "does not create the item and responds 422, replacing only the new_item frame" do
        expect {
          post quote_items_path(quote),
               params: { quote_item: { name: "", quantity: "1", unit_price_excl_vat: "10", vat_rate: "20" } },
               as: :turbo_stream
        }.not_to change(QuoteItem, :count)

        expect(response).to have_http_status(:unprocessable_content)
        rendered = Capybara.string(response.body)

        expect(rendered).to have_css("turbo-stream[action='replace'][target='new_item']")
        expect(rendered).to have_no_css("turbo-stream[action='append']")
        expect(rendered).to have_no_css("turbo-stream[action='replace'][target='quote_totals']")
        expect(response.body).to include("ne peut pas être vide")
        expect(response.body).to include(%(name="quote_item[name]"))
      end
    end
  end

  describe "GET /quotes/:quote_id/items/:id/edit" do
    it "renders the edit form pre-filled inside the item's own frame" do
      item = create(:quote_item, quote: quote, name: "Location de salle")

      get edit_quote_item_path(quote, item)

      expect(response).to have_http_status(:ok)
      rendered = Capybara.string(response.body)
      expect(rendered).to have_css("turbo-frame#frame_quote_item_#{item.id}")
      expect(rendered).to have_css("input[name='quote_item[name]'][value='Location de salle']")
    end
  end

  describe "PATCH /quotes/:quote_id/items/:id" do
    context "with valid attributes" do
      it "updates the item and replaces its row and the totals block" do
        item = create(:quote_item, quote: quote, name: "Ancien nom")

        patch quote_item_path(quote, item),
              params: { quote_item: { name: "Nouveau nom", quantity: "1", unit_price_excl_vat: "10", vat_rate: "20" } },
              as: :turbo_stream

        expect(response).to have_http_status(:ok)
        expect(item.reload.name).to eq("Nouveau nom")

        rendered = Capybara.string(response.body)
        expect(rendered).to have_css("turbo-stream[action='replace'][target='frame_quote_item_#{item.id}']")
        expect(rendered).to have_css("turbo-stream[action='replace'][target='quote_totals']")
        expect(response.body).to include("Nouveau nom")
      end
    end

    context "with an invalid vat_rate" do
      it "does not persist the change and responds 422, keeping the item in its edit frame" do
        item = create(:quote_item, quote: quote, vat_rate: 20)

        patch quote_item_path(quote, item),
              params: { quote_item: { name: item.name, quantity: "1", unit_price_excl_vat: "10", vat_rate: "999" } },
              as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
        expect(item.reload.vat_rate).to eq(BigDecimal("20"))

        rendered = Capybara.string(response.body)
        expect(rendered).to have_css("turbo-stream[action='replace'][target='frame_quote_item_#{item.id}']")
        expect(rendered).to have_no_css("turbo-stream[action='replace'][target='quote_totals']")
        expect(response.body).to include(%(name="quote_item[name]"))
      end
    end
  end

  describe "DELETE /quotes/:quote_id/items/:id" do
    it "destroys the item and responds with a stream removing the row and refreshing the totals" do
      item = create(:quote_item, quote: quote)

      expect {
        delete quote_item_path(quote, item), as: :turbo_stream
      }.to change(QuoteItem, :count).by(-1)

      expect(response).to have_http_status(:ok)
      rendered = Capybara.string(response.body)
      expect(rendered).to have_css("turbo-stream[action='remove'][target='quote_item_#{item.id}']")
      expect(rendered).to have_css("turbo-stream[action='replace'][target='quote_totals']")
    end
  end
end
