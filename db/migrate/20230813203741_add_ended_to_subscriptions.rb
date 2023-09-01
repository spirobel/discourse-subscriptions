# frozen_string_literal: true

class AddEndedToSubscriptions < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_subscriptions_subscriptions, :ended, :boolean
  end
end
