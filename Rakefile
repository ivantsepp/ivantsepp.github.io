require 'rubygems'
require 'rake'
require 'jekyll'
require 'tmpdir'
require 'shellwords'
require 'html/proofer'

# http://blog.nitrous.io/2013/08/30/using-jekyll-plugins-on-github-pages.html

desc "Generate blog files"
task :generate do
  Jekyll::Site.new(Jekyll.configuration({
    "source"      => ".",
    "destination" => "_site"
  })).process
end

desc "Generate and publish blog to gh-pages"
task :publish => [:generate, :proof] do
  Dir.mktmpdir do |tmp|
    system "mv _site/* #{tmp}"
    unless %x{git status --short}.empty?
      stashed = true
      system "git stash"
    end
    system "git checkout master"
    break unless $?.success?
    system "rm -rf *"
    system "mv #{tmp}/* ."
    message = "Site updated at #{Time.now.utc}"
    system "git add ."
    system "git commit -am #{message.shellescape}"
    system "git push ivantsepp master --force"
    system "git checkout source"
    if stashed
      system "git stash pop"
    end
  end
end

desc "HTML Proof the output"
task :proof => [:generate] do
  HTML::Proofer.new("./_site").run
end

task :default => :publish
