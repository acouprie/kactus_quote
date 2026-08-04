class QuoteItem < ApplicationRecord
  MAX_INPUT_VALUE = BigDecimal("99999.99")
  ALLOWED_VAT_RATES = %w[0 5.5 10 20].map { |rate| BigDecimal(rate) }.freeze

  belongs_to :quote

  before_save :raise_if_quote_validated_in_database
  before_destroy :raise_if_quote_validated_in_database

  validates :name, presence: true
  validates :quantity, numericality: { greater_than: 0, less_than_or_equal_to: MAX_INPUT_VALUE }
  validates :unit_price_excl_vat,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_INPUT_VALUE }
  validates :vat_rate, inclusion: { in: ALLOWED_VAT_RATES }

  validate :quantity_scale_must_not_exceed_column_precision
  validate :unit_price_excl_vat_scale_must_not_exceed_column_precision

  def quantity=(value)
    super(normalize_decimal_separator(value))
  end

  def unit_price_excl_vat=(value)
    super(normalize_decimal_separator(value))
  end

  private

  # Asks the parent quote on every write, so this holds even for an item saved or destroyed
  # without going through Quotes::ItemsController.
  def raise_if_quote_validated_in_database
    raise Quote::ImmutableError if quote.validated_in_database?
  end

  def normalize_decimal_separator(value)
    return value unless value.is_a?(String)

    # Replace comma with dot and remove all spaces
    value.tr(",", ".").delete(" \u00A0\u202F")
  end

  def quantity_scale_must_not_exceed_column_precision
    validate_scale(:quantity)
  end

  def unit_price_excl_vat_scale_must_not_exceed_column_precision
    validate_scale(:unit_price_excl_vat)
  end

  # ActiveModel::Type::Decimal#cast_value rounds to the column's scale at
  # assignment time, so the cast attribute never shows the extra decimals.
  # Reading *_before_type_cast is the only way to catch them.
  def validate_scale(attribute)
    raw_value = public_send(:"#{attribute}_before_type_cast")
    decimal_part = raw_value.to_s.split(".")[1]
    return if decimal_part.nil?

    scale = self.class.columns_hash[attribute.to_s].scale
    return if decimal_part.length <= scale

    errors.add(attribute, "has too many decimal places")
  end
end
