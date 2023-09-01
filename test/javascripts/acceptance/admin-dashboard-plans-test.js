import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Discourse Subscriptions", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/subscriptions/admin/plans", () => helper.response([]));
  });

  test("Admin dashboard plans list unconfigured shows hint", async function (assert) {
    await visit("/admin/plugins/discourse-subscriptions/plans");
    assert.true(
      document.documentElement.innerHTML.includes(
        "Stripe is not configured correctly. Please see Discourse Meta for information."
      )
    );
  });
});
acceptance("Discourse Subscriptions, stripe key configured:", function (needs) {
  needs.user();
  needs.settings({
    discourse_subscriptions_public_key: "stripekey",
  });
  needs.pretender((server, helper) => {
    server.get("/subscriptions/admin/plans", () => helper.response([]));
  });

  test("Admin dashboard plans list no plans", async function (assert) {
    await visit("/admin/plugins/discourse-subscriptions/plans");
    assert.true(
      document.documentElement.innerHTML.includes(
        "Before cutomers can subscribe to your site,"
      )
    );
  });

  test("Admin dashboard shows to stripe dashboard notice", async function (assert) {
    await visit("/admin/plugins/discourse-subscriptions/plans");
    assert.true(
      document.documentElement.innerHTML.includes(
        "To create pricing tables, plans and products,"
      )
    );
  });
});
