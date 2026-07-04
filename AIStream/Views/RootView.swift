//
//  RootView.swift
//  AIStream
//
//  Created by Poonam More on 17/02/26.
//

import SwiftUI

/// Root view that shows Setup or Dashboard based on session state.
struct RootView: View {
    @ObservedObject private var session = AppSession.shared

    var body: some View {
        Group {
            if session.isAuthenticated {
                DashboardView()
            } else {
                SetupView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.isAuthenticated)
    }
}
