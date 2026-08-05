class Quote < ApplicationRecord
  enum :status, { draft: "draft", validated: "validated" }, default: :draft

  has_many :quote_items, -> { order(:id) }, dependent: :destroy

  validates :name, presence: true
  validate :must_have_at_least_one_item, on: :finalize

  def finalize!
    self.status = :validated
    self.validated_at = Time.current
    save(context: :finalize)
  end

  private

  def must_have_at_least_one_item
    errors.add(:base, :no_item) if quote_items.empty?
  end
end
