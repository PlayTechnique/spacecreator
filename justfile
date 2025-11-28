# SpaceCreator justfile

# GitHub repo info
repo := "PlayTechnique/spacecreator"

# Open the GitHub Actions page
open:
    open "https://github.com/{{repo}}/actions"

# Trigger a build via workflow dispatch
build:
    gh workflow run "Build and Release" --repo {{repo}}
    @echo "Build triggered! Opening actions page..."
    @sleep 2
    open "https://github.com/{{repo}}/actions"

# Generate next calver tag and push it (format: YYYY-MM-DD-N)
release:
    #!/usr/bin/env bash
    set -euo pipefail

    TODAY=$(date +%Y-%m-%d)

    # Find existing tags for today and get the highest sequence number
    EXISTING=$(git tag -l "v${TODAY}-*" | sort -t- -k4 -n | tail -1)

    if [ -z "$EXISTING" ]; then
        # No tags today, start with 1
        SEQ=1
    else
        # Extract the sequence number and increment
        SEQ=$(echo "$EXISTING" | sed "s/v${TODAY}-//" | sed 's/^0*//')
        SEQ=$((SEQ + 1))
    fi

    NEW_TAG="v${TODAY}-${SEQ}"

    echo "Creating tag: $NEW_TAG"
    git tag "$NEW_TAG"
    git push origin "$NEW_TAG"

    echo ""
    echo "Tag $NEW_TAG pushed! Release workflow will start automatically."

# View logs from the most recent workflow run
logs:
    gh run list --repo {{repo}} --limit 1 --json databaseId --jq '.[0].databaseId' | xargs -I {} gh run view {} --repo {{repo}} --log

# Stream SpaceCreator app logs (like tail -f)
applogs:
    log stream --predicate 'subsystem == "com.example.SpaceCreator"' --info --style compact
