# CLAUDE.md

A fork of NVIDIA's `cloudxr-apple-generic-viewer` (SwiftUI, visionOS + iOS) that adds Apple's Foveated Streaming as a second streaming backend next to CloudXRKit. `README.md` describes the app; `SESSION_SUMMARY.md` records the decisions.

## Git

- Work on `feature/foveated-streaming`. `origin` is the fork (`pablo-figueroa-uniandes`) and `upstream` is NVIDIA.
- Keep the code diff upstream-friendly: keep the app name, the folder layout and NVIDIA's MIT header on existing files. New files carry the same MIT text with `Copyright (c) 2026 Pablo Figueroa and Claude`.
- Put course deliverables (`Docs/`, `LiterateP/`, `SESSION_SUMMARY.md`, this file) in commits separate from code commits.

## Build

```sh
xcodebuild -project CloudXRViewer.xcodeproj -scheme CloudXRViewer-visionOS -destination 'generic/platform=visionOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project CloudXRViewer.xcodeproj -scheme CloudXRViewer-visionOS -destination 'generic/platform=visionOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project CloudXRViewer.xcodeproj -scheme CloudXRViewer-iOS -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

- Requires Xcode 26.4 or later (developed with 27.2): visionOS 26.4 SDK for FoveatedStreaming, iOS 27 SDK for the StreamingSession package.
- Build all three after changes. The simulator build compiles the foveated code out, because `FOVEATED_STREAMING` is set for device SDKs only in `Config.xcconfig`; the device builds compile it. The iOS Simulator cannot build (StreamingSession has no simulator slice).
- `CloudXRViewer.xcodeproj` is upstream's hand-maintained project (not XcodeGen). Add new files to the right targets, either in Xcode or with care in `project.pbxproj`, and check with `plutil -lint`.

## Code map

- `Common/Streaming/`: `ViewerSession` protocol and `ViewerStatus`/`ConnectionState`/channel types; `ClassicSession` (CloudXRKit adapter); `FoveatedSession.swift` (endpoints + `FoveatedStreamingSession` conformance).
- `AppModel`: `backend`, the classic `session`, `foveatedSession` and `activeSession`. The UI reads `status`/`activeSession`, never a specific SDK's state, except in backend-specific code.
- On visionOS the foveated `ImmersiveSpace(foveatedStreaming:)` is opened and dismissed by the session (`immersivePresentationBehaviors`); only the classic space is opened by `openImmersiveSpace(id:)`.
- visionOS 27-only APIs (channel `stringRepresentation`, `InputCapability`) must stay behind `#available`.

## Documentation upkeep

After changing source code, update the matching `LiterateP/chapters/*.nw` (then run `make check` and `make pdf` in `LiterateP/`) and the relevant section of `Docs/CloudXRViewer-Foveated-Theory-and-Code.md` (rebuild its PDF with the script in `Docs/tools/`).
