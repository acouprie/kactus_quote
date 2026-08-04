class QuoteTotals
  Line = Struct.new(:item, :line_net_amount, :line_vat_amount, :line_gross_amount, keyword_init: true)

  ROUNDING_MODE = BigDecimal::ROUND_HALF_UP
  ZERO = BigDecimal("0")

  def initialize(quote)
    @quote = quote
  end

  def lines
    compute!
    @lines
  end

  def total_net_amount
    compute!
    @total_net_amount
  end

  def total_vat_amount
    compute!
    @total_vat_amount
  end

  def total_gross_amount
    compute!
    @total_gross_amount
  end

  private

  attr_reader :quote

  def compute!
    return if defined?(@lines)

    items = quote.quote_items.to_a
    net_amounts = items.each_with_object({}) { |item, amounts| amounts[item] = line_net_amount_for(item) }
    lines_by_item = {}

    items.group_by(&:vat_rate).each do |rate, group_items|
      group_net_subtotal = group_items.sum(ZERO) { |item| net_amounts[item] }
      group_vat_amount = round_half_up(group_net_subtotal * rate / 100)

      allocate_group_vat(group_items, net_amounts, group_vat_amount).each do |item, line_vat_amount|
        lines_by_item[item] = Line.new(
          item: item,
          line_net_amount: net_amounts[item],
          line_vat_amount: line_vat_amount,
          line_gross_amount: net_amounts[item] + line_vat_amount
        )
      end
    end

    @lines = items.map { |item| lines_by_item.fetch(item) }
    @total_net_amount = items.sum(ZERO) { |item| net_amounts[item] }
    @total_vat_amount = lines_by_item.values.sum(ZERO, &:line_vat_amount)
    @total_gross_amount = @total_net_amount + @total_vat_amount
  end

  def line_net_amount_for(item)
    round_half_up(item.quantity * item.unit_price_excl_vat)
  end

  # Largest-remainder allocation: each line's exact VAT is kept as a Rational
  # (never rounded) until it is split into a floor and a remainder, so the
  # cents distributed always add up to the group's authoritative VAT.
  def allocate_group_vat(group_items, net_amounts, group_vat_amount)
    exact_cents = group_items.each_with_object({}) do |item, exact|
      exact[item] = Rational(to_cents(net_amounts[item])) * item.vat_rate.to_r / 100
    end
    floor_cents = exact_cents.transform_values(&:floor)
    remainders = group_items.index_with { |item| exact_cents[item] - floor_cents[item] }

    cents_to_distribute = to_cents(group_vat_amount) - floor_cents.values.sum
    items_receiving_extra_cent = group_items
      .sort_by { |item| [ -remainders[item], item.id ] }
      .first(cents_to_distribute)

    group_items.each_with_object({}) do |item, line_vat_amounts|
      cents = floor_cents[item] + (items_receiving_extra_cent.include?(item) ? 1 : 0)
      line_vat_amounts[item] = cents_to_amount(cents)
    end
  end

  def round_half_up(amount)
    amount.round(2, ROUNDING_MODE)
  end

  def to_cents(amount)
    (amount * 100).round(0, ROUNDING_MODE).to_i
  end

  def cents_to_amount(cents)
    BigDecimal(cents) / BigDecimal(100)
  end
end
