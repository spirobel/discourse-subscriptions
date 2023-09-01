import Route from "@ember/routing/route";
import AdminPlan from "discourse/plugins/discourse-subscriptions/discourse/models/admin-plan";
import Group from "discourse/models/group";

export default Route.extend({
  model() {
    return AdminPlan.findAll();
  },
  afterModel(model) {
    if (this.currentUser.admin) {
      return Group.findAll().then((groups) => {
        this._availableGroups = groups.filterBy("automatic", false);
        return model;
      });
    }
  },

  setupController(controller, model) {
    controller.setProperties({
      //originalPrimaryGroupId: model.primary_group_id,
      availableGroups: this._availableGroups,
      //customGroupIdsBuffer: model.customGroups.mapBy("id"),
      model,
      dirty: true,
      groupFinder(term) {
        return Group.findAll({ term, ignore_automatic: true });
      },
    });
  },
});
