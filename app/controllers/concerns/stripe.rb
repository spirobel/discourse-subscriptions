# frozen_string_literal: true

module DiscourseSubscriptions
  module Stripe
    extend ActiveSupport::Concern

    def set_api_key
      ::Stripe.api_key = SiteSetting.discourse_subscriptions_secret_key
    end

    def is_stripe_configured?
      SiteSetting.discourse_subscriptions_public_key.present? &&
        SiteSetting.discourse_subscriptions_secret_key.present?
    end

    def get_checkout_sessions()
      cs = []
      current_set = { has_more: true, last_record: nil }

      until current_set[:has_more] == false
        current_set =
          ::Stripe::Checkout::Session.list(limit: 100, starting_after: current_set[:last_record])

        current_set[:last_record] = current_set[:data].last[:id] if current_set[:data].present?
        cs.concat(current_set[:data].to_a)
      end

      cs
    end

    def get_subscription_data(price = nil)
      subscriptions = []
      current_set = { has_more: true, last_record: nil }

      until current_set[:has_more] == false
        current_set =
          if price
            ::Stripe::Subscription.list(
              expand: %w[data.plan.product data.customer],
              price: price,
              limit: 100,
              starting_after: current_set[:last_record],
            )
          else
            ::Stripe::Subscription.list(
              expand: %w[data.plan.product data.customer],
              limit: 100,
              starting_after: current_set[:last_record],
            )
          end

        current_set[:last_record] = current_set[:data].last[:id] if current_set[:data].present?
        subscriptions.concat(current_set[:data].to_a)
      end

      subscriptions
    end
  end
end
