# Fix: Directory Already Exists

If you get "destination path 'ai-teacher-classroom' already exists", try these solutions:

## Solution 1: Check if it's empty or has old files

```bash
# See what's in the directory
ls -la

# If it's empty or just has a few files, remove it
rm -rf ~/ai-teacher-classroom

# Then clone fresh
git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git ai-teacher-classroom
cd ai-teacher-classroom
bash scripts/deploy_vast_ai.sh
```

## Solution 2: Update existing directory (if it has code)

```bash
# If it's a git repo, pull latest
cd ~/ai-teacher-classroom
git pull

# Then run deployment
bash scripts/deploy_vast_ai.sh
```

## Solution 3: Clone with different name

```bash
cd ~
git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git ai-teacher-classroom-new
cd ai-teacher-classroom-new
bash scripts/deploy_vast_ai.sh
```
