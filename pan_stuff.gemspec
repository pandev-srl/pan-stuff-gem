require_relative "lib/pan_stuff/version"

Gem::Specification.new do |spec|
  spec.name        = "pan_stuff"
  spec.version     = PanStuff::VERSION
  spec.authors     = ['Umberto Peserico', 'Alessio Bussolari']
  spec.email       = %w[umberto.peserico@pandev.it alessio.bussolari@pandev.it]
  spec.homepage    = "https://bitbucket.org/pandev-srl/pan-stuff"
  spec.summary     = "Summary of PanStuff."
  spec.description = "Description of PanStuff."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = '>= 3.2.0', '< 3.4'
  
  spec.add_dependency 'money', '~> 6.19'
  spec.add_dependency "rails", ">= 7.0.0", "< 8"
end
