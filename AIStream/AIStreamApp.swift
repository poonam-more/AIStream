//
//  Created by Poonam More on 12/02/26.
//

import SwiftUI
import CoreData

@main
struct AIStreamApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        APIClient.onUnauthorized = { AppSession.shared.handleUnauthorized() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
