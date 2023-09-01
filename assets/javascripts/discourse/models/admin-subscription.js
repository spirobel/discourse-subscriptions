import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import EmberObject from "@ember/object";

const AdminSubscription = EmberObject.extend({
  @discourseComputed("status")
  canceled(status) {
    return status === "canceled";
  },

  @discourseComputed("metadata")
  metadataUserExists(metadata) {
    return metadata.user_id && metadata.username;
  },

  destroy(refund) {
    const data = {
      refund,
    };
    return ajax(`/s/admin/subscriptions/${this.id}`, {
      method: "delete",
      data,
    }).then((result) => AdminSubscription.create(result));
  },
  createInvite(user, custom_message) {
    return ajax(`/subscriptions/admin/subscriptions/${this.id}`, {
      type: "PATCH",
      data: { user, custom_message },
    });
  },
});

AdminSubscription.reopenClass({
  find() {
    return ajax("/subscriptions/admin/subscriptions", {
      method: "get",
    }).then((result) => {
      if (result === null) {
        return { unconfigured: true };
      }
      result.data = result.data.map((subscription) =>
        AdminSubscription.create(subscription)
      );
      return result;
    });
  },
  loadMore(lastRecord) {
    return ajax(
      `/subscriptions/admin/subscriptions?last_record=${lastRecord}`,
      {
        method: "get",
      }
    ).then((result) => {
      result.data = result.data.map((subscription) =>
        AdminSubscription.create(subscription)
      );
      return result;
    });
  },
});

export default AdminSubscription;
