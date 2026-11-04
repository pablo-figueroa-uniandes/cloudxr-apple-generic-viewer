// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is furnished
// to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice (including the next
// paragraph) shall be included in all copies or substantial portions of the
// Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
// OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
// OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// Copyright (c) 2008-2025 NVIDIA Corporation. All rights reserved.

import SwiftUI
import RealityKit
import CloudXRKit
#if FOVEATED_STREAMING
#if os(visionOS)
import FoveatedStreaming
#else
import StreamingSession
#endif
#endif

struct SavedSettings {
    @AppStorage("application") static var application: Application = .generic_viewer
    @AppStorage("streamingBackend") static var backend: StreamingBackend = .classic
}

/// The data that the app uses to configure its views.
@MainActor
@Observable
public class AppModel {
    /// The CloudXRKit session, created on the first classic connection.
    public var session: Session?

#if FOVEATED_STREAMING
    /// The foveated streaming session. It lives as long as the app because the visionOS
    /// `ImmersiveSpace(foveatedStreaming:)` scene is built from it.
    let foveatedSession = FoveatedStreamingSession()
#endif

    var backend = StreamingBackend.available.contains(SavedSettings.backend) ? SavedSettings.backend : .classic {
        didSet {
            SavedSettings.backend = backend
        }
    }

    /// The session of the selected backend, if it exists.
    var activeSession: (any ViewerSession)? {
        switch backend {
        case .classic:
            session.map { ClassicSession($0) }
        case .foveated:
#if FOVEATED_STREAMING
            foveatedSession
#else
            nil
#endif
        }
    }

    var status: ViewerStatus {
        activeSession?.viewerStatus ?? .initialized
    }

    var connectionState: ConnectionState {
        ConnectionState(backend: backend, status: status)
    }

    /// Why the last foveated connection attempt failed before the session reported a status.
    var foveatedConnectError: String?

    func disconnect() async {
        await activeSession?.disconnect()
    }

#if DEBUG
    var disableFeedback = true
#else
    var disableFeedback = false
#endif

    var isRatingViewPresented = false
    var ratingText = "Feedback"
    var showDisconnectionAlert = false

    var showStreamingAppView: Bool {
        status == .connected
    }

    var application = SavedSettings.application {
        didSet {
            SavedSettings.application = application
        }
    }

    #if os(visionOS)
    let windowStateManager = WindowStateManager()
    #endif
}