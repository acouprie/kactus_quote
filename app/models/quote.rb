class Quote < ApplicationRecord
  class ImmutableError < StandardError; end

  enum :status, { draft: "draft", validated: "validated" }, default: :draft

  has_many :quote_items, -> { order(:id) }, dependent: :destroy

  validates :name, presence: true
  validate :must_have_at_least_one_item, on: :finalize

  before_update :raise_if_validated_in_database
  before_destroy :raise_if_validated_in_database

  def finalize
    self.status = :validated
    self.validated_at = Time.current
    save(context: :finalize)
  end

  # Read by QuoteItem's own guard, so a validated quote's items are immutable too.
  def validated_in_database?
    status_in_database == "validated"
  end

  private

  def must_have_at_least_one_item
    errors.add(:base, :no_item) if quote_items.empty?
  end

  # Reads the persisted status, never the in-memory one: finalize assigns status = :validated
  # before saving, so an in-memory read would make the draft-to-validated transition refuse itself.
  def raise_if_validated_in_database
    raise ImmutableError if validated_in_database?
  end
end
