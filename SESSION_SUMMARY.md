# Session Summary — CloudXR Viewer with Foveated Streaming

Date: 2026-11-04. Authors: Pablo Figueroa and Claude.

## Goal

Make a new version of [NVIDIA/cloudxr-apple-generic-viewer](https://github.com/NVIDIA/cloudxr-apple-generic-viewer) that supports foveated rendering through Apple's Foveated Streaming framework. The work is kept as a fork so it could eventually be offered back upstream.

## Repository

- Fork: `pablo-figueroa-uniandes/cloudxr-apple-generic-viewer`, cloned to `~/Development/fovRendering`.
- Remotes: `origin` is the fork and `upstream` is NVIDIA. All work happens on the `feature/foveated-streaming` branch.
- Commit layout: the first commit on top of upstream holds the code, project and README changes, so it can become a pull request. The course deliverables (`Docs/`, `LiterateP/`, this file, `CLAUDE.md`) are in separate commits that can be left out of a pull request branch.

## Decisions

| Question | Decision | Why |
|---|---|---|
| Replace CloudXRKit or add a backend? | Both backends, switchable in the config screen | Compare foveated and non-foveated streaming against the same server, and keep GDN, HUD and network stats for the classic path. |
| iOS | Apple's `StreamingSession` package (iOS 27) as the second backend | It has the same API as `FoveatedStreamingSession`. iOS has no eye tracking, so the iOS backend is labelled "Streaming Session". |
| App name and project | Keep `CloudXRViewer`, upstream's hand-maintained `.xcodeproj` and its folder layout; no XcodeGen | Keeps the diff small enough to upstream. The project was edited with a throwaway script (pbxproj Python library plus hand fixes), not committed. |
| Packages | Added to the project as remote package references (`cloudxr-framework` ≥ 6.0.2, `streamingsession` on `main`), with `Package.resolved` committed | Upstream asked users to add CloudXRKit by hand, but builds should work out of the box. |
| Abstraction | `ViewerSession` protocol, `ViewerStatus`, `ViewerChannelID`/`ViewerChannel` in `Common/Streaming/`. `ClassicSession` wraps CloudXRKit; `FoveatedStreamingSession` conforms directly through an extension | The adapters hold no state, so SwiftUI observation passes through them. |
| visionOS immersive space | A second scene, `ImmersiveSpace(foveatedStreaming:)`, with `immersivePresentationBehaviors = .automatic(open, dismiss)`. `WindowStateManager`, `LaunchView` and `ViewerApp` open and dismiss only the classic space | The foveated session presents its own space and `openImmersiveSpace(id:)` cannot open it. |
| Backend switch and alerts | Observers watch `ConnectionState` (backend + status) and ignore changes where the backend differs | Otherwise, switching back to a backend whose last session failed would replay its disconnection alert. |
| Simulator | The `FOVEATED_STREAMING` compilation condition is set in `Config.xcconfig` for `xros`/`iphoneos` SDKs only | FoveatedStreaming is not in the visionOS Simulator SDK. Gating keeps upstream's simulator workflow for the classic path. The iOS Simulator cannot build at all, because StreamingSession has no simulator slice (upstream's iOS path needs ARKit on a device anyway). |
| visionOS 26.4 vs 27 APIs | Deployment target 26.4; channel `stringRepresentation` and `InputCapability.handTracking` are used under `#available(visionOS 27.0, *)` | Those APIs were added in visionOS 27. |
| `WindowStateManager` | Made `@MainActor`; its unfair lock was replaced with a plain property | It touches the main-actor `AppModel`, and the lock's `Sendable` closure no longer compiled. |

## Verification

- `xcodebuild` passes for `CloudXRViewer-visionOS` on a device and on the visionOS Simulator, and for `CloudXRViewer-iOS` on a device (Xcode 27.2, `CODE_SIGNING_ALLOWED=NO`).
- The visionOS 27.2 Simulator launches the app with the classic form, identical to upstream.
- A temporary local build that exposed the picker in the simulator was used to check the foveated form's layout. It was reverted and never committed. As a result, the explanatory note moved out of the visionOS form, whose fixed height clipped it, and into the HUD tab.
- **Not tested** (needs hardware and a Windows/Linux CloudXR server): QR pairing and streaming on Apple Vision Pro; pause, resume and the system pause sheet; data-channel round trips with `StreamingSession-OpenXRSample`; hand tracking over foveated streaming; and the iOS StreamingSession path on an iOS 27 device.

## Device test checklist

1. Run `StreamingSession-WindowsApp` and `StreamingSession-OpenXRSample` (from apple/streamingsession) on a Windows PC on the same network.
2. On Vision Pro, select Foveated Streaming → Discover & pair → Connect, then scan the QR code. The immersive space should open by itself.
3. Server Actions: pick a channel and send Action 1/2. Check that replies arrive.
4. Press the Digital Crown: the session pauses and the system pause sheet appears. Resume.
5. Disconnect, switch to CloudXR, and connect to a LÖVR sample server by IP to confirm the classic path still works.
6. Repeat steps 2–3 on an iOS 27 device.
