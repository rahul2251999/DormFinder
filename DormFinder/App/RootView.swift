import SwiftUI

/// Top-level navigation: shows the auth flow until the user signs in, then a tab bar with
/// Browse, Map, and My Bookings. Adapts label style for accessibility (Dynamic Type) by
/// letting the tab bar fall back to icon-only when text would be truncated.
struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.default, value: authViewModel.isAuthenticated)
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            ListingListView()
                .tabItem {
                    Label("Browse", systemImage: "list.bullet")
                }
                .accessibilityLabel("Browse listings")

            ListingMapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .accessibilityLabel("Map view of listings")

            MyBookingsView()
                .tabItem {
                    Label("My Bookings", systemImage: "calendar")
                }
                .accessibilityLabel("My bookings")
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppEnvironment.preview())
        .environmentObject(AuthViewModel(authService: AppEnvironment.preview().authService))
}
