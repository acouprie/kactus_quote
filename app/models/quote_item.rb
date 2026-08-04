class QuoteItem < ApplicationRecord
  MAX_AMOUNT = 99_999.99
  ALLOWED_VAT_RATES = [ 0, 5.5, 10, 20 ].freeze

  belongs_to :quote

  validates :name, presence: true
  validates :quantity, numericality: { greater_than: 0, less_than_or_equal_to: MAX_AMOUNT }
  validates :unit_price_excl_vat,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_AMOUNT }
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

  def normalize_decimal_separator(value)
    return value unless value.is_a?(String)

    value.tr(",", ".")
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
