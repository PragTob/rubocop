# frozen_string_literal: true

module RuboCop
  module Cop
    module Rails
      # This cop looks for delegations that could have been created
      # automatically with the `delegate` method.
      #
      # Safe navigation `&.` is ignored because Rails' `allow_nil`
      # option checks not just for nil but also delegates if nil
      # responds to the delegated method.
      #
      # The `EnforceForPrefixed` option (defaulted to `true`) means that
      # using the target object as a prefix of the method name
      # without using the `delegate` method will be a violation.
      # When set to `false`, this case is legal.
      #
      # @example
      #   # bad
      #   def bar
      #     foo.bar
      #   end
      #
      #   # good
      #   delegate :bar, to: :foo
      #
      #   # good
      #   def bar
      #     foo&.bar
      #   end
      #
      #   # good
      #   private
      #   def bar
      #     foo.bar
      #   end
      #
      #   # EnforceForPrefixed: true
      #   # bad
      #   def foo_bar
      #     foo.bar
      #   end
      #
      #   # good
      #   delegate :bar, to: :foo, prefix: true
      #
      #   # EnforceForPrefixed: false
      #   # good
      #   def foo_bar
      #     foo.bar
      #   end
      #
      #   # good
      #   delegate :bar, to: :foo, prefix: true
      class Delegate < Cop
        MSG = 'Use `delegate` to define delegations.'.freeze

        def on_def(node)
          method_name, args, body = *node
          return unless trivial_delegate?(method_name, args, body)
          return if private_or_protected_delegation(node)
          add_offense(node, location: :keyword)
        end

        private

        def autocorrect(node)
          method_name, _args, body = *node
          delegation = ["delegate :#{body.children[1]}",
                        "to: :#{body.children[0].children[1]}"]
          if method_name == prefixed_method_name(body)
            delegation << ['prefix: true']
          end

          lambda do |corrector|
            corrector.replace(node.source_range, delegation.join(', '))
          end
        end

        def trivial_delegate?(method_name, args, body)
          body && delegate?(body) && !body.csend_type? &&
            method_name_matches?(method_name, body) &&
            arguments_match?(args, body)
        end

        def delegate?(body)
          receiver, = *body
          receiver.respond_to?(:type) && receiver.send_type? &&
            receiver.child_nodes.empty?
        end

        def arguments_match?(args, body)
          _receiver, _method_name, *arguments = *body
          arg_array = Array(args)
          argument_array = Array(arguments)
          arg_array.size == argument_array.size && (
            arg_array == argument_array ||
            arg_array.map(&:children) == argument_array.map(&:children)
          )
        end

        def method_name_matches?(method_name, body)
          _receiver, property_name, *_args = *body
          method_name == property_name ||
            (include_prefix_case? &&
              method_name == prefixed_method_name(body))
        end

        def include_prefix_case?
          cop_config['EnforceForPrefixed']
        end

        def prefixed_method_name(body)
          receiver, property_name, *_args = *body
          _receiver, target, *_args = *receiver
          [target, property_name].join('_').to_sym
        end

        def private_or_protected_delegation(node)
          line = node.loc.line
          private_or_protected_before(line) ||
            private_or_protected_inline(line)
        end

        def private_or_protected_before(line)
          (processed_source[0..line].map(&:strip) & %w[private protected]).any?
        end

        def private_or_protected_inline(line)
          processed_source[line - 1].strip =~ /\A(private )|(protected )/
        end
      end
    end
  end
end
