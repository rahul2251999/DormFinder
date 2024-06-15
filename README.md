# DormFinder

A native iOS app that helps university students browse, search, and book dorm/off-campus
housing near their school — built with SwiftUI, MVVM, Combine, async/await networking, and
an offline-first CoreData cache. Includes an optional FastAPI + PostgreSQL backend so the
whole stack runs end to end.

## Contents

- [iOS app](#ios-app)
  - [Folder structure](#folder-structure)
  - [Architecture](#architecture)
  - [Setting up the Xcode project](#setting-up-the-xcode-project)
  - [Running the app](#running-the-app)
  - [Tests](#tests)
- [Backend](#backend)
  - [Setup](#backend-setup)
  - [Endpoints](#endpoints)
- [Key design decisions](#key-design-decisions)

---

## iOS app

### Folder structure

```
DormFinder/
├── App/
│   ├── DormFinderApp.swift        # @main entry point, builds AppEnvironment
│   ├── AppEnvironment.swift       # Composition root / dependency container
│   ├── RootView.swift             # Auth gate + tab navigation
│   └── UITestingSupport.swift     # Deterministic fixtures for UI tests (#if DEBUG)
├── Models/
│   ├── Listing.swift              # Listing, RoomType, Amenity, ListingFilter
│   ├── Booking.swift              # Booking, BookingStatus, BookingRequest
│   └── User.swift                 # User, Login/Signup payloads, AuthResponse, Session
├── Views/
│   ├── Auth/AuthView.swift
│   ├── Listings/                  # List, Row, Detail, Filter
│   ├── Map/ListingMapView.swift
│   ├── Booking/                   # BookingFlowView, MyBookingsView
│   └── Components/
├── ViewModels/
│   ├── ListingListViewModel.swift
│   ├── ListingDetailViewModel.swift
│   ├── MapViewModel.swift
│   ├── AuthViewModel.swift
│   └── MyBookingsViewModel.swift
├── Services/
│   ├── NetworkService.swift       # Protocol + URLSession async/await implementation
│   ├── AuthService.swift          # Login/signup/refresh, JWT session lifecycle
│   ├── ListingService.swift
│   ├── BookingService.swift
│   └── KeychainService.swift      # Secure JWT/session persistence
├── Persistence/
│   ├── Model.xcdatamodeld         # CoreData model: CachedListing, CachedBooking
│   ├── PersistenceController.swift
│   ├── CachedListing+Mapping.swift
│   ├── CachedBooking+Mapping.swift
│   └── SyncManager.swift          # Offline-first reads/writes + background sync
├── Utilities/
│   └── NetworkMonitor.swift       # Combine-based connectivity publisher
└── Resources/
    └── Assets.xcassets

DormFinderTests/                   # XCTest unit tests (view models, networking, sync)
DormFinderUITests/                 # XCUITest: end-to-end booking flow

backend/                           # Optional FastAPI + PostgreSQL service
```

### Architecture

**MVVM + Combine.** Views are thin SwiftUI structs that bind to `@Published` properties on
`ObservableObject` view models. View models own all business logic and expose state through
Combine pipelines (e.g. `ListingListViewModel` debounces filter changes and recomputes the
visible list reactively via `Publishers.CombineLatest`).

**Dependency injection via a composition root.** `AppEnvironment` (in `App/AppEnvironment.swift`)
builds every service, the CoreData stack, and the `SyncManager` exactly once, and is injected
into the view hierarchy as an `@EnvironmentObject`. Views construct their view models lazily in
`.task {}` once the environment is available. This is also what makes `AppEnvironment.preview()`
and the `UI-TESTING` launch-argument path (see `UITestingSupport.swift`) possible — swap the
concrete services for fakes without touching a single view.

**Protocol-based service layer.** `NetworkServiceProtocol`, `AuthServiceProtocol`,
`ListingServiceProtocol`, and `BookingServiceProtocol` are the seams used for testing —
`DormFinderTests/Mocks/MockServices.swift` provides in-memory fakes that let view-model tests
run without touching the network or disk.

**Networking.** `NetworkService` wraps `URLSession` with async/await, decodes
snake_case JSON into camelCase `Codable` models (custom `JSONDecoder`/`JSONEncoder` with
ISO-8601 date handling), maps HTTP status codes to a typed `NetworkError`, and calls an
injected `unauthorizedHandler` on 401 so the app can sign the user out centrally.

**Offline-first persistence (CoreData).** See [Key design decisions](#key-design-decisions)
below for the full sync/conflict-resolution story — the short version is that `SyncManager`
is the single gateway between the UI and both the network and CoreData; views and view models
never talk to `NSManagedObjectContext` directly.

**Accessibility.** Views use Dynamic Type-friendly system fonts (`.headline`, `.body`, etc.),
SF Symbols with `Label`, `accessibilityElement(children: .combine)` to group related content
into single VoiceOver announcements, descriptive `accessibilityLabel`/`accessibilityHint`s, and
adaptive layouts (`LazyVGrid` column counts driven by `horizontalSizeClass`) so the UI holds up
across iPhone sizes and orientations.

### Setting up the Xcode project

This repo ships the full Swift source tree and a CoreData model, but not a generated
`.xcodeproj` (those are large, brittle XML files that don't review well as text). To open it
in Xcode:

1. **File ▸ New ▸ Project ▸ iOS ▸ App.**
   - Product Name: `DormFinder`
   - Interface: SwiftUI, Language: Swift
   - Uncheck "Use Core Data" (we bring our own `.xcdatamodeld`) and "Include Tests" if prompted
     — we'll add the test targets manually in the next step.
2. Delete the generated `ContentView.swift` and the placeholder `DormFinderApp.swift`.
3. Drag the `DormFinder/` folder from this repo into the project navigator
   ("Copy items if needed", create groups, add to the `DormFinder` target).
4. Add two test targets: **File ▸ New ▸ Target ▸ Unit Testing Bundle** named `DormFinderTests`,
   and **UI Testing Bundle** named `DormFinderUITests`. Drag in the corresponding folders from
   this repo and add them to their respective targets (enable "Testing Host Application" →
   `DormFinder` for the unit test target).
5. Select the `Model.xcdatamodeld` in the navigator and confirm its target membership includes
   `DormFinder`.
6. In **Signing & Capabilities**, set your team and bundle identifier.
7. Update `AppEnvironment.apiBaseURL` (in `App/AppEnvironment.swift`) to point at your backend
   — by default it's `https://api.dormfinder.app/v1`; for local development against the bundled
   FastAPI service this is typically `http://127.0.0.1:8000/v1`.

> Minimum deployment target: **iOS 17** (uses the new `Map`/`MapCameraPosition` MapKit APIs
> and Swift Concurrency throughout). If you need to support iOS 16, swap `Map` for
> `MapKit.Map` with `MKCoordinateRegion` bindings and replace `ContentUnavailableView` usages
> (already abstracted behind `ContentUnavailableMessage`).

### Running the app

1. Start the backend (see [Backend setup](#backend-setup)) or point `apiBaseURL` at a staging
   server.
2. Build & run on a simulator or device (⌘R). The app launches into the auth screen; sign up
   with any email/password (8+ characters) to create an account against your backend.
3. Turn on Airplane Mode after browsing listings once — the cached results remain visible,
   "My Bookings" still works for cached reservations, and any new booking you create is queued
   and synced automatically the moment connectivity returns (`SyncManager` observes
   `NetworkMonitor.$isConnected`).

### Tests

- **Unit tests** (`DormFinderTests`):
  - `AuthViewModelTests` — form validation, login/signup success & failure state transitions.
  - `ListingListViewModelTests` — cache-first loading and reactive filter/search behavior.
  - `NetworkServiceTests` — JSON decoding (snake_case ↔ camelCase, ISO-8601 dates), encoding,
    and HTTP status → `NetworkError` mapping using a stubbed `URLProtocol`.
  - `SyncManagerTests` — the offline queueing and last-write-wins conflict-resolution merge
    logic against an in-memory CoreData stack.
- **UI tests** (`DormFinderUITests`):
  - `BookingFlowUITests.test_loginBrowseAndBookListing_appearsInMyBookings` drives the full
    booking journey (log in → browse → open detail → request booking → confirm → verify in
    My Bookings) against deterministic in-memory fixtures, activated via the `UI-TESTING`
    launch argument (see `UITestingSupport.swift`).

Run all tests with **⌘U**, or from the command line:

```sh
xcodebuild test -scheme DormFinder -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Backend

A lightweight FastAPI + PostgreSQL service exposing the REST endpoints the iOS app expects:
listings, bookings, and JWT-based auth (access + refresh tokens). It's optional — the iOS app
only needs *some* server implementing this contract — but it makes the project runnable
end to end.

### Backend setup

Requires Python 3.11+ and a running PostgreSQL instance.

```sh
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

createdb dormfinder              # or use Docker: see below
cp .env.example .env             # then edit JWT_SECRET_KEY, DATABASE_URL, etc.

python seed.py                   # populates a few sample listings
uvicorn app.main:app --reload    # serves on http://127.0.0.1:8000
```

Or with Docker for Postgres only:

```sh
docker run --name dormfinder-db -e POSTGRES_USER=dormfinder -e POSTGRES_PASSWORD=dormfinder \
  -e POSTGRES_DB=dormfinder -p 5432:5432 -d postgres:16
```

Open `http://127.0.0.1:8000/docs` for interactive OpenAPI docs.

> The schema is created automatically on startup via `Base.metadata.create_all` for local
> development convenience. For production, manage migrations with **Alembic**
> (`alembic.ini`/`migrations/` would live alongside `app/`) instead of relying on this.

### Endpoints

All routes are prefixed with `/v1` to match `AppEnvironment.apiBaseURL`.

| Method | Path                | Auth | Description                                 |
|--------|---------------------|------|---------------------------------------------|
| POST   | `/auth/signup`      | No   | Create an account, returns `AuthOut` (JWTs) |
| POST   | `/auth/login`       | No   | Exchange credentials for `AuthOut`          |
| POST   | `/auth/refresh`     | No   | Exchange a refresh token for new JWTs       |
| GET    | `/listings`         | No   | Paginated listing search (`page`, `lat`, `lng`) |
| GET    | `/listings/{id}`    | No   | Listing detail                              |
| GET    | `/bookings`         | Yes  | Current user's reservations                 |
| POST   | `/bookings`         | Yes  | Create a booking (computes price server-side) |
| DELETE | `/bookings/{id}`    | Yes  | Cancel a booking (soft cancel, bumps `version`) |

Bearer tokens go in `Authorization: Bearer <access_token>`. A `401` response from any
authenticated endpoint is what triggers `AuthService`'s token refresh / sign-out flow on
the client.

---

## Key design decisions

### Offline-first sync & conflict resolution

`SyncManager` (in `Persistence/SyncManager.swift`) is the single gateway between the UI and
both the network and CoreData — view models never touch `NSManagedObjectContext` directly.

- **Listings are read-through cached.** Every successful fetch writes results into
  `CachedListing` rows; `ListingListViewModel` always reads from the cache first (so the UI
  populates instantly on relaunch) and reconciles with a network refresh, falling back
  silently to cached data when offline.
- **Bookings are read/write and offline-capable.** Creating or cancelling a booking writes
  to CoreData immediately (optimistic UI, e.g. a `pendingCreate` row with a temporary
  `local-<uuid>` id) and is pushed to the server right away if connectivity allows; otherwise
  it's queued with a `syncState` (`pendingCreate` / `pendingUpdate` / `pendingDelete`) and
  flushed by `syncPendingBookings()` — which `SyncManager` triggers automatically the instant
  `NetworkMonitor` reports the device coming back online (via a Combine subscription on
  `$isConnected`).
- **Conflict resolution is last-write-wins by server-assigned `version`.** Every `Booking`
  carries a monotonically-increasing `version` bumped by the backend on each mutation
  (see `models.py`/`bookings.py`). When merging a remote booking into a row that has unsynced
  local edits (`pendingUpdate`), the server's copy wins outright if its `version` is `>=` the
  local row's — the server is the authority on status transitions a client can't predict
  (e.g. a host confirming a booking). If the local row's version is ahead, the local edit is
  preserved and retried on the next sync pass. This keeps the policy simple, deterministic,
  and free of merge UI — appropriate for a booking status field where "the latest server state
  wins" is the right default.

### Why a composition root instead of a DI framework

`AppEnvironment` wires every dependency by hand in one place. For an app this size that's more
legible than a DI container, and it's the mechanism that makes three different configurations
trivial to express: production (`AppEnvironment()`), SwiftUI previews (`AppEnvironment.preview()`,
in-memory CoreData), and UI tests (`UI-TESTING` launch argument → `UITestingSupport.swift`
fixtures, also in-memory). Nothing about the views or view models changes between these.

### Why JWTs live in the Keychain, not UserDefaults

`Session` (access token, refresh token, expiry, user id) is persisted via `KeychainService`
as a single encrypted item with `kSecAttrAccessibleAfterFirstUnlock`, so a stolen/jailbroken
device at rest can't read tokens out of a plist, but the app can still refresh sessions in the
background after the user unlocks their phone once post-reboot.
