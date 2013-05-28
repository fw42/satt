Gem::Specification.new do |s|
  s.name           = 'satt'
  s.version        = '0.0.1'
  s.date           = Time.now.strftime("%Y-%m-%d"),
  s.summary        = "Serialize All The Things"
  s.description    = "Serializing arbitrary Ruby objects with MessagePack"
  s.authors        = ["Florian Weingarten"]
  s.email          = 'flo@hackvalue.de'
  s.files          = ["lib/satt.rb"]
  s.homepage       = 'https://github.com/fw42/satt/'

  s.add_dependency "msgpack"
end
