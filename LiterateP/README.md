# The CloudXR viewer with foveated streaming as a literate program

This directory presents the source code of this fork of NVIDIA's CloudXR Generic Viewer, with its second streaming backend (Apple's Foveated Streaming on visionOS, StreamingSession on iOS), as a literate program in the sense of Donald Knuth: a book written for people, from which the program for the machine can be extracted. The notation is Norman Ramsey's noweb, handled by the small self-contained tool `lit.py` (the one from `cvi26-7`), so noweb itself isn't needed.

```
chapters/*.nw       the web: LaTeX prose interleaved with named code chunks, read in file-name order
lit.py              tangle (web → sources), weave (web → LaTeX), check (tangled == repository sources)
cloudxrviewer.tex   LaTeX driver: preamble, chunk markup, bibliography, chunk index
Makefile            make check | make pdf | make tangle | make clean
cloudxrviewer.pdf   the typeset book (committed)
```

## Commands

| Command | What it does |
|---|---|
| `make check` | Tangles every root chunk and compares it byte for byte with the file of the same path in the repository. It also fails if a project source file isn't produced by any root chunk. |
| `make pdf` | Weaves the web, typesets it with [tectonic](https://tectonic-typesetting.github.io), and copies the result to the committed `cloudxrviewer.pdf`. |
| `make tangle` | Writes the tangled sources to `build/tangled/` without touching the project. |

Tectonic downloads the LaTeX packages it needs on the first run. Code is set in Menlo, which ships with macOS.

## What the web covers

The roots are every Swift file under `CloudXRViewer/`, `Config.xcconfig`, the visionOS entitlements and the two `Info.plist` files. `CloudXRViewer.xcodeproj/project.pbxproj` is deliberately left out: Xcode maintains it, and it is not meant to be read. Asset catalogs and `Settings.bundle` are not code and are left out too.

| Chapter | Sources |
|---|---|
| `00-overview` | Introduction, foveation, the two backends, the shared license header chunks |
| `10-app` | `Common/ViewerApp.swift`, `AppModel.swift`, `AppDelegate.swift`, `TestHelper.swift` |
| `20-abstraction` | `Common/Streaming/ViewerSession.swift` |
| `30-classic` | `Common/Streaming/ClassicSession.swift`, `Common/SessionConfigView.swift`, `Common/GuestMode.swift` |
| `40-foveated` | `Common/Streaming/FoveatedSession.swift`, the foveated connect flow of `SessionConfigView`, `Config.xcconfig`, entitlements, `Info.plist` files |
| `50-visionos` | `Common/WindowStateManager.swift` and `visionOS/` |
| `60-ios` | `iOS/` |
| `70-messaging` | `Common/ServerActionsView.swift` |
| `80-utilities` | `SessionConfigView+extensions.swift`, `StarRatingView.swift` and the small helpers |

## Web syntax

| Syntax | Meaning |
|---|---|
| `<<name>>=` | Starts a code chunk. Defining the same name again appends to it. |
| `@` | Starts documentation (LaTeX). Text after `@ ` on the same line belongs to it. |
| `<<name>>` | On its own line inside code, includes that chunk. The line's indentation is added to every included line. |
| `[[code]]` | Inline code in the prose. |
| `@nonl` | As the last line of a root chunk: the file ends without a newline (many of NVIDIA's files do). This is the one addition to `cvi26-7`'s `lit.py`; the other is listing languages for `.plist` and `.entitlements`. |

A chunk named like a file path (containing `/` or `.`) that no other chunk uses is a root chunk. Tangling writes it to that path.

## Keeping the book and the code in sync

The sources in the repository are still the ones Xcode builds. After changing code, update the matching chunk in `chapters/` and run `make check` until it prints only `ok` lines, then `make pdf`. The `--require` globs in the Makefile cover every Swift file, so a new file that no chunk tangles is reported as `UNCOVERED`.
