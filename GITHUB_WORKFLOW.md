# GitHub Workflow Checklist

**Always commit and push changes as you make them!**

## Quick Commands

### On Local Machine (Windows)
```powershell
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey

# Check status
git status

# Add all changes
git add .

# Commit with message
git commit -m "Description of what you changed"

# Push to GitHub
git push origin main
```

### On VAST Instance (Linux)
```bash
cd ~/Nextwork-Teachers-TechMonkey

# Check status
git status

# Add all changes
git add .

# Commit with message
git commit -m "Description of what you changed"

# Push to GitHub
git push origin main
```

## When to Commit

✅ **Always commit when:**
- Updating connection scripts (IP/port changes)
- Modifying configuration files
- Adding new scripts or documentation
- Fixing bugs or making improvements
- Changing deployment scripts
- Updating documentation

❌ **Don't commit:**
- `.env` files (contains secrets)
- Generated files (models, outputs, logs)
- Temporary test files

## First-Time Git Setup on VAST Instance

If git isn't configured on the VAST instance:

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

## Common Workflow

1. **Make changes** (locally or on instance)
2. **Test changes** (verify they work)
3. **Commit changes** (`git add . && git commit -m "message"`)
4. **Push to GitHub** (`git push origin main`)
5. **Pull on other machine** (`git pull origin main`)

## Quick Status Check

```bash
# See what's changed
git status

# See what will be committed
git diff --cached

# See uncommitted changes
git diff
```

## If You Forget to Commit

If you made changes but forgot to commit:

```bash
# Check what's uncommitted
git status

# If you're on a different machine, pull first
git pull origin main

# Then add your local changes
git add .

# Commit and push
git commit -m "Catch up: description"
git push origin main
```

## Emergency: Revert Changes

If you need to undo changes:

```bash
# See what changed
git status

# Discard uncommitted changes to a file
git restore filename

# Discard ALL uncommitted changes (careful!)
git restore .

# Undo last commit (keeps changes)
git reset --soft HEAD~1

# Undo last commit (discards changes)
git reset --hard HEAD~1
```

## Branching (Optional)

For larger features, consider using branches:

```bash
# Create and switch to new branch
git checkout -b feature-name

# Make changes, commit
git add .
git commit -m "Feature description"

# Push branch
git push origin feature-name

# Merge back to main
git checkout main
git merge feature-name
git push origin main
```

## Remember

🔄 **Commit early, commit often!**
📤 **Push to GitHub after every meaningful change**
🔄 **Pull before starting work on a different machine**
✅ **Keep GitHub as the source of truth**
