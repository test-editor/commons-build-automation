#!/bin/bash
#
# DESCRIPTION AND CONTEXT:
#
# This script is used in the context of automatic publishing of npm artifacts
# through tagging of git versions on the master branch during the build on travis.
#
# This script is used to tag the (containing) repo with a new patch version
# and push this change back to its github location.
#
# Given the appropriate web hook, this will automatically trigger a build
# on travis, which in turn will publish this artifact, since this is a tagged
# version.
#
# Tagging may take place only if:
# * this is no travis pull request (TRAVIS_PULL_REQUEST = false)
# * this is a build on the master branch (TRAVIS_BRANCH = master)
# * this branch is untagged (TRAVIS_TAG = "")
#
# Tagging should take place only once if you are using a build matrix.
#
# To ensure that tagging is not done on an already tagged build, the author of
# the git push is checked. For the git push a technical user is used (srvte). If
# the latest author of a push is this technical user, no tagging is done (since
# this would enter an endless loop of tag -> publish cycles).
#
# USAGE:
#
#   The condition 'FIREFOX_VERSION = latest' ensures that only one execution per build
#   in the context of matrix builds takes place!
#
#   Make sure to have an entry within your .gitignore for this shell script!
#
#   given there is a deploy section within the '.travis.yml':
#     deploy:
#       skip_cleanup: true
#       provider: npm
#       email: service.eng@akquinet.de
#       api_key:
#         secure: "..."
#       on:
#         condition: "$FIREFOX_VERSION = latest"
#         tags: true
#         repo: test-editor/...
#
#  you can include the call to the tagging in the 'after_success:' section of your yml file:
#    after_success:
#    - 'if [ "$FIREFOX_VERSION" = "latest" -a "$TRAVIS_PULL_REQUEST" = "false" -a "$TRAVIS_BRANCH" = "master" -a "$TRAVIS_TAG" = "" ]; then wget https://github.com/test-editor/commons-build-automation/raw/master/travis/deploy/tag_with_new_patch_version.sh; bash tag_with_new_patch_version.sh; fi'
#
#
tag_author="srvte tagging"
last_author=`git show --format="%aN" HEAD | head -n 1`
echo "Last author was: $last_author"
if [ "$last_author" == "$tag_author" ]; then
  echo "Author of last commit seems to be the one that is reserved for pushing tags."
  echo "No new version is tagged!"
else
  package_name=`cat package.json | grep name | awk '{ print $2 }' | sed -e 's/"\(.*\)",/\1/g'`
  if [[ $package_name = \@testeditor/* ]]; then
    echo "package name used = $package_name"
    echo "tag with new patch level version, since publishing is wanted"
    old_version=`npm view $package_name version`
    echo "old version (before tagging) was v$old_version"
    if [ "$GH_EMAIL" == "" -o "$GH_TOKEN" == "" ]; then
      echo "tagging is not done since email and token for push into github is missing!"
    else
      # configure for git push to work automatically
      github_project=`git config --get remote.origin.url | sed 's|.*\(/[^/]*/[^/]*\)$|\1|g'`
      git config user.name "$tag_author"
      git config user.email "$GH_EMAIL"
      git remote remove origin || true
      git remote add origin https://$GH_TOKEN@github.com$github_project
      git remote -v # show the now configured remotes
      git checkout - # if detached, try to return to a regular branch
      git fetch # necessary to make origin/master known
      git branch --set-upstream-to=origin/master
      git remote -v # show the now configured remotes
      git status # show some info
      git tag # show tag info
      npm version patch # create git commit and tag automatically!
      # postversion action in package.json will execute git push && git push --tags
      new_version=`npm view $package_name version`
      echo "tagged now with v$new_version"
    fi
  else
    echo "package name '$package_name' does not start with @testeditor/ which seems to be wrong!"
  fi
fi
