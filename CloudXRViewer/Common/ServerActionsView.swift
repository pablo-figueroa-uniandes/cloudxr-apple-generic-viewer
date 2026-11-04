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
import os.log

struct ServerActionsView: View {
    static var logger = Logger()
    // Messages are sent via MessageChannel of the session in appModel.
    @Environment(AppModel.self) var appModel

    @State var lastMessageSent: String = ""
    @State var lastMessageReceived: String = ""

    @Binding var currentChannelSelection: ViewerChannelID?
    @Binding var currentChannel: (any ViewerChannel)?

    // Reader task for the currently selected channel.
    @State private var channelReaderTask: Task<Void, Never>?
    @State private var receivedMessageCount: Int = 0

    func sendMessage(message: String) {
        guard let channelSelection = currentChannelSelection else {
            Self.logger.warning("No channel selected")
            lastMessageSent = "Error - no channel"
            return
        }

        guard let messageData = message.data(using: .utf8) else {
            Self.logger.warning("String message could not be converted to data")
            lastMessageSent = "Error"
            return
        }

        if let channel = currentChannel {
            do {
                try channel.send(messageData)
                lastMessageSent = message
            } catch {
                Self.logger.warning("Failed to send message via current channel: \(error.localizedDescription)")
                lastMessageSent = "Error - failed to send"
            }
        } else {
            Self.logger.warning("No current channel available for send")
            lastMessageSent = "Error - no channel"
        }
    }

    var body: some View {
        Form {
            VStack {
                if let session = appModel.activeSession {
                    Picker("Channels", selection: $currentChannelSelection) {
                        ForEach(session.channelIDs, id: \.self) { channelID in
                            Text(channelID.label).tag(channelID as ViewerChannelID?)
                        }
                        Text("None").tag(nil as ViewerChannelID?)
                    }
                    .pickerStyle(.menu)
                    .id(session.channelIDs)
                    .onChange(of: currentChannelSelection) {
                        currentChannel = nil
                        // Cancel any existing reader task when switching selection.
                        channelReaderTask?.cancel()

                        guard let channelSelection = currentChannelSelection else {
                            return
                        }
                        guard let channel = session.channel(for: channelSelection) else {
                            return
                        }

                        currentChannel = channel
                        // Start a reader task for the selected channel.
                        channelReaderTask = Task {
                            for await message in channel.receivedMessageStream {
                                receivedMessageCount += 1
                                lastMessageReceived = "Message \(receivedMessageCount): " + String(decoding: message, as: UTF8.self)
                            }
                        }
                    }
                    .onChange(of: session.channelIDs) {
                        if let channelSelection = currentChannelSelection,
                           !session.channelIDs.contains(channelSelection)
                        {
                            currentChannelSelection = nil
                            // Cancel reader if selection disappears.
                            channelReaderTask?.cancel()
                            channelReaderTask = nil
                        }
                    }

                    if let channel = currentChannel {
                        Text("Status: \(channel.statusDescription)")
                    } else {
                        Text("Status: N/A")
                    }
                }

                Divider()

                VStack {
                    HStack {
                        Spacer()
                        Button("Action 1") {
                            sendMessage(message: "Action 1")
                        }
                        .disabled(currentChannelSelection == nil)
                        .buttonStyle(.borderedProminent)
                        Spacer()
                        Button("Action 2") {
                            sendMessage(message: "Action 2")
                        }
                        .disabled(currentChannelSelection == nil)
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                }
                Divider()
                VStack {
                    Text("Last message sent: ")
                    Divider()
                    Text(lastMessageSent)
                    Spacer()
                }
                Divider()
                VStack {
                    Text("Last message received:")
                    Divider()
                    Text(lastMessageReceived)
                    Spacer()
                }
            }
        }
        .onAppear {
            if let channel = currentChannel {
                channelReaderTask?.cancel()
                channelReaderTask = Task {
                    for await message in channel.receivedMessageStream {
                        receivedMessageCount += 1
                        lastMessageReceived = "Message \(receivedMessageCount): " + String(decoding: message, as: UTF8.self)
                    }
                }
            }
        }
        .onDisappear {
            channelReaderTask?.cancel()
            channelReaderTask = nil
        }
    }
}

#Preview {
    @Previewable @State var appModel = AppModel()
    @Previewable @State var selection: ViewerChannelID? = nil
    @Previewable @State var channel: (any ViewerChannel)? = nil
    ServerActionsView(currentChannelSelection: $selection, currentChannel: $channel)
        .environment(appModel)
}