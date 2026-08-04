require "rails_helper"

RSpec.describe "Quotes list, inline creation row", type: :system do
  it "navigates to the quote's own screen after a successful creation" do
    visit quotes_path

    click_link "Ajouter un devis"
    fill_in "quote_name", with: "Devis salle de réception"
    click_button "Valider"

    expect(page).to have_field("quote_name", with: "Devis salle de réception")
    expect(page).to have_current_path(quote_path(Quote.last))
    expect(page).not_to have_content("Content missing")
  end

  it "dismisses the row on Escape, persisting nothing and issuing no request" do
    visit quotes_path

    click_link "Ajouter un devis"
    fill_in "quote_name", with: "Ne doit pas être créé"

    requests = []
    subscription = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
      requests << payload
    end

    begin
      find_field("quote_name").send_keys(:escape)
      expect(page).to have_link("Ajouter un devis")
      expect(page).to have_no_field("quote_name")
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end

    expect(requests).to be_empty
    expect(Quote.count).to eq(0)
  end

  it "still dismisses the row via Annuler after a previous validation error" do
    visit quotes_path

    click_link "Ajouter un devis"
    click_button "Valider"
    expect(page).to have_content("Nom ne peut pas être vide")

    click_button "Annuler"

    expect(page).to have_link("Ajouter un devis")
    expect(page).to have_no_content("Nom ne peut pas être vide")
  end
end
