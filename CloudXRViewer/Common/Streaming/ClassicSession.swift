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

import CloudXRKit
import Foundation

/// Adapts a CloudXRKit `Session` to `ViewerSession`.
///
/// The adapter keeps no state of its own: every property reads through to the wrapped session, so
/// SwiftUI observation of `Session.state` keeps working through it.
@MainActor
final class ClassicSession: ViewerSession {
    let session: Session

    init(_ session: Session) {
        self.session = session
    }

    var viewerStatus: ViewerStatus {
        switch session.state {
        case .initialized:
            .initialized
        case .authenticating, .authenticated, .connecting:
            .connecting
        case .connected:
            .connected
        case .pausing:
            .pausing
        case .paused:
            .paused
        case .resuming:
            .resuming
        case .disconnecting:
            .disconnecting
        case .disconnected(let result):
            switch result {
            case .success:
                .disconnected(error: nil)
            case .failure(let error):
                .disconnected(error: error.localizedDescription)
            }
        @unknown default:
            .initialized
        }
    }

    var statusDescription: String {
        session.state.description
    }

    var channelIDs: [ViewerChannelID] {
        session.availableMessageChannels.map { channelInfo in
            ViewerChannelID(
                label: "Channel [\(channelInfo.uuid.map { String($0) }.joined(separator: ","))]",
                key: channelInfo
            )
        }
    }

    func channel(for id: ViewerChannelID) -> (any ViewerChannel)? {
        guard let channelInfo = id.key.base as? ChannelInfo else {
            return nil
        }
        return session.getMessageChannel(channelInfo)
    }

    func disconnect() async {
        session.disconnect()
    }

    func pause() async throws {
        session.pause()
    }

    func resume() async throws {
        try session.resume()
    }
}

extension CloudXRKit.MessageChannel: ViewerChannel {
    var statusDescription: String {
        status.rawValue
    }

    func send(_ data: Data) throws {
        guard sendServerMessage(data) else {
            throw ChannelSendError()
        }
    }
}
