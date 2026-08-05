require "rails_helper"

RSpec.describe "Full quote flow, from an empty list to a validated quote", type: :system do
  it "creates a quote, adds items at different VAT rates, updates totals live, and locks the quote once validated" do
    currency = ->(amount) { ApplicationController.helpers.number_to_currency(amount) }

    visit quotes_path

    click_link "Ajouter un devis"
    fill_in "quote_name", with: "Séminaire annuel"
    click_button "Valider"

    expect(page).to have_content("En cours d'édition")
    quote = Quote.last
    expect(page).to have_current_path(quote_path(quote))

    click_link "Ajouter un article"

    fill_in "quote_item_name", with: "Location de salle"
    fill_in "quote_item_quantity", with: "1"
    fill_in "quote_item_unit_price_excl_vat", with: "1000"
    select "20\u{202F}%", from: "quote_item_vat_rate"
    click_button "Valider"

    within "#quote_totals" do
      expect(page).to have_content(currency.call(1000))
      expect(page).to have_content(currency.call(200))
      expect(page).to have_content(currency.call(1200))
    end

    # The add-item form resets and keeps focus after a successful submission, so the next
    # item is added without clicking "Ajouter un article" again.
    fill_in "quote_item_name", with: "Prestation traiteur"
    fill_in "quote_item_quantity", with: "10"
    fill_in "quote_item_unit_price_excl_vat", with: "45"
    select "10\u{202F}%", from: "quote_item_vat_rate"
    click_button "Valider"

    within "#quote_totals" do
      expect(page).to have_content(currency.call(1450))
      expect(page).to have_content(currency.call(245))
      expect(page).to have_content(currency.call(1695))
    end

    fill_in "quote_item_name", with: "Frais de dossier"
    fill_in "quote_item_quantity", with: "1"
    fill_in "quote_item_unit_price_excl_vat", with: "50"
    select "0\u{202F}%", from: "quote_item_vat_rate"
    click_button "Valider"

    within "#quote_totals" do
      expect(page).to have_content(currency.call(1500))
      expect(page).to have_content(currency.call(245))
      expect(page).to have_content(currency.call(1745))
    end

    expect(quote.quote_items.count).to eq(3)

    accept_confirm do
      click_button "Valider le devis"
    end

    expect(page).to have_current_path(quote_path(quote))
    expect(page).to have_content("Validé")
    expect(quote.reload).to be_validated

    expect(page).to have_content("Location de salle")
    expect(page).to have_content("Prestation traiteur")
    expect(page).to have_content("Frais de dossier")
    within "#quote_totals" do
      expect(page).to have_content(currency.call(1500))
      expect(page).to have_content(currency.call(245))
      expect(page).to have_content(currency.call(1745))
    end

    expect(page).to have_no_link("Ajouter un article")
    expect(page).to have_no_button("Supprimer")
    expect(page).to have_no_button("Éditer")

    click_link "Quitter"

    expect(page).to have_current_path(quotes_path)
    within "#quote_#{quote.id}" do
      expect(page).to have_link("Voir")
      expect(page).to have_no_link("Éditer")
      expect(page).to have_no_button("Supprimer")
    end
  end
end
