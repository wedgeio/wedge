class Wedge
  module Store
    include Methods

    def self.store
      if server?
        Thread.current[:__wedge__] ||= {}
      else
        $__wedge_store__ ||= {}
      end
    end

    def self.clear!
      if server?
        Thread.current[:__wedge__] = {}
      else
        $__wedge_store__ = {}
      end
    end

    def self.read(key)
      store[key]
    end

    def self.[](key)
      store[key]
    end

    def self.write(key, value)
      store[key] = value
    end

    def self.[]=(key, value)
      store[key] = value
    end

    def self.exist?(key)
      store.key?(key)
    end

    def self.fetch(key, &block)
      store[key] = yield unless exist?(key)
      store[key]
    end

    def self.delete(key, &block)
      store.delete(key, &block)
    end
  end
end
