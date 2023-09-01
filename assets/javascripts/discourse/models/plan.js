import EmberObject, { computed } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";

const Plan = EmberObject.extend({
  amountDollars: computed("unit_amount", {
    get() {
      return parseFloat(this.get("unit_amount") / 100).toFixed(2);
    },
    set(key, value) {
      const decimal = parseFloat(value) * 100;
      this.set("unit_amount", decimal);
      return value;
    },
  }),
  @discourseComputed("recurring.interval", "recurring.interval_count")
  billingInterval(interval, interval_count) {
    if (interval_count) {
      return interval_count + " " + interval;
    } else {
      return I18n.t("discourse_subscriptions.one_time_payment");
    }
  },

  @discourseComputed("amountDollars", "currency", "billingInterval")
  subscriptionRate(amountDollars, currency, interval) {
    return `${amountDollars} ${currency.toUpperCase()} / ${interval}`;
  },
});

export default Plan;
