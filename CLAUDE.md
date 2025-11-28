# SpaceCreator

## Local Build

Use `DEVELOPER_DIR` env var for xcodebuild commands:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project SpaceCreator.xcodeproj -scheme SpaceCreator -configuration Debug build
```

## Release Workflow

Use the justfile tasks for all release operations:

- `just build` - Trigger a build via workflow dispatch
- `just release` - Create a calver tag (YYYY-MM-DD-N) and push to trigger release
- `just logs` - View logs from the most recent workflow run
- `just open` - Open the GitHub Actions page

Do NOT manually create tags or run git commands for releases.

## Debugging with Logs

SpaceCreator uses os.Logger with subsystem `com.example.SpaceCreator` and category `SpaceCreation`.

Stream logs in real-time:
```bash
just applogs
```

The app logs startup messages and detailed multi-monitor debugging info when creating spaces.
