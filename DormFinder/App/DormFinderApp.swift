import SwiftUI

@main
struct DormFinderApp: App {
    @StateObject private var environment: AppEnvironment
    @StateObject private var authViewModel: AuthViewModel

    init() {
        let environment = AppEnvironment()
        _environment = StateObject(wrappedValue: environment)
        _authViewModel = StateObject(wrappedValue: AuthViewModel(authService: environment.authService))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .environmentObject(authViewModel)
                .environment(\.managedObjectContext, environment.persistence.container.viewContext)
        }
    }
}
