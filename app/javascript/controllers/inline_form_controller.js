import { Controller } from "@hotwired/stimulus"

// Controls a turbo-frame that toggles between a trigger link and an inline
// form (add-quote row, add-item row). Cancelling restores the trigger
// client side, without any request, since Turbo has no built-in way to
// dismiss a frame it navigated into. The trigger markup comes from a value
// set by the server on every render, rather than being captured from the
// DOM at connect time: after a validation error the frame's initial
// content is the errored form, not the trigger, so capturing it would
// make cancel a no-op.
export default class extends Controller {
  static values = { trigger: String }

  cancel() {
    this.element.innerHTML = this.triggerValue
  }
}
