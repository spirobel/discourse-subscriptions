# frozen_string_literal: true

module DiscourseSubscriptions
  module Admin
    class SubscriptionsController < ::Admin::AdminController
      include DiscourseSubscriptions::Stripe
      include DiscourseSubscriptions::Group
      before_action :set_api_key

      PAGE_LIMIT = 10

      def index
        begin
          if is_stripe_configured?
            discourse_customers = Customer.left_outer_joins(:user, :invite).all

            subscriptions = get_subscription_data

            subscriptions.each do |sub|
              discourse_customer =
                discourse_customers.filter { |c| c.customer_id == sub[:customer][:id] }.first

              link_text(sub, discourse_customer)
            end
          elsif !is_stripe_configured?
            subscriptions = nil
          end
          result = {
            has_more: false,
            data: subscriptions,
            length: 0,
            last_record: params[:last_record],
          }
          render_json_dump result
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def update
        user = ::User.find_by_username_or_email(params[:user])
        if user.nil?
          invite =
            ::Invite.generate(
              current_user,
              email: params[:user],
              skip_email: params[:skip_email],
              custom_message: params[:custom_message],
            )
        end

        subscription = ::Stripe::Subscription.retrieve(params[:id])

        discourse_customer = Customer.find_by(customer_id: subscription[:customer])
        if discourse_customer.nil?
          discourse_customer = Customer.create(customer_id: subscription[:customer])
        end

        discourse_subscription = Subscription.find_by(external_id: params[:id])
        if discourse_subscription.nil?
          discourse_subscription =
            Subscription.create(
              customer_id: discourse_customer[:id],
              external_id: subscription[:id],
            )
        end

        group =
          ::Group.find_by_name(subscription[:plan][:metadata][:group_name]) unless subscription[
          :plan
        ].nil?
        group.remove(discourse_customer.user) unless group.nil?

        if invite.nil?
          discourse_customer.update(user_id: user.id, invite_id: nil)
          group.add(user) unless group.nil?
        else
          discourse_customer.update(user_id: nil, invite_id: invite.id)
        end
        subscription = {}
        link_text(subscription, discourse_customer)

        render_json_dump subscription
      end

      def destroy
        params.require(:id)
        begin
          refund_subscription(params[:id]) if params[:refund]
          subscription = ::Stripe::Subscription.delete(params[:id])

          customer =
            Customer.find_by(
              product_id: subscription[:plan][:product],
              customer_id: subscription[:customer],
            )

          Subscription.delete_by(external_id: params[:id])

          if customer
            user = ::User.find(customer.user_id)
            customer.delete
            group = plan_group(subscription[:plan])
            group.remove(user) if group
          end

          render_json_dump subscription
        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      private

      def link_text(subscription, discourse_customer)
        return if discourse_customer.nil?
        # if there is a user link to it with the username
        if discourse_customer.user
          subscription[:subscriptionUserPath] = "/admin/users/" + discourse_customer.user.id.to_s +
            "/" + discourse_customer.user.username
          subscription[:subscriptionLinkText] = discourse_customer.user.username
        end

        if discourse_customer.invite
          subscription[:subscriptionUserPath] = "/u/" +
            discourse_customer.invite.invited_by.username + "/invited/pending"
          subscription[:subscriptionLinkText] = discourse_customer.invite.email
        end
      end

      def get_subscriptions(start)
        ::Stripe::Subscription.list(
          expand: ["data.plan.product"],
          limit: PAGE_LIMIT,
          starting_after: start,
        )
      end

      def find_valid_subscriptions(data, ids)
        valid = data.select { |sub| ids.include?(sub[:id]) }
        valid.empty? ? nil : valid
      end

      # this will only refund the most recent subscription payment
      def refund_subscription(subscription_id)
        subscription = ::Stripe::Subscription.retrieve(subscription_id)
        invoice = ::Stripe::Invoice.retrieve(subscription[:latest_invoice]) if subscription[
          :latest_invoice
        ]
        payment_intent = invoice[:payment_intent] if invoice[:payment_intent]
        refund = ::Stripe::Refund.create({ payment_intent: payment_intent })
      end
    end
  end
end
