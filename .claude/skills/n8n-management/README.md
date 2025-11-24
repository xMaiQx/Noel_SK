# n8n-Management Skill - Quick Reference

## Installation
Skill is located at: `.skills/n8n-management/`
Packaged version: `n8n-management.zip`

## Quick Start

### Check Workflow Status
```bash
python3 .skills/n8n-management/scripts/n8n_api.py list-workflows
```

### Debug Failed Workflow
```bash
# Get latest execution
python3 .skills/n8n-management/scripts/n8n_api.py latest-execution "workflow_name"

# View specific execution
python3 .skills/n8n-management/scripts/n8n_api.py get-execution <id>
```

### Update Workflow
```bash
python3 .skills/n8n-management/scripts/n8n_api.py update-workflow <id> workflow.json
```

## Configuration
- **n8n URL**: https://5dc9eaf4cd4b.ngrok-free.app (update in script if ngrok restarts)
- **API Key**: Embedded in script (regenerate if needed)
- **Dependencies**: None (uses Python stdlib only)

## Full Documentation
See `SKILL.md` for complete usage guide.
