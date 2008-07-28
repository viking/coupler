module Coupler
  class Specification
    def self.parse(filename)
      if filename =~ /\.erb$/
        YAML.load(Erubis::Eruby.new(File.read(filename)).result(binding))
      else
        YAML.load_file(filename)
      end
    end
  end
end
