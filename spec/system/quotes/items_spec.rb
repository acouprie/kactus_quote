require "rails_helper"

RSpec.describe "Quote screen, item table", type: :system do
  it "adds three items in a row with no click other than the submits, updating the totals each time" do
    quote = create(:quote, name: "Devis salle de réception")
    visit quote_path(quote)

    click_link "Ajouter un article"

    3.times do |n|
      fill_in "quote_item_name", with: "Article #{n + 1}"
      fill_in "quote_item_quantity", with: "1"
      fill_in "quote_item_unit_price_excl_vat", with: "100"
      find("#quote_item_vat_rate option[value='20.0']").select_option
      click_button "Valider"

      expect(page).to have_content("Article #{n + 1}")
      within "#quote_totals" do
        expect(page).to have_content(ApplicationController.helpers.number_to_currency((n + 1) * 100))
      end
    end

    expect(QuoteItem.count).to eq(3)
  end

  it "dismisses the add-item row on Escape, persisting nothing and issuing no request" do
    quote = create(:quote)
    visit quote_path(quote)

    click_link "Ajouter un article"
    fill_in "quote_item_name", with: "Ne doit pas être créé"

    requests = []
    subscription = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
      requests << payload
    end

    begin
      find_field("quote_item_name").send_keys(:escape)
      expect(page).to have_link("Ajouter un article")
      expect(page).to have_no_field("quote_item_name")
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end

    expect(requests).to be_empty
    expect(QuoteItem.count).to eq(0)
  end
end
