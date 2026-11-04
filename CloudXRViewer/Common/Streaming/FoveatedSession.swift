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
import Network
#if FOVEATED_STREAMING
#if os(visionOS)
import FoveatedStreaming
#else
import StreamingSession
#endif
#endif

/// How the foveated session finds its server.
enum FoveatedEndpointKind: String, CaseIterable {
    /// The system browses for `_apple-foveated-streaming._tcp` servers and pairs with a QR code.
    case discover = "Discover & pair (QR code)"
    /// A server on the local network at a known address.
    case local = "Manual IP address"
    /// A cloud server reached through a signaling service.
    case remote = "Remote server"
}

extension FoveatedEndpointKind {
    /// The default port of the foveated streaming session-management protocol.
    static let defaultPort = 55000
}

#if FOVEATED_STREAMING
struct FoveatedEndpointError: LocalizedError {
    let errorDescription: String?
}

extension FoveatedEndpointKind {

    func endpoint(hostAddress: String, port: Int, serverName: String) throws -> FoveatedStreamingSession.Endpoint {
        switch self {
        case .discover:
            return .systemDiscovered
        case .local:
            let host = hostAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            let ipAddress: any IPAddress
            if let ipv4 = IPv4Address(host) {
                ipAddress = ipv4
            } else if let ipv6 = IPv6Address(host) {
                ipAddress = ipv6
            } else {
                throw FoveatedEndpointError(errorDescription: "\"\(host)\" is not a valid IP address")
            }
            guard (1...Int(UInt16.max)).contains(port), let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
                throw FoveatedEndpointError(errorDescription: "\(port) is not a valid port")
            }
            return .local(ipAddress: ipAddress, port: nwPort)
        case .remote:
            let name = serverName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw FoveatedEndpointError(errorDescription: "Enter a server name")
            }
            return .remote(serverName: name, signalingHeaders: [:])
        }
    }
}

extension FoveatedStreamingSession: ViewerSession {
    var viewerStatus: ViewerStatus {
        switch status {
        case .initialized:
            .initialized
        case .connecting:
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
        case .disconnected(let reason):
            .disconnected(error: reason == .appInitiatedDisconnect ? nil : reason.localizedDescription)
        @unknown default:
            .initialized
        }
    }

    var statusDescription: String {
        status.description
    }

    var channelIDs: [ViewerChannelID] {
        availableMessageChannels
            .map { ViewerChannelID(label: "Channel \($0.label)", key: $0) }
            .sorted { $0.label < $1.label }
    }

    func channel(for id: ViewerChannelID) -> (any ViewerChannel)? {
        guard let channelID = id.key.base as? MessageChannel.ID else {
            return nil
        }
        return messageChannel(for: channelID)
    }
}

private extension FoveatedStreamingSession.MessageChannel.ID {
    var label: String {
#if os(visionOS)
        // visionOS 26 has no public text form of a channel ID.
        if #available(visionOS 27.0, *) {
            return stringRepresentation
        }
        return String(describing: self)
#else
        return stringRepresentation
#endif
    }
}

extension FoveatedStreamingSession.MessageChannel: ViewerChannel {
    var statusDescription: String {
        switch channelStatus {
        case .ready:
            "ready"
        case .closed:
            "closed"
        @unknown default:
            "unknown"
        }
    }

    func send(_ data: Data) throws {
        try sendMessage(data)
    }
}
#endif
