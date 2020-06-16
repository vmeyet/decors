# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Decors do
  before { stub_class(:TestClass) { extend Decors::DecoratorDefinition } }
  before do
    stub_class(:Spy) do
      def self.passed_args(*args, **kwargs, &block)
        arguments(args: args, kwargs: kwargs, evald_block: block&.call)
      end

      def self.arguments(**); end
    end
  end

  context 'Check decorated_method & undecorated_method' do
    let(:instance) { TestClass.new }

    before do
      stub_class(:SimpleDecorator, inherits: [::Decors::DecoratorBase])
      call_method = call_proc
      SimpleDecorator.send(:define_method, :call) { |*| instance_eval(&call_method) }
      TestClass.class_eval do
        define_decorator :SimpleDecorator, SimpleDecorator
        SimpleDecorator()
        def test
          42
        end
      end
    end

    context 'Check decorated_method value' do
      let(:call_proc) { proc { decorated_method } }
      it { expect(instance.test).to eq TestClass.instance_method(:test) }
    end

    context 'Check undecorated_method value' do
      let(:call_proc) { proc { undecorated_method } }
      it { expect(instance.test.bind(instance).call).to eq 42 }
      it { expect(instance.test.bind(instance).call).not_to eq TestClass.instance_method(:test) }
    end
  end

  context 'when simple case decorator' do
    before do
      stub_class(:SimpleDecorator, inherits: [::Decors::DecoratorBase]) do
        def initialize(deco_class, undeco_method, deco_method, *deco_args, **deco_kwargs, &deco_block)
          super
          Spy.passed_args(*deco_args, **deco_kwargs, &deco_block)
        end

        def call(instance, *args, **kwargs, &block)
          super
          Spy.passed_args(*args, **kwargs, &block)
        end
      end

      TestClass.class_eval { define_decorator :SimpleDecorator, SimpleDecorator }
    end

    context 'It receive all the parameters at initialization' do
      it { expect(SimpleDecorator).to receive(:new).with(TestClass, anything, anything, 1, 2, a: 3).and_call_original }
      it { expect(Spy).to receive(:arguments).with(args: [1, 2], kwargs: { a: 3 }, evald_block: 'ok') }

      after do
        TestClass.class_eval do
          SimpleDecorator(1, 2, a: 3) { 'ok' }
          def test_method(*); end

          def test_method_not_decorated(*); end
        end
      end
    end

    context 'It receive the instance and the arguments passed to the method when called' do
      let(:instance) { TestClass.new }
      before do
        TestClass.class_eval do
          SimpleDecorator()
          def test_method(*args, **kwargs, &block)
            Spy.passed_args(*args, **kwargs, &block)
          end

          def test_method_not_decorated; end
        end
      end

      it { expect_any_instance_of(SimpleDecorator).to receive(:call).with(instance, 1, a: 2, b: 3, &proc { 'yes' }) }
      it { expect(Spy).to receive(:arguments).with(args: [1], kwargs: { a: 2, b: 3 }, evald_block: 'yes').twice }

      after do
        instance.test_method(1, a: 2, b: 3) { 'yes' }
        instance.test_method_not_decorated
      end
    end

    context 'It keep the method visibility' do
      before do
        TestClass.class_eval do
          SimpleDecorator()
          public def public_test_method(*); end

          SimpleDecorator()
          private def private_test_method(*); end

          SimpleDecorator()
          protected def protected_test_method(*); end
        end
      end

      it { expect(TestClass).to be_public_method_defined(:public_test_method) }
      it { expect(TestClass).to be_protected_method_defined(:protected_test_method) }
      it { expect(TestClass).to be_private_method_defined(:private_test_method) }
    end
  end

  context 'when decorator is defining a method during initialization' do
    before do
      stub_class(:StrangeDecorator, inherits: [::Decors::DecoratorBase]) do
        def initialize(decorated_class, undecorated_method, decorated_method, *deco_args, **deco_kwargs, &deco_block)
          super
          decorated_class.send(:define_method, :foo) { 42 }
        end

        def call(*)
          super * 2
        end
      end

      TestClass.class_eval { define_decorator :StrangeDecorator, StrangeDecorator }
    end

    before do
      TestClass.class_eval do
        StrangeDecorator()
        StrangeDecorator()
        def test_method
          5
        end
      end
    end

    it { expect(TestClass.new.test_method).to eq 5 * 2 * 2 }
    it { expect(TestClass.new.foo).to eq 42 }
  end

  context 'when mutiple decorators' do
    before do
      Spy.class_eval do
        @ordered_calls = []

        class << self
          attr_reader :ordered_calls

          def calling(name)
            ordered_calls << name
          end
        end
      end

      stub_class(:Deco1, inherits: [::Decors::DecoratorBase]) do
        def call(*)
          Spy.calling(:deco1_before)
          super
          Spy.calling(:deco1_after)
        end
      end

      stub_class(:Deco2, inherits: [::Decors::DecoratorBase]) do
        def call(*)
          Spy.calling(:deco2_before)
          super
          Spy.calling(:deco2_after)
        end
      end

      TestClass.class_eval do
        define_decorator :Deco1, Deco1
        define_decorator :Deco2, Deco2

        Deco2()
        Deco1()
        def test_method(*)
          Spy.calling(:inside)
        end
      end
    end

    before { TestClass.new.test_method }
    it { expect(Spy.ordered_calls).to eq %i[deco2_before deco1_before inside deco1_after deco2_after] }
  end

  context 'when method has return value' do
    before do
      stub_class(:ModifierDeco, inherits: [::Decors::DecoratorBase])

      TestClass.class_eval do
        define_decorator :ModifierDeco, ModifierDeco

        ModifierDeco()
        def test_method
          :ok
        end
      end
    end

    it { expect(TestClass.new.test_method).to eq :ok }
  end

  context 'when method has arguments' do
    before do
      stub_class(:ModifierDeco, inherits: [::Decors::DecoratorBase])

      TestClass.class_eval do
        define_decorator :ModifierDeco, ModifierDeco

        ModifierDeco()
        def test_method(*args, **kwargs, &block)
          Spy.passed_args(*args, **kwargs, &block)
        end
      end
    end

    it { expect(Spy).to receive(:arguments).with(args: [1, 2, 3], kwargs: { a: :a }, evald_block: 'yay') }
    after { TestClass.new.test_method(1, 2, 3, a: :a) { 'yay' } }
  end

  context 'when changing arguments given to the method' do
    before do
      stub_class(:ModifierDeco, inherits: [::Decors::DecoratorBase]) do
        def call(instance, *)
          undecorated_call(instance, 1, 2, 3, a: :a, &proc { 'yay' })
        end
      end

      TestClass.class_eval do
        define_decorator :ModifierDeco, ModifierDeco

        ModifierDeco()
        def test_method(*args, **kwargs, &block)
          Spy.passed_args(*args, **kwargs, &block)
        end
      end
    end

    it { expect(Spy).to receive(:arguments).with(args: [1, 2, 3], kwargs: { a: :a }, evald_block: 'yay') }
    after { TestClass.new.test_method }
  end

  context 'when method is recursive' do
    before do
      stub_class(:AddOneToArg, inherits: [::Decors::DecoratorBase]) do
        def call(instance, *args)
          undecorated_call(instance, args.first + 1)
        end
      end

      TestClass.class_eval do
        define_decorator :AddOneToArg, AddOneToArg

        AddOneToArg()
        def test_method(n)
          return 0 if n.zero?

          n + test_method(n - 2)
        end
      end
    end

    it { expect(TestClass.new.test_method(4)).to eq 5 + 4 + 3 + 2 + 1 }
  end

  context 'when already has a method_added' do
    before do
      stub_module(:TestMixin) do
        def method_added(*)
          Spy.called
        end
      end
      stub_class(:Deco, inherits: [::Decors::DecoratorBase])
    end
    it { expect(Spy).to receive(:called) }

    after do
      TestClass.class_eval do
        extend TestMixin

        define_decorator :Deco, Deco

        def test_method; end
      end
    end
  end

  context 'when inherited' do
    before do
      stub_class(:Deco, inherits: [::Decors::DecoratorBase])

      TestClass.class_eval do
        define_decorator :Deco, Deco

        Deco()
        def test_method
          :ok
        end
      end
    end

    it {
      stub_class(:TestClass2, inherits: [TestClass])
      TestClass2.class_eval do
        Deco()
        def test_method
          :ko
        end
      end

      expect(TestClass.new.test_method).to eq :ok
      expect(TestClass2.new.test_method).to eq :ko
    }

    it {
      stub_class(:TestClass3, inherits: [TestClass])

      TestClass3.class_eval do
        Deco()
        def test_method
          "this is #{super}"
        end
      end

      expect(TestClass3.new.test_method).to eq 'this is ok'
    }
  end

  context 'when decorating a class method' do
    before do
      stub_class(:Deco, inherits: [::Decors::DecoratorBase]) do
        def call(*)
          super
          Spy.called
        end
      end
    end

    context 'when mixin extended on the class (singleton method in class)' do
      before do
        TestClass.class_eval do
          define_decorator :Deco, Deco

          Deco()
          def self.test_method
            :ok
          end
        end
      end

      it { expect(Spy).to receive(:called) }
      after { TestClass.test_method }
    end

    context 'when mixin extended on the class (singleton method in singleton class)' do
      before do
        TestClass.class_eval do
          class << self
            extend Decors::DecoratorDefinition

            define_decorator :Deco, Deco

            Deco()
            def self.test_method
              :ok
            end
            end
        end
      end

      it { expect(Spy).to receive(:called) }
      after { TestClass.singleton_class.test_method }
    end

    context 'when mixin extended on the class (method in singleton class of singleton class)' do
      before do
        TestClass.class_eval do
          class << self
            class << self
              extend Decors::DecoratorDefinition

              define_decorator :Deco, Deco

              Deco()
              def test_method
                :ok
              end
            end
            end
        end
      end

      it { expect(Spy).to receive(:called) }
      after { TestClass.singleton_class.test_method }
    end

    context 'when mixin extended on the class (method in singleton class)' do
      before do
        TestClass.class_eval do
          class << self
            extend Decors::DecoratorDefinition

            define_decorator :Deco, Deco

            Deco()
            def test_method
              :ok
            end
            end
        end
      end

      it { expect(Spy).to receive(:called) }
      after { TestClass.test_method }
    end

    context 'when mixin extended on the class (both method in singleton class and singleton method in class)' do
      before do
        TestClass.class_eval do
          define_decorator :Deco, Deco

          Deco()
          def self.test_method__in_class
            :ok
          end

          def self.untest_method__in_class; end

          class << self
            extend Decors::DecoratorDefinition

            define_decorator :Deco, Deco

            Deco()
            def test_method__in_singleton
              :ok
            end

            def untest_method__in_singleton; end
          end
        end
      end

      it { expect(Spy).to receive(:called) and TestClass.test_method__in_class }
      it { expect(Spy).to receive(:called) and TestClass.test_method__in_singleton }
      it { expect(Spy).to_not receive(:called) and TestClass.untest_method__in_class }
      it { expect(Spy).to_not receive(:called) and TestClass.untest_method__in_singleton }
    end
  end
end
