class Quote < ApplicationRecord
  enum :status, { draft: "draft", validated: "validated" }, default: :draft

  has_many :quote_items, -> { order(:id) }, dependent: :destroy

  validates :name, presence: true
end
