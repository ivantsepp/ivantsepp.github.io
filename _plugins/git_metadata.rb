# Exposes git stats as `site.git`, replacing the jekyll-git_metadata gem
# (https://github.com/ivantsepp/jekyll-git_metadata) which is pinned to Jekyll 3.
#
# Provides:
#   site.git.total_commits
#   site.git.total_additions
#   site.git.total_subtractions
#   site.git.last_commit.commit_date
#   site.git.last_commit.message
module Jekyll
  class GitMetadataGenerator < Generator
    safe true
    priority :high

    def generate(site)
      Dir.chdir(site.source) do
        additions = 0
        subtractions = 0
        `git log --numstat --pretty=format: 2>/dev/null`.each_line do |line|
          added, removed, = line.split("\t")
          additions += added.to_i if added =~ /\A\d+\z/
          subtractions += removed.to_i if removed =~ /\A\d+\z/
        end

        date, message = `git log -1 --pretty=format:%cI%n%s 2>/dev/null`.split("\n", 2)

        site.config['git'] = {
          'total_commits' => `git rev-list --count HEAD 2>/dev/null`.to_i,
          'total_additions' => additions,
          'total_subtractions' => subtractions,
          'last_commit' => {
            'commit_date' => date ? Time.parse(date) : nil,
            'message' => message.to_s.strip
          }
        }
      end
    end
  end
end
