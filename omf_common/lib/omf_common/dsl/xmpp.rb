require 'blather/client/dsl'

module OmfCommon
  module DSL
    module Xmpp
      include Blather::DSL

      HOST_PREFIX = 'pubsub'

      PUBSUB_CONFIGURE = Blather::Stanza::X.new({
        :type => :submit,
        :fields => [
          { :var => "FORM_TYPE", :type => 'hidden', :value => "http://jabber.org/protocol/pubsub#node_config" },
          { :var => "pubsub#persist_items", :value => "0" },
          { :var => "pubsub#max_items", :value => "0" },
          { :var => "pubsub#notify_retract",  :value => "0" },
          { :var => "pubsub#publish_model", :value => "open" }]
      })

      # Set up XMPP options and start the Eventmachine, connect to XMPP server
      #
      def connect(username, password, server)
        jid = "#{username}@#{server}"
        client.setup(jid, password)
        client.run
      end

      # Shut down XMPP connection
      def disconnect
        shutdown
      end

      # Create a new pubsub node with additional configuration
      #
      # @param [String] node Pubsub node name
      # @param [String] host Pubsub host address
      def create_node(node, host, &block)
        pubsub.create(node, prefix_host(host), PUBSUB_CONFIGURE, &callback_logging(__method__, node, &block))
      end

      # Delete a pubsub node
      #
      # @param [String] node Pubsub node name
      # @param [String] host Pubsub host address
      def delete_node(node, host, &block)
        pubsub.delete(node, prefix_host(host), &callback_logging(__method__, node, &block))
      end

      # Subscribe to a pubsub node
      #
      # @param [String] node Pubsub node name
      # @param [String] host Pubsub host address
      def subscribe(node, host, &block)
        logger.warn host
        logger.warn jid.domain
        pubsub.subscribe(node, nil, prefix_host(host), &callback_logging(__method__, node, &block))
      end

      # Un-subscribe all existing subscriptions from all pubsub nodes.
      #
      # @param [String] host Pubsub host address
      def unsubscribe(host)
        pubsub.subscriptions(prefix_host(host)) do |m|
          m[:subscribed] && m[:subscribed].each do |s|
            pubsub.unsubscribe(s[:node], nil, s[:subid], prefix_host(host), &callback_logging(__method__, s[:node], s[:subid]))
          end
        end
      end

      def affiliations(host, &block)
        pubsub.affiliations(prefix_host(host), &callback_logging(__method__, &block))
      end

      # Publish to a pubsub node
      #
      # @param [String] node Pubsub node name
      # @param [String] message Any XML fragment to be sent as payload
      # @param [String] host Pubsub host address
      def publish(node, message, host, &block)
        pubsub.publish(node, message, prefix_host(host), &callback_logging(__method__, node, message.operation, &block))
      end

      # Event callback for pubsub node event(item published)
      #
      def node_event(*args, &block)
        pubsub_event(:items?, *args, &callback_logging(__method__, &block))
      end

      private

      # Provide a new block wrap to automatically log errors
      def callback_logging(*args, &block)
        m = args.empty? ? "OPERATION" : args.map {|v| v.to_s.upcase }.join(" ")
        proc do |callback|
          logger.error callback if callback.respond_to?(:error?) && callback.error?
          logger.debug "#{m} SUCCEED" if callback.respond_to?(:result?) && callback.result?
          block.call(callback) if block
        end
      end

      def prefix_host(host)
        "#{HOST_PREFIX}.#{host}"
      end
    end
  end
end
