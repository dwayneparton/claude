---
name: test-coverage
description: Write tests and coverage

---

## Steps

1. **Identify what to test:**
   - If the user specifies files or functions, use those as the target.
   - Otherwise, check `git diff --name-only` for recently changed source files.
   - Read each target file to understand its public API, branches, and edge cases.

2. **Check for existing tests:**
   - Look for existing test files alongside the target (e.g., `foo.test.ts`, `foo_test.go`, `test_foo.py`).
   - Read existing tests to understand current coverage, patterns, and test utilities already in use.
   - Identify gaps: untested functions, missing branch coverage, missing edge cases.

3. **Check for shared test utilities:**
   - Look for existing test helpers, fixtures, factories, or shared mocks (e.g., `__tests__/`, `tests/`, `__mocks__/`, `conftest.py`, `test_helpers_test.go`).
   - Reuse existing utilities rather than duplicating setup logic.
   - If a new shared utility is needed (mock, factory, fixture), add it in the appropriate shared location — not inline in the test file.

4. **Write the tests:**
   - Write only the tests needed to cover the gaps identified in step 2.
   - Prefer table-driven / parameterized tests when multiple inputs exercise the same code path.
   - Each test should cover a distinct behavior or branch — no redundant tests.
   - Test the public interface, not implementation details.
   - Cover: happy path, error/failure cases, boundary conditions, and any non-obvious branches.

5. **Run the tests:**
   - Run the test suite for the target files and verify all tests pass.
   - If tests fail, fix them before proceeding.

6. **Check coverage (if tooling is available):**
   - Run coverage for the target files (e.g., `go test -cover`, `npm run test`, `pytest --cov`).
   - Report the coverage result to the user.
   - If there are still meaningful uncovered branches, add targeted tests for them.

## Important

- Always follow the established testing patterns and conventions already in the repo. Read existing tests first and match their style, structure, and utilities.
- Tests should be written in a way that creates the most effective coverage with the fewest tests.
- Keep them minimal — optimize for maximum coverage, not test count.
- If a test utility is needed or a shared mock is missing, add it in the appropriate shared location.
- Keep tests lean and effective. No unnecessary setup, no redundant assertions.
- Do NOT test generated code, third-party libraries, or trivial getters/setters.
