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
