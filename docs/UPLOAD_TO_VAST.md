# Upload Project Files Directly to Vast.ai (No GitHub Needed)

If you don't want to push to GitHub, you can upload files directly using SCP.

## From Your Windows Machine (Cursor Terminal)

### Option 1: Using Git Bash or PowerShell with SCP

```bash
# From your project directory
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey

# Upload entire project to Vast.ai
scp -P 11071 -r * root@ssh4.vast.ai:~/ai-teacher-classroom/

# Or upload specific directories and files
scp -P 11071 docker-compose.yml root@ssh4.vast.ai:~/ai-teacher-classroom/
scp -P 11071 -r scripts/ root@ssh4.vast.ai:~/ai-teacher-classroom/
scp -P 11071 -r services/ root@ssh4.vast.ai:~/ai-teacher-classroom/
scp -P 11071 -r frontend/ root@ssh4.vast.ai:~/ai-teacher-classroom/
scp -P 11071 -r configs/ root@ssh4.vast.ai:~/ai-teacher-classroom/
scp -P 11071 -r n8n/ root@ssh4.vast.ai:~/ai-teacher-classroom/
scp -P 11071 -r docs/ root@ssh4.vast.ai:~/ai-teacher-classroom/
scp -P 11071 README.md LICENSE requirements.txt .gitignore root@ssh4.vast.ai:~/ai-teacher-classroom/
```

### Option 2: Using SFTP or Vast.ai Web Interface

Some Vast.ai instances have a file upload interface in the dashboard.

### Option 3: Create a ZIP and upload

On Windows:
```powershell
# Create ZIP
Compress-Archive -Path * -DestinationPath project.zip

# Upload ZIP
scp -P 11071 project.zip root@ssh4.vast.ai:~/

# Then on Vast.ai instance:
ssh -p 11071 root@ssh4.vast.ai
cd ~
unzip project.zip -d ai-teacher-classroom
```
