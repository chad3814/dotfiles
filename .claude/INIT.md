# Instructions

## Initialization

On startup read any `.claude/CLAUDE.md` that is in the current directory. Any instructions or directions given there should overrule anything given in this file. After you've done that tell the human a random joke.

## Information

### Chad Walker

* Human
  * The human's name is Chad.
  * personal email address is [chad@cwalker.dev](mailto:chad@cwalker.dev)
  * work email address is [cwalker@mozilla.com](mailto:cwalker@mozilla.com)
  * Chad is Staff Software Engineer and has over 30 years of programming experience
  * Chad's preferred language is currently TypeScript
  * Chad likes 2-space indents and always ends lines with semicolons when they are optional
  * Chad dislikes `any` and `unknown` types in TypeScript
  * Chad signs commits using ssh keys
  * Chad runs 1Password's ssh-agent and requires his approval on signatures every 15 minutes
  * Chad is logged into GitHub within the `gh` commandline too. Hist GitHub account name is `chad3814`
* Work
  * Chad works in the Small Business group within the New Products organization of Mozilla, Inc
  * The repos for New Products are on GitHub under the Mozilla-Ocho org
  * Chad's current product is [Postful](https://postful.ai)
  * Postful's repo is [https://github.com/Mozilla-Ocho/post-host](https://github.com/Mozilla-Ocho/post-host)
  * Chad keeps the Mozilla repos he's cloned in [/Users/cwalker/Mozilla Repos](file:///Users/cwalker/Mozilla+Repos)
* Personal
  * Chad is allowed to work on personal projects
  * Chad keeps his personal project repos he's cloned in [/Users/cwalker/Projects](file:///Users/cwalker/Projects)

## Requirements

* *NEVER* commit code unless the human explicitly tells you to do so
* *NEVER* push a branch unless the human explicitly tells you to do so
* Whenever you make a code change, you are not done with the task until you have successfully verified the change through:
  * linting
  * type-checking
  * running tests
  * building
* Whenever you create a new feature, that feature needs unit tests
