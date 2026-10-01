# Update PR Title and Description

Update the current pull request's title and description based on the actual changes.

## Instructions

1. Get the current PR number and existing description:
   ```
   gh pr view --json number,title,body,headRefName,baseRefName
   ```

2. Check if the repo has a PR template:
   ```
   Look for .github/pull_request_template.md or .github/PULL_REQUEST_TEMPLATE.md or docs/pull_request_template.md
   ```

3. Analyze the changes:
   - Run `gh pr diff` to see the full diff
   - Run `git log $(git merge-base HEAD main)..HEAD --oneline` to see commit history
   - Understand what changed and why

4. Preserve from the existing PR body (if present):
   - Any screenshot or image links (`![...](...)`  or `<img` tags)
   - Any video links or attachments
   - Any ticket/issue links (Jira, Linear, GitHub issues, etc.)
   - Any "Fixes #", "Closes #", "Relates to #" references

5. Generate the title using bracket format:
   - `[Feature]`: A new feature
   - `[Fix]`: A bug fix
   - `[Docs]`: Documentation changes
   - `[Style]`: Formatting changes (no code logic change)
   - `[Refactor]`: Code restructuring without changing behavior
   - `[Perf]`: Performance improvements
   - `[Test]`: Adding or updating tests
   - `[Chore]`: Maintenance tasks, dependency updates, tooling

   Use imperative mood. Keep under 72 characters.

6. Generate the description:
   - If a PR template exists in the repo, follow its structure and fill in each section
   - If no template exists, use this format:
     ```
     ## Summary
     Brief description of what this PR does and why.

     ## Changes
     - Bullet points of key changes

     ## Context
     Any relevant reasoning, tradeoffs, or related issues.
     ```
   - Preserve any existing screenshots, videos, and ticket links in their original location or in an appropriate section
   - Use imperative mood
   - Format with proper markdown

7. Show the generated title and description to the user for review before applying.

8. After user confirms, apply with:
   ```
   gh pr edit --title "<title>"
   gh pr edit --body "<body>"
   ```
