import { Controller } from "@hotwired/stimulus"

// Computes a live preview of a line's net amount (quantity * unit price)
// while typing, for immediate feedback only. QuoteTotals, server side, stays
// the single source of truth for every persisted and displayed amount: this
// preview is never submitted and never touches VAT or the cent allocation.
export default class extends Controller {
  static targets = [ "quantity", "unitPrice", "netPreview" ]

  compute() {
    const quantity = this.parseNumber(this.quantityTarget.value)
    const unitPrice = this.parseNumber(this.unitPriceTarget.value)

    if (quantity === null || unitPrice === null) {
      this.netPreviewTarget.textContent = "—"
      return
    }

    this.netPreviewTarget.textContent = (quantity * unitPrice).toLocaleString("fr-FR", {
      style: "currency",
      currency: "EUR"
    })
  }

  parseNumber(rawValue) {
    const normalized = rawValue.trim().replace(/,/g, ".").replace(/\s/g, "")
    if (normalized === "") return null

    const value = Number(normalized)
    return Number.isFinite(value) ? value : null
  }
}
