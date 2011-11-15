module Insight
  module Instrumentation
    class Probe
      module Interpose
      end

      @@class_list = nil

      module ProbeRunner
        include Backstage

        def probe_run(object, context = "::", kind=:instance, args=[], called_at=caller[1])
          return yield if Thread.current['instrumented_backstage']
          instrument = Thread.current['insight.instrument']
          result = nil
          if instrument.nil?
            backstage do
              # Rails.logger.debug{"No instrument in thread - #{context} /
              # #{called_at}"}
              result = yield
            end
          else
            instrument.run(object, context, kind, called_at, args){ result = yield }
          end
          result
        end
        extend self
      end

      class << self
        include Logging

        def class_list
          @@class_list ||= begin
                             classes = []
                             ObjectSpace.each_object(Class) do |klass|
                               classes << klass
                             end
                             classes
                           end
        end

        def get_probe_chain(name)
          const = const_from_name(name)
          chain = []
          const.ancestors.each do |mod|
            if probes.has_key?(mod.name)
              chain << probes[mod.name]
            end
          end
          chain
        end

        def const_from_name(name)
          parts = name.split("::")
          const = parts.inject(Kernel) do |namespace, part|
            namespace.const_get(part)
          end
        end

        def probes
          @probes ||= Hash.new do |h,k|
            begin
              h[k] = self.new(const_from_name(k))
            rescue NameError
              logger.info{ "Cannot find constant: #{k}" }
            end
          end
        end

        def all_probes
          probes.values
        end

        def probe_for(const)
          probes[const]
        end
      end

      def initialize(const)
        @const = const
        @probed = {}
        @collectors = Hash.new{|h,k| h[k] = []}
        @probe_orders = []
      end

      def collectors(key)
        @collectors[key.to_sym]
      end

      def all_collectors
        @collectors.values
      end

      def clear_collectors
        @collectors.clear
      end

      def probe(collector, *methods)
        methods.each do |name|
          unless @collectors[name.to_sym].include?(collector)
            @collectors[name.to_sym] << collector
          end
          @probe_orders << name
        end
      end

      def descendants
        @descendants ||= self.class.class_list.find_all do |klass|
          klass.ancestors.include?(@const)
        end
      end

      def local_method_defs(klass)
        klass.instance_methods(false)
      end

      def descendants_that_define(method_name)
        log{{ :descendants => descendants }}
        descendants.find_all do |klass|
          (@const == klass or local_method_defs(klass).include?(method_name))
        end
      end

      def log &block
        #$stderr.puts block.call.inspect
      end

      def fulfill_probe_orders
        log{{:probes_for => @const.name}}
        @probe_orders.each do |method_name|
          log{{ :method => method_name }}
          descendants_that_define(method_name).each do |klass|
            log{{ :subclass => klass.name }}
            build_tracing_wrappers(klass, method_name)
          end
        end
        @probe_orders.clear
      end

      def interposition_module_name
        @interposition_module_name ||= (@const.name.gsub(/::/, "") + "Instance").to_sym
      end

      def interpose_module
        return Interpose::const_get(interposition_module_name)
      rescue NameError
        mod = Module.new
        Interpose::const_set(interposition_module_name, mod)
        retry
      end

      def build_tracing_wrappers(target, method_name)
        return if @probed.has_key?([target,method_name])
        @probed[[target,method_name]] = true

        mod = interpose_module
        unless target.include?(mod)
          target.class_eval do
            include mod
          end
        end

        if target.instance_methods(false).include?(method_name.to_s)
          meth = target.instance_method(method_name)

          interpose_module.module_eval do
            define_method(method_name, meth)
          end

          target.class_exec() do
            define_method(method_name) do |*args, &block|
              ProbeRunner::probe_run(self, self.class.name, :instance, args, caller(0)[0]) do
                super(*args, &block)
              end
            end
          end
        end
      end
    end

    class ClassProbe < Probe
      def local_method_defs(klass)
        klass.singleton_methods(false)
      end

      def build_tracing_wrappers(target, method_name)
        return if @probed.has_key?([target, method_name])
        @probed[[target, method_name]] = true

        method = target.method(method_name)

        (class << target; self; end).class_exec(method) do |method|
          define_method(method_name) do |*args, &block|
            ProbeRunner::probe_run(self, self.name, :class, args, caller(0)[0]) do
              method.call(*args, &block)
            end
          end
        end
      end
    end

    class InstanceProbe < Probe
    end
  end
end