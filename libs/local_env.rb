class LocalEnv
  def initialize(section, keys)
    @section = section
    @keys = keys
  end

  def get(key)
    if @keys.key?(key)
      self.send("get_#{@keys[key].fetch(:type, :string)}", key)
    end
  end

  private

  def get_string(key)
    ENV.fetch("#{@section}_#{key.upcase}", @keys[key].fetch(:default, nil))
  end
  
  def get_int(key)
    rv = ENV.fetch("#{@section}_#{key.upcase}", nil)
    rv ? rv.to_i : @keys[key].fetch(:default, nil)
  end
  
  def get_list(key)
    rv = ENV.fetch("#{@section}_#{key.upcase}", nil)
    rv ? rv.split(/\,\b*/) : @keys[key].fetch(:default, nil)
  end
end
