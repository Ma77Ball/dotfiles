---
name: talk
description: "Draft a professional post for a public developer community (GitHub Discussion/Issue, mailing list, forum) that asks a technical question or raises a design point. Searches for prior art first so it isn't a duplicate, writes in a plain professional tone (no greetings, no thanks, no grandiosity, no hedging), and can post it to GitHub Discussions on request. Trigger: /talk"
---

# /talk

Turn a question or design point into a **short, professional community post** ready to send to a project's GitHub Discussions, Issues, mailing list, or forum. Optionally post it.

The goal is a post that a busy maintainer will read and answer: specific, grounded in the project's own docs/code, and free of filler.

## Usage

```
/talk <question or point>                 # draft a post
/talk <point> --repo owner/name           # draft for a specific repo + search it for prior art
/talk <point> --post                       # draft, then post to GitHub Discussions (asks which category if unclear)
/talk <point> --issue                      # frame as a GitHub Issue instead of a Discussion
```

## Steps

1. **Understand the point.** Read whatever context is in the conversation (docs fetched, code read). Pin the claim to a real source: quote or cite the exact doc page/section, file, or line the question is about. Do not invent detail.

2. **Check it isn't a duplicate (required before posting).** Search the project's Issues and Discussions (and mailing-list archive if relevant) for the topic and its synonyms. Report what exists, link the closest prior art, and reference it in the post ("closest is #54, which ..."). If something already answers it, say so and stop before posting.

3. **Pick the venue.** Match the project's own CONTRIBUTING guidance. Default for a design/usage question: GitHub Discussions (Ideas or Q&A). Bugs and concrete change proposals: Issues. Respect projects that use JIRA or a mailing list as the front door.

4. **Draft it** following the Tone Rules below.

5. **Post only on explicit request** (`--post`, or the user says to post). Posting is outward-facing under the user's identity, so confirm the venue/category first unless already told. Use `gh api graphql` with `createDiscussion` for Discussions, `gh issue create` for Issues. Report back the URL.

## Tone Rules (this is the important part)

**No greeting, no sign-off.** No "Hi all", "Hey team", "thanks in advance", "cheers". Open on the substance.

**No grandiosity or flattery.** Don't praise the project ("great work", "really nice to see"), don't thank them for existing. Don't editorialize about yourself ("just trying to understand"). State the point.

**No hedging theater.** One short "I searched and didn't find this" is fine and useful; drop "apologies if I missed it", "not proposing anything", "happy to be wrong", and similar padding. At most one closing line offering a next step ("Happy to open an issue/AIP if there's interest").

**Lead with the grounding.** First sentence cites the doc/code the question is about, so the reader knows exactly what you read. Then the question.

**Ask specific, numbered questions.** Break a design question into 2-4 concrete sub-questions. Where you already know the likely answer (a constraint, a tradeoff), frame it as a question that shows you understand it ("FFM finalized in JDK 22 while the project targets 8/11/17, so I assume backward compatibility is a factor"). This earns a real answer instead of a brush-off.

**Keep it tight.** A title and a short body. No walls of text, no restating the docs at length. Link, don't paste.

**Plain, technical, neutral.** Professional engineer asking a peer. Not stiff, not chummy.

**No em dashes.** Use commas, colons, hyphens, or parentheses.

**No manual line wrapping.** One paragraph per line; soft-wrap handles width. Newline only for a real structural break.

**No AI/tool attribution** anywhere in the post.

## Recommended shape

```
Title: <specific question or proposal, scannable>

<1-2 sentences citing the exact doc/section/file, plus the prior-art note from the search>

<the core question in one sentence>

1. <specific sub-question, with the constraint you already see>
2. <specific sub-question>
3. <roadmap / is-this-planned sub-question>

<optional single next-step line>
```

## Posting mechanics

**GitHub Discussion** (GraphQL; needs repo id + category id):
```
gh api graphql -f query='{ repository(owner:"OWNER", name:"NAME"){ id discussionCategories(first:20){ nodes{ id name slug } } } }'
gh api graphql -f query='mutation($r:ID!,$c:ID!,$t:String!,$b:String!){ createDiscussion(input:{repositoryId:$r, categoryId:$c, title:$t, body:$b}){ discussion{ url } } }' -f r=REPO_ID -f c=CATEGORY_ID -f t="TITLE" -f b="BODY"
```

**GitHub Issue:** `gh issue create --repo OWNER/NAME --title "..." --body "..."`

Always report the resulting URL to the user.
