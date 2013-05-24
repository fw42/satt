Gem::Specification.new do |s|
  s.name           = 'satt'
  s.version        = '0.0.1'
  s.date           = '2013-05-24'
  s.summary        = "Serialize All The Things"
  s.description    = "Serializing arbitrary Ruby objects with MessagePack"
  s.authors        = ["Florian Weingarten"]
  s.email          = 'flo@hackvalue.de'
  s.files          = ["lib/satt.rb"]
  s.homepage       = 'http://rubygems.org/gems/satt'

  s.add_dependency "msgpack"
end
