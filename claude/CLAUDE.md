# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

# address-comments
- **address-comments** (`~/.claude/skills/address-comments/SKILL.md`) - fix PR review comments, add test coverage, draft short plain replies. Trigger: `/address-comments` or asking to fix/address review comments.
When the user types `/address-comments`, invoke the Skill tool with `skill: "address-comments"` before doing anything else.

# leetcode-testdata
- **leetcode-testdata** (`~/.claude/skills/leetcode-testdata/SKILL.md`) - add runnable test data to a LeetCode solution file: detect the Solution signature, generate diverse cases (5-10 if unspecified), wire a PASS/FAIL harness into main(), compile and verify. Trigger: `/leetcode-testdata` or asking to add test data/tests to a LeetCode file.
When the user types `/leetcode-testdata`, invoke the Skill tool with `skill: "leetcode-testdata"` before doing anything else.

# mongoPR
- **mongoPR** (`~/.claude/skills/mongoPR/SKILL.md`) - open a mongodb/mongo PR the standard way: SERVER JIRA ticket, `SERVER-XXXXX Description` commit/title, clean description, testing links as a PR comment, push to fork, PR against master. No AI attribution. Trigger: `/mongoPR` or asking to make/open/raise a mongo PR.
When the user types `/mongoPR`, invoke the Skill tool with `skill: "mongoPR"` before doing anything else.

# git-commit
- **git-commit** (`~/.claude/skills/git-commit/SKILL.md`) - write a commit message that describes what the added/changed code is and how it works (not a changelog), with NO hard line wrapping (one line per paragraph/bullet, let soft-wrap handle it) and no AI attribution; copy it to the clipboard and commit. Trigger: `/git-commit` or asking to write a commit message / commit the changes.
When the user types `/git-commit`, invoke the Skill tool with `skill: "git-commit"` before doing anything else.
