require_relative 'duplicable'

class Hash
  # add keys to hash
  def to_obj
    self.each do |k,v|
      if v.kind_of? Hash
        v.to_obj
      end
      k=k.to_s.gsub(/\.|\s|-|\/|\'/, '_').downcase.to_sym

      ## create and initialize an instance variable for this key/value pair
      self.instance_variable_set("@#{k}", v)

      ## create the getter that returns the instance variable
      self.class.send(:define_method, k, proc{self.instance_variable_get("@#{k}")})

      ## create the setter that sets the instance variable
      self.class.send(:define_method, "#{k}=", proc{|v| self.instance_variable_set("@#{k}", v)})
    end

    return self
  end

  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end

    # Slice a hash to include only the given keys. Returns a hash containing 
  # the given keys.
  # 
  #   { a: 1, b: 2, c: 3, d: 4 }.slice(:a, :b)
  #   # => {:a=>1, :b=>2}
  # 
  # This is useful for limiting an options hash to valid keys before 
  # passing to a method:
  #
  #   def search(criteria = {})
  #     criteria.assert_valid_keys(:mass, :velocity, :time)
  #   end
  #
  #   search(options.slice(:mass, :velocity, :time))
  #
  # If you have an array of keys you want to limit to, you should splat them:
  #
  #   valid_keys = [:mass, :velocity, :time]
  #   search(options.slice(*valid_keys))
  def slice(*keys)
    keys.map! { |key| convert_key(key) } if respond_to?(:convert_key, true)
    keys.each_with_object(self.class.new) { |k, hash| hash[k] = self[k] if has_key?(k) }
  end

  # Replaces the hash with only the given keys.
  # Returns a hash containing the removed key/value pairs.
  #
  #   { a: 1, b: 2, c: 3, d: 4 }.slice!(:a, :b)
  #   # => {:c=>3, :d=>4}
  def slice!(*keys)
    keys.map! { |key| convert_key(key) } if respond_to?(:convert_key, true)
    omit = slice(*self.keys - keys)
    hash = slice(*keys)
    hash.default      = default
    hash.default_proc = default_proc if default_proc
    replace(hash)
    omit
  end

  # Removes and returns the key/value pairs matching the given keys.
  #
  #   { a: 1, b: 2, c: 3, d: 4 }.extract!(:a, :b) # => {:a=>1, :b=>2}
  #   { a: 1, b: 2 }.extract!(:a, :x)             # => {:a=>1}
  def extract!(*keys)
    keys.each_with_object(self.class.new) { |key, result| result[key] = delete(key) if has_key?(key) }
  end

  def indifferent
    Wedge::IndifferentHash.new self
  end
end

class HashObject
  def initialize(hash = {})
    hash.each do |k,v|
      if v.kind_of? Hash
        self.instance_variable_set("@#{k}", HashObject.new(v))
      end

      self.instance_variable_set("@#{k}", v)
      self.class.send(:define_method, k, proc{self.instance_variable_get("@#{k}")})
      self.class.send(:define_method, "#{k}=", proc{|vv| self.instance_variable_set("@#{k}", vv)})
    end
  end

  def to_h
    hash_to_return = Wedge::IndifferentHash.new
    self.instance_variables.each do |var|
      value = self.instance_variable_get(var)
      hash_to_return[var.to_s.gsub("@","")] = value.is_a?(HashObject) ? value.to_h : value
    end
    return hash_to_return
  end

  def dup
    Wedge::IndifferentHash.new self.to_h.inject({}) {|copy, (key, value)| copy[key] = value.dup rescue value; copy}
  end
end

class Object
  # Returns a deep copy of object if it's duplicable. If it's
  # not duplicable, returns +self+.
  #
  #   object = Object.new
  #   dup    = object.deep_dup
  #   dup.instance_variable_set(:@a, 1)
  #
  #   object.instance_variable_defined?(:@a) # => false
  #   dup.instance_variable_defined?(:@a)    # => true
  def deep_dup
    duplicable? ? dup : self
  end
end

class Array
  # Returns a deep copy of array.
  #
  #   array = [1, [2, 3]]
  #   dup   = array.deep_dup
  #   dup[1][2] = 4
  #
  #   array[1][2] # => nil
  #   dup[1][2]   # => 4
  def deep_dup
    map(&:deep_dup)
  end
end

class Hash
  # Returns a deep copy of hash.
  #
  #   hash = { a: { b: 'b' } }
  #   dup  = hash.deep_dup
  #   dup[:a][:c] = 'c'
  #
  #   hash[:a][:c] # => nil
  #   dup[:a][:c]  # => "c"
  def deep_dup
    each_with_object(dup) do |(key, value), hash|
      hash.delete(key)
      hash[key.deep_dup] = value.deep_dup
    end
  end
end
