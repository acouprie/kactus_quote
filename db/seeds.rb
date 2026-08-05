# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Several VAT rates on one quote.
quote = Quote.find_or_create_by!(name: "Anniversaire Dupont - salle et traiteur")
if quote.quote_items.none?
  quote.quote_items.create!(name: "Location de salle", quantity: 1, unit_price_excl_vat: 1_500, vat_rate: 20)
  quote.quote_items.create!(name: "Prestation traiteur (50 couverts)", quantity: 50, unit_price_excl_vat: 45,
                             vat_rate: 10)
  quote.quote_items.create!(name: "Pièce montée", quantity: 1, unit_price_excl_vat: 180, vat_rate: 5.5)
  quote.quote_items.create!(name: "Frais de dossier (partenaire en franchise de TVA)", quantity: 1,
                             unit_price_excl_vat: 50, vat_rate: 0)
end

# A rate group where the cent reallocation actually fires: twelve lines at 1,09 € and 5,5 % each
# have an exact VAT of 5,995 cents, floored to 5, so the floors sum to 60 cents while the group's
# authoritative VAT on 13,08 € rounds to 72 cents. The 12 missing cents get spread one per line.
# See docs/logbook.md, "The VAT computation contract".
quote = Quote.find_or_create_by!(name: "Séminaire entreprise - forfaits techniques")
if quote.quote_items.none?
  12.times do |i|
    quote.quote_items.create!(name: "Forfait technique poste #{i + 1}", quantity: 1, unit_price_excl_vat: 1.09,
                               vat_rate: 5.5)
  end
end

# A quote made only of 0 % lines.
quote = Quote.find_or_create_by!(name: "Mariage - prestataire en franchise de TVA")
if quote.quote_items.none?
  quote.quote_items.create!(name: "Animation musicale", quantity: 1, unit_price_excl_vat: 600, vat_rate: 0)
  quote.quote_items.create!(name: "Décoration florale", quantity: 1, unit_price_excl_vat: 350, vat_rate: 0)
  quote.quote_items.create!(name: "Photographe", quantity: 8, unit_price_excl_vat: 90, vat_rate: 0)
end

# An empty draft.
Quote.find_or_create_by!(name: "Brouillon vide")

# An already validated quote. Items are immutable once the quote is validated, so they have to be
# added while it is still a draft; the quote is only finalized once they are in place.
quote = Quote.find_or_create_by!(name: "Cocktail d'entreprise")
if quote.draft?
  quote.quote_items.create!(name: "Location de salle", quantity: 1, unit_price_excl_vat: 900, vat_rate: 20)
  quote.quote_items.create!(name: "Cocktail dînatoire (30 personnes)", quantity: 30, unit_price_excl_vat: 38,
                             vat_rate: 10)
  quote.finalize!
end
