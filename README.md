# Auto-close issues that are "Done"

Automatically close issues that are marked as "Done" in a GitHub project but still open in the repo.

### Quickstart

Create a Personal Access Token (PAT) with the following privileges:

- `public_repo` 
- `read:project`
- `read:org` (Only required for projects owned by organizations)

Add that token to your repository secrets with the name `GITHUB_TOKEN_PROJECT_ACCESS` or a similar name.

Create a GitHub action file in `.github/workflows/` with the following code:

```yaml
name: Close done issues

on:
  # Enables manual triggers of this action
  workflow_dispatch:
  # Runs this action every Monday-Friday at 5am UTC
  schedule:
    - cron: "00 5 * * 1-5"

jobs:
  auto-close-issues:
    name: Auto-close issues that are done
    runs-on: ubuntu-latest
    env:
      # Gives the gh CLI access to your project
      GH_TOKEN: ${{ secrets.GH_TOKEN_PROJECT_ACCESS }}
    steps:
      - uses: actions/checkout@v3
      - uses: widal001/auto-close-issues@v1
        with:
          owner: widal001
          owner-type: user
          project-number: "3"
          status: "✅ Done"
          # optionally control number of project items returned per API call
          # must be less than or equal 100 due to GitHub limits
          batch-size: "100"
```
