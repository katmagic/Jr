Gem::Specification.new do |s|
	s.name				= 'jr'
	s.version			= '0.1'
	s.author			= 'katmagic'
	s.email				= 'the.magical.kat@gmail.com'
	s.homepage		= 'https://github.com/katmagic/jr'
	s.summary			= 'Jr. is a JSON RPC client implementation.'
	s.description = 'Jr. lets you communicate with an HTTP JSON RPC server.'

	s.files = ['README', 'lib/jr.rb']

	if ENV['GEM_SIG_KEY']
		s.signing_key = ENV['GEM_SIG_KEY']
		s.cert_chain = ENV['GEM_CERT_CHAIN'].split(",") if ENV['GEM_CERT_CHAIN']
	else
		warn "environment variable $GEM_SIG_KEY unspecified; not signing gem"
	end
end
