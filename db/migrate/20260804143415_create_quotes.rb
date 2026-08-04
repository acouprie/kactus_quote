class CreateQuotes < ActiveRecord::Migration[7.2]
  def change
    create_table :quotes do |t|
      t.string :name, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :validated_at

      t.timestamps
    end
  end
end
