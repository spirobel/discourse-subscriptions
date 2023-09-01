# frozen_string_literal: true

module DiscourseSubscriptions
  class HooksController < ::ApplicationController
    include DiscourseSubscriptions::Group
    include DiscourseSubscriptions::Stripe

    layout false

    skip_before_action :check_xhr
    skip_before_action :redirect_to_login_if_required
    skip_before_action :verify_authenticity_token, only: [:create]

    def create
      begin
        payload = request.body.read
        sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
        webhook_secret = SiteSetting.discourse_subscriptions_webhook_secret

        event = ::Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
      rescue JSON::ParserError => e
        return render_json_error e.message
      rescue ::Stripe::SignatureVerificationError => e
        return render_json_error e.message
      end

      case event[:type]
      when "checkout.session.completed"
        checkout_session = event[:data][:object]
        email = checkout_session[:customer_details][:email]
        customer_id = checkout_session[:id]
        customer_id = checkout_session[:customer] unless checkout_session[:customer].nil?

        user = ::User.find_by_username_or_email(email)
        if user.nil?
          invite = ::Invite.generate(Discourse.system_user, email: email)
          discourse_customer =
            Customer.create(user_id: nil, invite_id: invite.id, customer_id: customer_id)
          return head 200
        end

        discourse_customer = Customer.find_by(user_id: user.id)
        if discourse_customer.nil?
          discourse_customer =
            Customer.create(user_id: user.id, invite_id: nil, customer_id: customer_id)
        else
          discourse_customer =
            Customer.update(
              user_id: user.id,
              invite_id: nil,
              customer_id: checkout_session[:customer],
            )
        end

        line_items =
          ::Stripe::Checkout::Session.list_line_items(checkout_session[:id], { limit: 100 })
        line_items.each do |item|
          group = plan_group(item[:price]) unless item[:price].nil?
          group.add(user) unless group.nil?
        end
      when "customer.subscription.created"
      when "customer.subscription.updated"
        subscription = event[:data][:object]

        return head 200 if subscription[:status] != "complete"

        group = plan_group(subscription[:plan]) unless subscription[:plan].nil?
        return head 200 if group.nil?

        discourse_customer = Customer.find_by(customer_id: subscription[:customer])
        if discourse_customer.nil?
          discourse_customer = Customer.create(customer_id: subscription[:customer])
        end

        discourse_subscription = Subscription.find_by(external_id: subscription[:id])
        if discourse_subscription.nil?
          discourse_subscription =
            Subscription.create(
              customer_id: discourse_customer[:id],
              external_id: subscription[:id],
            )
        end

        user = discourse_customer.user if discourse_customer.user
        if user.nil?
          stripe_customer = ::Stripe::Customer.retrieve(customer.customer_id)
          user = ::User.find_by_username_or_email(stripe_customer.email)
          discourse_customer.update(user_id: user.id, invite_id: nil)
        end

        if user.nil?
          invite = ::Invite.generate(Discourse.system_user, email: stripe_customer.email)
          discourse_customer.update(user_id: nil, invite_id: invite.id)
        else
          group.add(user)
        end
      when "customer.subscription.deleted"
        subscription = event[:data][:object]
        discourse_customer = Customer.find_by(customer_id: subscription[:customer])
        return head 200 if discourse_customer.nil?

        discourse_subscription = Subscription.find_by(external_id: subscription[:id])
        discourse_subscription.update(ended: true) if discourse_subscription
        if group = plan_group(subscription[:plan])
          group.remove(discourse_customer.user) if discourse_customer.user
        end
      end

      head 200
    end
  end
end
