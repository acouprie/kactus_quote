class CreateQuoteItems < ActiveRecord::Migration[7.2]
  def change
    create_table :quote_items do |t|
      t.references :quote, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.decimal :unit_price_excl_vat, precision: 12, scale: 2, null: false
      t.decimal :vat_rate, precision: 5, scale: 2, null: false

      t.timestamps
    end
  end
end
