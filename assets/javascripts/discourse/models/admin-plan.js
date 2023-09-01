import Plan from "discourse/plugins/discourse-subscriptions/discourse/models/plan";
import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";

const AdminPlan = Plan.extend({
  isNew: false,
  name: "",
  interval: "month",
  unit_amount: 0,
  intervals: ["day", "week", "month", "year"],
  metadata: {},
  buffered_group: "",

  @discourseComputed("trial_period_days")
  parseTrialPeriodDays(trialDays) {
    if (trialDays) {
      return parseInt(0 + trialDays, 10);
    } else {
      return 0;
    }
  },

  save() {
    const data = {
      nickname: this.nickname,
      interval: this.interval,
      amount: this.unit_amount,
      currency: this.currency,
      trial_period_days: this.parseTrialPeriodDays,
      type: this.type,
      product: this.product,
      metadata: this.metadata,
      active: this.active,
    };

    return ajax("/subscriptions/admin/plans", { method: "post", data });
  },

  update(bufferedGroup) {
    const data = {
      buffered_group: bufferedGroup,
    };

    return ajax(`/subscriptions/admin/plans/${this.id}`, {
      method: "patch",
      data,
    });
  },
});

AdminPlan.reopenClass({
  findAll(data) {
    return ajax("/subscriptions/admin/plans", { method: "get", data }).then(
      (result) =>
        result.map((plan) => {
          if (plan.metadata && plan.metadata.group_name) {
            plan.buffered_group = plan.metadata.group_name;
          }
          return AdminPlan.create(plan);
        })
    );
  },

  find(id) {
    return ajax(`/subscriptions/admin/plans/${id}`, { method: "get" }).then(
      (plan) => {
        if (plan.metadata && plan.metadata.group_name) {
          plan.buffered_group = plan.metadata.group_name;
        }
        return AdminPlan.create(plan);
      }
    );
  },
});

export default AdminPlan;
