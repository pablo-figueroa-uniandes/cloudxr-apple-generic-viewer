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

import SwiftUI
import RealityKit

/// Overlay content for the foveated streaming immersive space.
///
/// `ImmersiveSpace(foveatedStreaming:)` draws the stream itself, so unlike `GenericImmersiveView`
/// there is no session entity here: only the gesture wall that lets a triple tap bring back the
/// window, and the same lifecycle hooks the classic immersive space uses.
struct FoveatedImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        RealityView { content in
            content.add(GenericImmersiveView.makeInvisibleGestureWall())
        }
        .onAppear {
            appModel.windowStateManager.immersiveSpaceOnAppear()
        }
        .onDisappear {
            appModel.windowStateManager.immersiveSpaceOnDisappear()
        }
        .onTapGesture(count: 3) {
            appModel.windowStateManager.toggleWindow()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background { // Handle headset doffing during session
                appModel.windowStateManager.dismissImmersiveSpaceIfOpen()
            }
        }
    }
}
