require "rails_helper"

RSpec.describe "Quote screen, validating a draft", type: :system do
  it "enables the validate button as soon as an item is added, with no reload, and validates on confirm" do
    quote = create(:quote, name: "Devis salle de réception")
    visit quote_path(quote)

    expect(page).to have_button("Valider le devis", disabled: true)
    expect(page).to have_content("Ajoutez au moins un article avant de valider le devis")

    click_link "Ajouter un article"
    fill_in "quote_item_name", with: "Location de salle"
    fill_in "quote_item_quantity", with: "1"
    fill_in "quote_item_unit_price_excl_vat", with: "100"
    select "20\u{202F}%", from: "quote_item_vat_rate"
    click_button "Valider"

    expect(page).to have_button("Valider le devis", disabled: false)
    expect(page).to have_no_content("Ajoutez au moins un article avant de valider le devis")

    accept_confirm do
      click_button "Valider le devis"
    end

    expect(page).to have_content("Validé")
    expect(page).to have_current_path(quote_path(quote))
    expect(quote.reload).to be_validated
  end

  it "disables the validate button again once the only item is removed" do
    quote = create(:quote)
    create(:quote_item, quote: quote)
    visit quote_path(quote)

    expect(page).to have_button("Valider le devis", disabled: false)

    accept_confirm do
      click_button "Supprimer"
    end

    expect(page).to have_button("Valider le devis", disabled: true)
  end

  it "dismisses the confirmation without validating" do
    quote = create(:quote)
    create(:quote_item, quote: quote)
    visit quote_path(quote)

    dismiss_confirm do
      click_button "Valider le devis"
    end

    expect(page).to have_content("En cours d'édition")
    expect(quote.reload).to be_draft
  end
end
