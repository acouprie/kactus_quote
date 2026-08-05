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

        expect(rendered).to have_css("turbo-stream[action='update'][target='quote_items']")
        expect(rendered).to have_css("turbo-stream[action='replace'][target='new_item']")
        expect(rendered).to have_css("turbo-stream[action='replace'][target='quote_totals']")
        expect(response.body).to include(item.name)

        expect(response.body).to include("360,00\u{202F}€")
      end

      it "enables the validate button once the first item is added" do
        post quote_items_path(quote),
             params: { quote_item: { name: "Location de salle", quantity: "2", unit_price_excl_vat: "150", vat_rate: "20" } },
             as: :turbo_stream

        expect(response.body).to include(%(target="quote_validate_button"))
        # The button lives inside a <turbo-stream><template>, whose content Capybara's string
        # parser strips (it is not part of the live document until Turbo moves it out), so the
        # disabled attribute is asserted with Nokogiri directly rather than Capybara matchers.
        container = Nokogiri::HTML(response.body).at_css("#quote_validate_button")
        expect(container.at_css("button")["disabled"]).to be_nil
        expect(container.at_css(".hint")).to be_nil
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
        expect(rendered).to have_no_css("turbo-stream[action='update'][target='quote_items']")
        expect(rendered).to have_no_css("turbo-stream[action='replace'][target='quote_totals']")
        expect(response.body).to include('class="inline-form__errors"')
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
      it "updates the item and re-renders the table body and the totals block" do
        item = create(:quote_item, quote: quote, name: "Ancien nom")

        patch quote_item_path(quote, item),
              params: { quote_item: { name: "Nouveau nom", quantity: "1", unit_price_excl_vat: "10", vat_rate: "20" } },
              as: :turbo_stream

        expect(response).to have_http_status(:ok)
        expect(item.reload.name).to eq("Nouveau nom")

        rendered = Capybara.string(response.body)
        expect(rendered).to have_css("turbo-stream[action='update'][target='quote_items']")
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

    context "when the quote is already validated" do
      it "refuses the update, redirecting to the quote screen with a 303 and a flash" do
        validated_quote = create(:quote, status: :draft)
        item = create(:quote_item, quote: validated_quote, name: "Ancien nom")
        validated_quote.finalize

        patch quote_item_path(validated_quote, item),
              params: { quote_item: { name: "Nouveau nom", quantity: "1", unit_price_excl_vat: "10", vat_rate: "20" } }

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(quote_path(validated_quote))
        expect(item.reload.name).to eq("Ancien nom")
        expect(flash[:alert]).to eq(I18n.t("quotes.quote_screen.immutable_alert"))
      end
    end
  end

  describe "DELETE /quotes/:quote_id/items/:id" do
    it "destroys the item and responds with a stream re-rendering the table body and the totals" do
      item = create(:quote_item, quote: quote)

      expect {
        delete quote_item_path(quote, item), as: :turbo_stream
      }.to change(QuoteItem, :count).by(-1)

      expect(response).to have_http_status(:ok)
      rendered = Capybara.string(response.body)
      expect(rendered).to have_css("turbo-stream[action='update'][target='quote_items']")
      expect(rendered).to have_css("turbo-stream[action='replace'][target='quote_totals']")
      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(item))
    end

    it "disables the validate button again once the last item is destroyed" do
      item = create(:quote_item, quote: quote)

      delete quote_item_path(quote, item), as: :turbo_stream

      expect(response.body).to include(%(target="quote_validate_button"))
      container = Nokogiri::HTML(response.body).at_css("#quote_validate_button")
      expect(container.at_css("button")["disabled"]).to eq("disabled")
      expect(container.at_css(".hint")).not_to be_nil
    end

    context "when the quote is already validated" do
      it "refuses the deletion, redirecting to the quote screen with a 303 and a flash" do
        validated_quote = create(:quote, status: :draft)
        item = create(:quote_item, quote: validated_quote)
        validated_quote.finalize

        expect {
          delete quote_item_path(validated_quote, item)
        }.not_to change(QuoteItem, :count)

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(quote_path(validated_quote))
        expect(flash[:alert]).to eq(I18n.t("quotes.quote_screen.immutable_alert"))
      end
    end
  end

  # The largest-remainder allocation redistributes cents inside a rate group, so a write on one
  # item can move the VAT, and therefore the displayed Total TTC, of lines that are already on
  # screen. A stream touching only the written row would leave the Total TTC column no longer
  # summing to the totals block, which is the one property the whole computation exists to
  # produce. See docs/logbook.md, "The VAT computation contract".
  describe "a write that shifts the cent allocation of the other lines" do
    # 0,17 € and 0,57 € at 10 % both floor with a 0.7 cent remainder, and the group's
    # authoritative VAT leaves exactly one cent to distribute, so the id tie-break gives it to
    # the first line: 0,02 € and 0,05 €.
    let!(:first_item) do
      create(:quote_item, quote: quote, name: "Premier", quantity: 1, unit_price_excl_vat: "0.17", vat_rate: 10)
    end
    let!(:second_item) do
      create(:quote_item, quote: quote, name: "Second", quantity: 1, unit_price_excl_vat: "0.57", vat_rate: 10)
    end

    def rendered_gross_amount_for(item)
      # The rows sit inside a <turbo-stream><template>, whose content Capybara's string parser
      # strips, so this reads the response with Nokogiri directly.
      Nokogiri::HTML(response.body)
        .at_css("##{ActionView::RecordIdentifier.dom_id(item)} .items-row__cell--gross-preview")
        &.text&.strip
    end

    it "re-renders the sibling rows when a created item moves a cent" do
      # The third line drops the second one's remainder rank, so its VAT goes from 0,05 € to
      # 0,06 € and its Total TTC from 0,62 € to 0,63 €.
      post quote_items_path(quote),
           params: { quote_item: { name: "Troisième", quantity: "1", unit_price_excl_vat: "0.17", vat_rate: "10" } },
           as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(rendered_gross_amount_for(second_item)).to eq("0,63\u{202F}€")
    end

    it "re-renders the sibling rows when an updated item moves a cent" do
      patch quote_item_path(quote, first_item),
            params: { quote_item: { name: "Premier", quantity: "1", unit_price_excl_vat: "0.03", vat_rate: "10" } },
            as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(rendered_gross_amount_for(second_item)).to eq("0,63\u{202F}€")
    end

    it "re-renders the sibling rows when a destroyed item gives a cent back" do
      third_item = create(:quote_item, quote: quote, name: "Troisième", quantity: 1,
                                       unit_price_excl_vat: "0.17", vat_rate: 10)

      delete quote_item_path(quote, third_item), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(rendered_gross_amount_for(second_item)).to eq("0,62\u{202F}€")
    end
  end

  describe "POST /quotes/:quote_id/items when the quote is already validated" do
    it "refuses the creation, redirecting to the quote screen with a 303 and a flash" do
      validated_quote = create(:quote, status: :validated, validated_at: Time.current)

      expect {
        post quote_items_path(validated_quote),
             params: { quote_item: { name: "Location de salle", quantity: "2", unit_price_excl_vat: "150", vat_rate: "20" } }
      }.not_to change(QuoteItem, :count)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(quote_path(validated_quote))
      expect(flash[:alert]).to eq(I18n.t("quotes.quote_screen.immutable_alert"))
    end
  end
end
