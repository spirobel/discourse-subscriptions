import AdminSubscription from "discourse/plugins/discourse-subscriptions/discourse/models/admin-subscription";
import Controller from "@ember/controller";
import showModal from "discourse/lib/show-modal";
import { action } from "@ember/object";

export default Controller.extend({
  loading: false,

  @action
  loadMore() {
    if (!this.loading && this.model.has_more) {
      this.set("loading", true);

      return AdminSubscription.loadMore(this.model.last_record).then(
        (result) => {
          const updated = this.model.data.concat(result.data);
          this.set("model", result);
          this.set("model.data", updated);
          this.set("loading", false);
        }
      );
    }
  },

  @action
  editOrInviteUser(subscription) {
    showModal("subscription-user-selection", {
      modalClass: "subscription-user-selection",
      panels: [
        {
          id: "subscription-user-selection",
          title: "discourse_subscriptions.admin.customer.select_user.title",
          model: {
            inviteModel: subscription,
          },
        },
      ],
    });
  },
});
