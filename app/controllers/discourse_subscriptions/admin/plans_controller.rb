# frozen_string_literal: true

module DiscourseSubscriptions
  module Admin
    class PlansController < ::Admin::AdminController
      include DiscourseSubscriptions::Stripe

      before_action :set_api_key

      def index
        begin
          plans = ::Stripe::Price.list({ limit: 100 })
          products = ::Stripe::Product.list({ limit: 100 })

          plans.data.each do |plan|
            products.data.each do |product|
              plan.product_name = product.name if plan.product == product.id
            end
          end
          puts products
          render_json_dump plans.data
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def create
        begin
          price_object = {
            nickname: params[:nickname],
            unit_amount: params[:amount],
            product: params[:product],
            currency: params[:currency],
            active: params[:active],
            metadata: {
              group_name: params[:metadata][:group_name],
              trial_period_days: params[:trial_period_days],
            },
          }

          price_object[:recurring] = { interval: params[:interval] } if params[:type] == "recurring"

          plan = ::Stripe::Price.create(price_object)

          render_json_dump plan
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def show
        begin
          plan = ::Stripe::Price.retrieve(params[:id])

          if plan[:metadata] && plan[:metadata][:trial_period_days]
            trial_days = plan[:metadata][:trial_period_days]
          elsif plan[:recurring] && plan[:recurring][:trial_period_days]
            trial_days = plan[:recurring][:trial_period_days]
          end

          interval = nil
          interval = plan[:recurring][:interval] if plan[:recurring] && plan[:recurring][:interval]

          serialized =
            plan.to_h.merge(
              trial_period_days: trial_days,
              currency: plan[:currency].upcase,
              interval: interval,
            )

          render_json_dump serialized
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def update
        begin
          plan =
            ::Stripe::Price.update(params[:id], metadata: { group_name: params[:buffered_group] })
          group = ::Group.find_by_name(params[:buffered_group])

          unless group.nil?
            if plan.recurring.nil?
              checkout_sessions = get_checkout_sessions
              checkout_sessions.each do |cs|
                if cs.status == "complete"
                  customer = Customer.find_by(customer_id: cs[:id])
                  unless customer.nil?
                    line_items =
                      ::Stripe::Checkout::Session.list_line_items(cs[:id], { limit: 100 })
                    line_items.each do |item|
                      group = plan_group(item[:price]) unless item[:price].nil?
                      group.add(customer.user) unless group.nil?
                    end
                  end
                end
              end
              render_json_dump plan
              return
            end
            subscriptions = get_subscription_data(params[:id])
            discourse_customers = Customer.left_outer_joins(:user, :invite).all

            subscriptions.each do |sub|
              discourse_customers.each do |customer|
                if sub[:customer][:id] == customer.customer_id && customer.user
                  group.add(customer.user)
                end
              end
            end
          end
          render_json_dump plan
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      private

      def product_params
        { product: params[:product_id] } if params[:product_id]
      end
    end
  end
end
