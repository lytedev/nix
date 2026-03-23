# Issues

Issues are tracked as individual markdown files in this directory.

- **`open/`** — active issues
- **`closed/`** — resolved issues (move files here when done)

## Creating an issue

Add a `.md` file to `open/` with a `# Title` heading. Optionally include
`**Labels**:` and `**Related**:` metadata lines.

## Closing an issue

Move the file from `open/` to `closed/`.

## Finding issues

```bash
ls issues/open/                              # list open issues
grep -rl "beefcake" issues/                  # issues mentioning a host
grep "Labels.*service" issues/open/*.md      # issues with a label
```
