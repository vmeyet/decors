# frozen_string_literal: true

module Decors
  class DecoratorBase
    attr_reader :decorated_class, :undecorated_method, :decorated_method, :decorator_args,
                :decorator_kwargs, :decorator_block

    def initialize(decorated_class, undecorated_method, decorated_method, *args, **kwargs, &block)
      @decorated_class = decorated_class
      @undecorated_method = undecorated_method
      @decorated_method = decorated_method
      @decorator_args = args
      @decorator_kwargs = kwargs
      @decorator_block = block
    end

    def call(instance, *args, **kwargs, &block)
      undecorated_call(instance, *args, **kwargs, &block)
    end

    def undecorated_call(instance, *args, **kwargs, &block)
      undecorated_method.bind(instance).call(*args, **kwargs, &block)
    end

    def decorated_method_name
      decorated_method.name
    end
  end
end
