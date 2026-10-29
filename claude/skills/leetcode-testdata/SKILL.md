---
name: leetcode-testdata
description: "Add runnable test data to a LeetCode solution file: detect the Solution method signature, generate diverse test cases (5-10 if the user doesn't specify a count), wire them into a test harness in main() with expected values and PASS/FAIL output, then compile and run to verify. Trigger: /leetcode-testdata or asking to add test data / tests to a LeetCode file."
---

# /leetcode-testdata

Add a self-checking test harness to a LeetCode solution file. The user names a
file (and optionally how many tests); this fills in test cases that cover normal
and edge inputs, each compared against an **independently-reasoned** expected
value, printing `PASS`/`FAIL`. Then it compiles and runs to confirm.

## Usage

```
/leetcode-testdata <file>              # add tests (default: 5-10, pick a sensible count)
/leetcode-testdata <file> <n>          # add exactly n tests
/leetcode-testdata two-sum.cpp 8       # example
```

If the user asks in plain language ("add test data to two-sum.cpp", "put some
tests in this file"), treat it the same way.

## Rules

- **Count:** if the user gives a number, honor it exactly. If not, add **5-10**
  tests — lean toward the number of meaningfully distinct cases the problem has
  (simple problems ~5, richer ones up to 10). Never fewer than 5 unless the user
  says so.
- **Expected values are reasoned independently**, from the problem's semantics —
  NOT copied from the solution's own output. The whole point is that a wrong
  solution should produce `FAIL`. If you cannot determine the correct expected
  value with confidence, say so rather than rubber-stamping the solution's output.
- **Never modify the `Solution` class / user's algorithm.** Only touch includes,
  helper functions, and `main()` (or the file's equivalent entry point).
- **Preserve the user's style** — indentation (tabs vs spaces), brace placement,
  and whether they use `using namespace std;`. Match what's already in the file.
- **Separate the user's work from the harness with a banner.** Insert this exact
  comment block immediately above the entire testing area (helpers + `main()`),
  so the user's solution is visually separated from generated tests:
  ```
  // ------------------------------------------------------------------------
  // Claude code test harness below
  // ------------------------------------------------------------------------
  ```
  Use the language's comment syntax if not C/C++ (e.g. `#` lines for Python). If
  the banner is already present, don't duplicate it.

## Steps

1. **Resolve args.** Identify the target file (error clearly if it doesn't exist)
   and the requested count (else default per the Rules above).

2. **Read the file.** Find the `Solution` method: its name, parameter types, and
   return type. This determines how to build inputs and compare outputs.

3. **Make it compile locally if needed.** LeetCode files often omit headers and
   rely on an implicit `using namespace std;`. Add only what's missing
   (`#include <vector>`, `<unordered_map>`, `<string>`, `<algorithm>`, etc., and
   `using namespace std;` if the solution uses unqualified names). Do not
   restructure existing code.

4. **Design the cases.** Cover: the canonical examples from the problem, plus edge
   cases relevant to the signature — empty / single-element inputs, duplicates,
   negatives, zeros, all-same, min/max bounds, no-solution, already-sorted vs
   reversed, etc. Keep each case's expected value correct by reasoning.

5. **Write the harness** in `main()`, preceded by the separator banner (see Rules):
   - A `run_test(id, <inputs...>, expected)` helper that calls the solution,
     compares `got == expected`, and prints
     `test <id> <inputs> -> got=<...> expected=<...>  PASS|FAIL`.
   - For container return types (`vector`, etc.) add a small `print_vec`/print
     helper. For order-insensitive answers (e.g. some subset problems), sort both
     sides before comparing, and note that in a comment.
   - One `run_test(...)` line per case in `main()`.

6. **Compile and run to verify.** Use the same flags as the editor/runner:
   `g++ -std=c++20 -O2 -Wall <file> -o /tmp/<name> && /tmp/<name>`.
   (If a `compile_flags.txt` exists at the LeetCode root, match its standard.)
   All cases should print `PASS`. If a case `FAIL`s:
   - First re-check YOUR expected value — a wrong expected is your bug, fix it.
   - If the expected is genuinely correct and the solution disagrees, the
     **solution** has a bug: do NOT change the expected to hide it. Report the
     failing case to the user.

7. **Report.** State the file, how many tests were added, whether all passed, and
   surface any real solution bug or any case where you were unsure of the expected
   value.

## Other languages

If the file is Python (`class Solution` + methods) or another language, adapt:
build the equivalent test runner in that language's entry point (`if __name__ ==
"__main__":` for Python) with `assert`/print PASS-FAIL, and run it to verify. The
rules above (independent expected values, don't touch the solution, default 5-10)
still apply.
