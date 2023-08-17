# frozen_string_literal: true

class AddInviteToSubscriptionsCustomers < ActiveRecord::Migration[7.0]
  def change
    add_reference :discourse_subscriptions_customers, :invite, foreign_key: true
  end
end
