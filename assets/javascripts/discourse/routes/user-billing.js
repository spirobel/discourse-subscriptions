import Route from "@ember/routing/route";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default Route.extend({
  templateName: "user/billing",
  router: service(),
  @action
  updateSubscriptions() {
    ajax(`/subscriptions/user/subscriptions/portalsession`, {
      method: "POST",
    }).then((result) => {
      if (result.url) {
        window.location.replace(result.url);
      } else {
        this.router.transitionTo("subscriptions");
      }
    });
  },
});
