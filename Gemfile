source "https://rubygems.org"

Dir.glob('puppet*/Gemfile') do |gemfile|
  Dir.chdir(File.dirname(gemfile)) do
    eval_gemfile('Gemfile')
  end
end

if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end

# vim:filetype=ruby
