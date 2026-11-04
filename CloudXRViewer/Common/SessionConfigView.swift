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
import CloudXRKit
import OSLog
#if FOVEATED_STREAMING
#if os(visionOS)
import FoveatedStreaming
#else
import StreamingSession
#endif
#endif

struct SessionConfigView: View {
    @AppStorage("hostAddress") var hostAddress: String = ""
    @AppStorage("zone") private(set) var zone: Zone = .us_west
    @AppStorage("authMethod") private(set) var authMethod: AuthMethod = .starfleet
    @AppStorage("resolutionPreset") var resolutionPreset: ResolutionPreset = .standardPreset

#if os(visionOS)
    @AppStorage("enableHandTracking") var enableHandTracking: Bool = false
#endif

    @AppStorage("genericAppID") var genericAppID: Int = 0

    // Foveated streaming endpoint; the manual IP address reuses `hostAddress`.
    @AppStorage("foveatedEndpointKind") var foveatedEndpointKind: FoveatedEndpointKind = .discover
    @AppStorage("foveatedPort") var foveatedPort: Int = FoveatedEndpointKind.defaultPort
    @AppStorage("remoteServerName") var remoteServerName: String = ""

    @Environment(AppModel.self) var appModel
    @Environment(\.colorScheme) var colorScheme

#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    // TODO(tifchen): Revisit whether this can be included for iOS.
#endif

    @State var guestModeComponent: GuestModeComponent = GuestModeComponent()

    @State var awsalb = ""
    @State var sessionId = ""

    @State var useSimpleConfigView: Bool = {
        false
    }()

    @Binding var application: Application
    @State var isGuestModePopoverPresented: Bool = false

    var sessionConnected: Bool {
        switch appModel.status {
        case .initialized, .disconnected, .paused:
            false
        default:
            true
        }
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SessionConfigView.self)
    )

    // The order of these vars is important - the completion handler should be at the end
    var completionHandler: () -> Void

    var mainView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if useSimpleConfigView {
                        simpleConfigView
                    } else {
                        sessionConfigForm
                    }
                }
                .padding(.top, 8)
            }

            VStack(spacing: 16) {
                Text(stateDescription)
                    .frame(maxWidth: .infinity, alignment: .center)

                connectButton
            }
            .padding(.vertical, 128)
            .background(
                Color(.systemBackground)
                    .opacity(0.95)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .popover(isPresented: $isGuestModePopoverPresented,
                 attachmentAnchor: .point(.center),
                 arrowEdge: .top) {
            VStack {
                guestModeComponent.makeView()
            }
            .onAppear {
                guestModeComponent.configure {
                    isGuestModePopoverPresented = false
                    doConnect()
                }
            }
        }
        .presentationCompactAdaptation(.popover)
    }

    @ViewBuilder
    private var simpleConfigView: some View {
        VStack(alignment: .center) {
            Text("NVIDIA Omniverse Configurator")
                .font(.title)
                .padding(.top, 240)
        }
        .onAppear {
            zone = .us_west
            authMethod = .guest
            resolutionPreset = .standardPreset
            application = .generic_viewer
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private var connectButton: some View {
        Button(buttonLabel) {
            handleConnectButtonTap()
        }
        .disabled(connectButtonDisabled)
        .sheet(isPresented: Binding(get: { appModel.isRatingViewPresented }, set: { _ in })) {
            StarRatingView()
        }
        .confirmationDialog(
            "Do you really want to disconnect?",
            isPresented: Binding(
                get: { appModel.showDisconnectionAlert },
                set: { appModel.showDisconnectionAlert = $0 }
            ),
            titleVisibility: .visible
        ) {
            if !appModel.disableFeedback {
                Button("Disconnect with feedback") {
                    Task { await appModel.disconnect() }
                    appModel.isRatingViewPresented = true
                }
                Button("Disconnect without feedback", role: .destructive) {
                    Task { await appModel.disconnect() }
                }
            } else {
                Button("Disconnect", role: .destructive) {
                    Task { await appModel.disconnect() }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func handleConnectButtonTap() {
#if FOVEATED_STREAMING
        if appModel.backend == .foveated {
            handleFoveatedConnectButtonTap()
            return
        }
#endif

        if appModel.session?.state == .paused {
            try! appModel.session?.resume()
            self.completionHandler()
            return
        }

        if appModel.session?.state == .connected {
            appModel.showDisconnectionAlert = true
            return
        }

        // To be safe, disconnect from previous session
        switch appModel.session?.state {
        case .disconnected, .disconnecting:
            break
        default:
            appModel.session?.disconnect()
        }

        if usingGuestMode {
            isGuestModePopoverPresented = true
        }
        else {
            doConnect()
        }
    }

    private func doConnect() {
        let preset = resolutionPreset
        var cxrConfig = CloudXRKit.Config()
        cxrConfig.resolutionPreset = preset

#if os(visionOS)
    #if targetEnvironment(simulator)
        cxrConfig.handTrackingMode = enableHandTracking ? .simulated : .disabled
    #else
        cxrConfig.handTrackingMode = enableHandTracking ? .prediction : .disabled
    #endif
#endif

        var appID: UInt = 0

        if zone != .ipAddress {
            if application.appID != .unknown {
                appID = application.appID.rawValue
            } else if genericAppID > 0 {
                appID = UInt(genericAppID)
            } else {
                Self.logger.error("No valid appID configured for this application.")
                return
            }

            if !usingGuestMode {
                cxrConfig.connectionType = .nvGraphicsDeliveryNetwork(
                    appId: UInt(appID),
                    authenticationType: .starfleet(),
                    zone: zone.id
                )
            }
        } else {
            cxrConfig.connectionType = .local(ip: hostAddress)
        }

        if appModel.session == nil {
            appModel.session = CloudXRSession(config: cxrConfig)
        }

        Task { @MainActor in
            if usingGuestMode {
                let guestAuth = try await guestModeComponent.getGuestAuth(appID: appID)

                cxrConfig.connectionType = .nvGraphicsDeliveryNetwork(
                    appId: UInt(appID),
                    authenticationType: guestAuth,
                    zone: zone.id)
            }

            appModel.session?.configure(config: cxrConfig)
            try await appModel.session?.connect()
            completionHandler()
        }
    }

#if FOVEATED_STREAMING
    private func handleFoveatedConnectButtonTap() {
        let session = appModel.foveatedSession

        switch session.status {
        case .paused:
            Task { @MainActor in
                do {
                    try await session.resume()
                    completionHandler()
                } catch {
                    Self.logger.error("Foveated streaming resume failed: \(error.localizedDescription)")
                    appModel.foveatedConnectError = error.localizedDescription
                }
            }
        case .connected:
            appModel.showDisconnectionAlert = true
        default:
            doConnectFoveated()
        }
    }

    private func doConnectFoveated() {
        let session = appModel.foveatedSession
        appModel.foveatedConnectError = nil

        Task { @MainActor in
            do {
                let endpoint = try foveatedEndpointKind.endpoint(
                    hostAddress: hostAddress,
                    port: foveatedPort,
                    serverName: remoteServerName
                )

#if os(visionOS)
                // The session opens the immersive space once streaming starts and dismisses it
                // on disconnect, so neither LaunchView nor WindowStateManager opens it.
                session.immersivePresentationBehaviors = .automatic(openImmersiveSpace, dismissImmersiveSpace)

                if #available(visionOS 27.0, *) {
                    let capabilities: Set<FoveatedStreamingSession.InputCapability> = enableHandTracking ? [.handTracking] : []
                    if !capabilities.isEmpty {
                        _ = await session.requestAuthorization(for: capabilities)
                    }
                    session.requestedInputCapabilities = capabilities
                }
#endif

                try await session.connect(endpoint: endpoint)
                completionHandler()
            } catch {
                Self.logger.error("Foveated streaming connection failed: \(error.localizedDescription)")
                appModel.foveatedConnectError = error.localizedDescription
            }
        }
    }
#endif
}

#Preview {
    @Previewable @State var appModel = AppModel()
    return SessionConfigView(application: $appModel.application) { () -> Void in }
        .environment(appModel)
}
