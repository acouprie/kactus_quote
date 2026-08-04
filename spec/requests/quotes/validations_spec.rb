require "rails_helper"

RSpec.describe "Quotes::Validations", type: :request do
  describe "POST /quotes/:quote_id/validation" do
    context "when the quote has at least one item" do
      it "validates the quote and redirects to it with a 303" do
        quote = create(:quote, status: :draft)
        create(:quote_item, quote: quote)

        post quote_validation_path(quote)

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(quote_path(quote))
        expect(quote.reload).to be_validated
        expect(quote.validated_at).to be_present
      end
    end

    context "when the quote has no item" do
      it "refuses with a 422, replacing the flash, and the quote stays a draft" do
        quote = create(:quote, status: :draft)

        post quote_validation_path(quote), as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
        expect(quote.reload).to be_draft
        expect(quote.validated_at).to be_nil

        rendered = Capybara.string(response.body)
        expect(rendered).to have_css("turbo-stream[action='replace'][target='quote_flash']")
        expect(response.body).to include(I18n.t("activerecord.errors.models.quote.attributes.base.no_item"))
      end

      it "refuses even when the request bypasses the disabled button entirely" do
        quote = create(:quote, status: :draft)

        post quote_validation_path(quote), as: :turbo_stream

        expect(quote.reload).to be_draft
      end
    end
  end

  describe "GET /quotes/:id, draft screen validate button" do
    it "disables the validate button when the quote has no item" do
      quote = create(:quote, status: :draft)

      get quote_path(quote)
      rendered = Capybara.string(response.body)

      expect(rendered).to have_button("Valider le devis", disabled: true)
    end

    it "enables the validate button once the quote has an item" do
      quote = create(:quote, status: :draft)
      create(:quote_item, quote: quote)

      get quote_path(quote)
      rendered = Capybara.string(response.body)

      expect(rendered).to have_button("Valider le devis", disabled: false)
    end
  end
end
