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
// Copyright (c) 2026 Pablo Figueroa and Claude.

import Foundation

/// The streaming stack used to reach the server.
///
/// `classic` is the CloudXRKit Swift package this viewer was built on. `foveated` is Apple's
/// Foveated Streaming system framework on visionOS (the headset shares the approximate region the
/// user looks at so the server spends its bits there) and Apple's StreamingSession package on iOS,
/// which exposes the same API without eye tracking.
enum StreamingBackend: String, CaseIterable {
    case classic
    case foveated

    var label: String {
        switch self {
        case .classic:
            "CloudXR"
#if os(visionOS)
        case .foveated:
            "Foveated Streaming"
#else
        case .foveated:
            "Streaming Session"
#endif
        }
    }

    /// The backends this build can use; simulator builds have no foveated backend.
    static var available: [StreamingBackend] {
#if FOVEATED_STREAMING
        allCases
#else
        [.classic]
#endif
    }
}

/// Connection status shared by both backends, so the UI does not depend on either SDK's enum.
enum ViewerStatus: Equatable {
    case initialized
    case connecting
    case connected
    case pausing
    case paused
    case resuming
    case disconnecting
    /// `error` is nil when the disconnection was clean.
    case disconnected(error: String?)

    /// The session can start a new connection.
    var isIdle: Bool {
        switch self {
        case .initialized, .disconnected:
            true
        default:
            false
        }
    }

    var isDisconnected: Bool {
        if case .disconnected = self { true } else { false }
    }
}

/// A status together with the backend that reported it, so observers can tell a real status
/// change from one caused by switching backends.
struct ConnectionState: Equatable {
    let backend: StreamingBackend
    let status: ViewerStatus
}

/// Identifies an opaque data channel independently of the backend's own channel type.
struct ViewerChannelID: Hashable {
    /// Human-readable name for the channel picker.
    let label: String
    /// The backend's own identifier (`ChannelInfo` or `FoveatedStreamingSession.MessageChannel.ID`).
    let key: AnyHashable
}

/// An open opaque data channel to the server.
protocol ViewerChannel: AnyObject {
    var receivedMessageStream: AsyncStream<Data> { get }
    var statusDescription: String { get }
    func send(_ data: Data) throws
}

struct ChannelSendError: LocalizedError {
    var errorDescription: String? { "The message could not be sent on this channel" }
}

/// What the views need from a streaming session, whichever backend provides it.
@MainActor
protocol ViewerSession: AnyObject {
    var viewerStatus: ViewerStatus { get }
    /// The backend's own status text, shown under the configuration form.
    var statusDescription: String { get }
    var channelIDs: [ViewerChannelID] { get }
    func channel(for id: ViewerChannelID) -> (any ViewerChannel)?
    func disconnect() async
    func pause() async throws
    func resume() async throws
}
