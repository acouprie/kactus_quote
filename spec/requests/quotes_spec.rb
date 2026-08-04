require "rails_helper"

RSpec.describe "Quotes", type: :request do
  def destroy_affordance_for(quote)
    "form[action='#{quote_path(quote)}'] input[name='_method'][value='delete']"
  end

  def confirmation_affordance_for(quote)
    "form[action='#{quote_path(quote)}'] button[data-turbo-confirm]"
  end

  describe "GET /quotes" do
    it "lists quotes ordered by created_at descending" do
      older = create(:quote, name: "Devis A", created_at: 2.days.ago)
      newer = create(:quote, name: "Devis B", created_at: 1.day.ago)

      get quotes_path

      expect(response).to have_http_status(:ok)
      expect(response.body.index(newer.name)).to be < response.body.index(older.name)
    end

    it "offers a destructive action on a draft quote and none on a validated one" do
      draft = create(:quote, status: :draft)
      validated = create(:quote, status: :validated, validated_at: Time.current)

      get quotes_path
      rendered = Capybara.string(response.body)

      # button_to renders the HTTP verb as a hidden input, hence visible: :all at the call
      # site. Without it the selector matches nothing, the positive assertion fails and the
      # negative one passes for the wrong reason.
      expect(rendered).to have_css(destroy_affordance_for(draft), visible: :all)
      expect(rendered).to have_no_css(destroy_affordance_for(validated), visible: :all)
    end

    it "asks for confirmation before deleting a draft quote" do
      draft = create(:quote, status: :draft)

      get quotes_path
      rendered = Capybara.string(response.body)

      expect(rendered).to have_css(confirmation_affordance_for(draft))
    end
  end

  describe "POST /quotes" do
    context "with a valid name" do
      it "creates the quote and redirects to it with a 303" do
        expect {
          post quotes_path, params: { quote: { name: "Devis salle de réception" } }
        }.to change(Quote, :count).by(1)

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(quote_path(Quote.last))
      end

      it "ignores a status slipped into the parameters" do
        post quotes_path, params: { quote: { name: "Devis", status: "validated" } }

        expect(Quote.last).to be_draft
        expect(Quote.last.validated_at).to be_nil
      end
    end

    context "with a blank name" do
      it "does not create a quote and responds 422" do
        expect {
          post quotes_path, params: { quote: { name: "" } }
        }.not_to change(Quote, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /quotes/:id" do
    it "displays the quote" do
      quote = create(:quote, name: "Devis salle de réception")

      get quote_path(quote)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(quote.name)
    end

    context "when the quote is a draft" do
      it "renders the draft variant with an editable name and the save-and-exit action" do
        quote = create(:quote, name: "Devis salle de réception", status: :draft)

        get quote_path(quote)
        rendered = Capybara.string(response.body)

        expect(rendered).to have_css("input[name='quote[name]'][value='#{quote.name}']")
        expect(rendered).to have_content("En cours d'édition")
        expect(rendered).to have_button("Enregistrer et quitter")
        expect(rendered).to have_no_link("Quitter")
      end

      it "formats amounts and VAT rates with French conventions" do
        quote = create(:quote, status: :draft)
        create(:quote_item, quote: quote, quantity: 1, unit_price_excl_vat: 1234.56, vat_rate: 5.5)

        get quote_path(quote)

        # The separators come from rails-i18n's fr locale: U+202F narrow no-break space between
        # the thousands and before the unit. Written as escapes rather than pasted, so the
        # assertion survives an editor normalising invisible characters.
        expect(response.body).to include("1\u{202F}234,56\u{202F}€")
        expect(response.body).to include("5,5\u{202F}%")
      end
    end

    context "when the quote is validated" do
      it "renders the read-only variant with a plain exit link and no draft affordances" do
        quote = create(:quote, status: :validated, validated_at: Time.current)

        get quote_path(quote)
        rendered = Capybara.string(response.body)

        expect(rendered).to have_content("Validé")
        expect(rendered).to have_link("Quitter", href: quotes_path)
        expect(rendered).to have_no_css("input[name='quote[name]']")
        expect(rendered).to have_no_button("Enregistrer et quitter")
      end
    end
  end

  describe "PATCH /quotes/:id" do
    context "with a valid name" do
      it "renames the quote and redirects to the list with a 303" do
        quote = create(:quote, name: "Ancien nom", status: :draft)

        patch quote_path(quote), params: { quote: { name: "Nouveau nom" } }

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(quotes_path)
        expect(quote.reload.name).to eq("Nouveau nom")
      end

      it "ignores a status slipped into the parameters" do
        quote = create(:quote, name: "Nom", status: :draft)

        patch quote_path(quote), params: { quote: { name: "Nom", status: "validated" } }

        expect(quote.reload).to be_draft
        expect(quote.validated_at).to be_nil
      end
    end

    context "with a blank name" do
      it "does not persist the change and responds 422, re-rendering the screen" do
        quote = create(:quote, name: "Nom initial", status: :draft)

        patch quote_path(quote), params: { quote: { name: "" } }

        rendered = Capybara.string(response.body)

        expect(rendered).to have_css("input[name='quote[name]']")
        expect(rendered).to have_content(I18n.t("activerecord.errors.models.quote.attributes.name.blank"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(quote.reload.name).to eq("Nom initial")
      end
    end
  end

  describe "DELETE /quotes/:id" do
    it "destroys the quote and its items, redirecting with a 303" do
      quote = create(:quote)
      create(:quote_item, quote: quote)

      expect {
        delete quote_path(quote)
      }.to change(Quote, :count).by(-1).and change(QuoteItem, :count).by(-1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(quotes_path)
    end
  end
end
