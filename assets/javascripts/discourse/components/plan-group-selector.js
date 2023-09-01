import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { isNone } from "@ember/utils";
import { action } from "@ember/object";

export default Component.extend({
  classNames: ["plan-group-selector-wrapper"],
  init() {
    this._super(...arguments);

    if (this.plan.metadata && this.plan.metadata.group_name) {
      this.bufferedGroup = this.plan.metadata.group_name;
    }
  },
  @discourseComputed("bufferedGroup", "plan.metadata.group_name")
  dirty(bufferVal, settingVal) {
    if (isNone(bufferVal)) {
      bufferVal = "";
    }

    if (isNone(settingVal)) {
      settingVal = "";
    }

    return bufferVal.toString() !== settingVal.toString();
  },
  @action
  cancel() {
    this.set("bufferedGroup", this.plan.metadata.group_name);
  },
  @action
  update() {
    this.plan.update(this.bufferedGroup).then((result) => {
      this.set("bufferedGroup", result.metadata.group_name);
      this.plan.set("metadata", { group_name: result.metadata.group_name });
    });
  },
  plan: null,
  availableGroups: [],
});
