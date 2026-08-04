FactoryBot.define do
  factory :quote_item do
    quote
    name { "Location de salle" }
    quantity { 1 }
    unit_price_excl_vat { 100 }
    vat_rate { 20 }
  end
end
