---
layout: post
title:  "GitHub References"
date:   2014-08-17 18:53:14
categories: git github
comments: true
---

There are two special types of references that are available in your GitHub hosted repository. GitHub creates these references for each pull request; they are `pull/:id/head` and `pull/:id/merge`. Let's review them and how they can be useful.

## Pull Request Head
This reference points to the latest commit of the pull request. GitHub automatically stashes all the changes for a pull request against the main repository. Why does GitHub do this and why is it useful? Well, one would expect that when the requester deletes his/her fork, the changes are also lost. However, this is not true. You are still able to merge a pull request because those changes are "saved" in the pull request head reference.

One could also checkout the pull request locally without ever having to add a remote. You could also [modify it locally](https://help.github.com/articles/checking-out-pull-requests-locally#modifying-an-inactive-pull-request-locally) if the pull request has become stale and now conflicts with master.

One way I've found this knowledge to be very useful is that it allows you to do a compare across pull requests on GitHub. Often, you may find yourself working on a pull request that includes another pull request. That is, your pull request depends on the work done in another pull request. When a code reviewer looks at the diff on GitHub, it includes changes from **both** pull requests but really, the code reviewer only wants to focus on the changes you made specifically for your pull request. To get that view, just make a compare between those pull requests references. I made a quick demostration of this: [the second pull request](https://github.com/ivantsepp/ivantsepp.github.io/pull/8) works on top of [the first pull request](https://github.com/ivantsepp/ivantsepp.github.io/pull/7) but the [compare link](https://github.com/ivantsepp/ivantsepp.github.io/compare/pull%2F7%2Fhead...pull%2F8%2Fhead?w=1) only shows the commits made in the second pull request.

As a side note, just as you can hide whitespace diff with `git diff -w` or `git diff --ignore-all-space` on the command line, you can add `?w=1` to the URL to get the same effect with the GitHub view. There are some other [useful GitHub secrets](https://github.com/blog/967-github-secrets) you should check out.

Another way I used this GitHub supported functionality is extending the concept of checking out a pull request locally. @princesspretzel, who came up with this idea, wanted to be able to open all the files corresponding to a pull request. I see two use cases for this functionality:
- You are switching between branches and want to open all the files you've changed to resume work.
- You are code reviewing a massive branch and want to open the files to view changes instead of constantly scrolling the long diff.

To acheive this, we can consult the [GitHub Pull Request API](https://developer.github.com/v3/pulls/#list-pull-requests-files) to get a list of modified files for a pull request. Then we can checkout the pull request locally using `pull/:id/head`. This step is important since this is how the developer is able to see the changes in the editor (the pull request might've added new files). We are currently working on a [sublime plugin](https://github.com/princesspretzel/spoke) that does just that and I've created this command in [GithubTools](https://github.com/ivantsepp/github_tools), my collection of command line tools for GitHub.

## Pull Request Merge
The pull request merge reference points to the merge commit between the pull request and the base branch. I believe that GitHub creates this commit to test the mergeability of the pull request. How can this reference be useful for you? Well, TravisCI uses it to get a copy of the repository as if the pull request has been merged. Then, it will run the tests against this working copy. If you look at [this example](https://travis-ci.org/jekyll/jekyll/jobs/32736147), you can see the job runs `git fetch origin +refs/pull/2762/merge:` followed by a `git checkout -qf FETCH_HEAD` command.

Another hypothetically use case for reference is checking mergeability without hitting the API. You can determine [mergeability](https://developer.github.com/v3/pulls/#mergability) by hitting the API but we can do this programmatically without the API. One could fetch both the pull request head and the pull request merge references and determine if the latest sha in the pull request is in the history of the merge commit. The pull request is mergeable if so and not mergeable otherwise. I am planning on testing this out and implementing it in [GithubTools](https://github.com/ivantsepp/github_tools).

---
Let me know if you know of any other cool ways of using GitHub's special references for creating a better workflow. Here are some external links that you definitely should check out:
- [Zach Holman's talk "More Git and GitHub Secrets"](http://zachholman.com/talk/more-git-and-github-secrets/) - This is where I learned about these references. The talk also has some of nice nuggets of information.
- [Git Howto: Mirror a GitHub Repo Without Pull Refs](http://christoph.ruegg.name/blog/git-howto-mirror-a-github-repository-without-pull-refs.html) - I came across this blog post while writing this. The post shows you how to mirror a GitHub repository without copying these references
- [GitHub: add remote for pulls and merges](https://coderwall.com/p/3dgwcg) - Add a remote refspec for grabbing these pull request head and merge references

