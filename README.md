# Basobaas Map

Basobaas Map is a comprehensive Flutter-based mobile application designed to simplify the rental process in Nepal. It bridges the gap between landlords and tenants by offering a map-centric interface for finding and posting rental properties. Whether you are looking for a room, a flat, or a hostel, or you are a landlord wanting to list your property, Basobaas Map provides the tools you need.

## Features

### For Tenants (Seekers)
*   **Interactive Map Search:** Visualize rental properties on an interactive map using `flutter_map`. Markers are color-coded to indicate status (Green: Vacant, Orange: To Be Vacant, Red: Rented).
*   **Advanced Filtering:** Narrow down your search with powerful filters:
    *   **Property Type:** Room, Flat, Hostel.
    *   **Price Range:** Set minimum and maximum budget.
    *   **Location:** Search by city, street, or landmarks using fuzzy search.
    *   **Dates:** Filter by availability (start and end dates).
    *   **Amenities:** Filter for specific needs like WiFi, Parking, Kitchen, Water Supply, etc.
*   **Detailed Listings:** View comprehensive property details including:
    *   High-quality image galleries with fullscreen viewing.
    *   Price, deposit, and negotiation status.
    *   Detailed descriptions and rules.
    *   List of amenities and nearby landmarks.
*   **Saved Rentals:** Bookmark properties to your "Saved Rentals" list for easy access later.
*   **Direct Contact:** Contact landlords directly via phone or social media links provided in the app.

### For Landlords (Owners)
*   **Easy Posting:** Create detailed rental listings with:
    *   Multiple photo uploads (stored securely via Supabase).
    *   Precise map location picking.
    *   Detailed attributes (price, type, amenities, rules).
*   **Listing Management:**
    *   **Edit Posts:** Update details and photos of your properties.
    *   **Status Management:** easily toggle property status between "Vacant", "To Be Vacant", and "Rented".
    *   **Automated Status:** "To Be Vacant" properties automatically switch to "Vacant" when the available date arrives.
*   **Verification:** A mandatory email verification process ensures trust and security within the platform.

## Architecture

The project is built using a clean and scalable **Provider** pattern architecture.

*   **`lib/main.dart`**: The application entry point. It handles the initialization of critical services like Firebase, Supabase, and dependency injection via `MultiProvider`.
*   **`lib/pages/`**: Organized by feature sets:
    *   **`base_page.dart`**: Manages the persistent bottom navigation bar.
    *   **`home_page.dart`**: Displays a feed of latest and filtered rental listings.
    *   **`map_page.dart`**: The core map interface for exploring rentals geographically.
    *   **`post_page.dart`**: The form interface for submitting new rentals.
    *   **`login/`**: Handles authentication flows (Login, Register, Forgot Password).
    *   **`profile/`**: User settings, profile editing, contact info management, and listing management (Active Listings, Saved Rentals).
*   **`lib/provider/`**: Business logic and state management:
    *   **`auth_provider.dart`**: Manages user session, Firebase Auth interactions (Email/Password, Google), and user profile data (Firestore).
    *   **`post_provider.dart`**: The powerhouse for rental data. It handles fetching listings, executing complex filters, real-time map marker updates, and CRUD operations for posts using Firestore and Supabase Storage.
*   **`lib/shared_widgets/`**: Reusable UI components like `PostCard`, `RoomCard`, `AdvancedFilterDrawer`, and `ContactSection` to maintain UI consistency.

## Tech Stack

*   **Frontend Framework:** [Flutter](https://flutter.dev/) (SDK ^3.8.1)
*   **Authentication:** [Firebase Authentication](https://firebase.google.com/products/auth) (Email/Password & Google Sign-In)
*   **Database:** [Cloud Firestore](https://firebase.google.com/products/firestore) (NoSQL database for user data and rental listings)
*   **Storage:** [Supabase Storage](https://supabase.com/storage) (Scalable object storage for user avatars and rental property images)
*   **Maps:** [`flutter_map`](https://pub.dev/packages/flutter_map) with [`latlong2`](https://pub.dev/packages/latlong2) for rendering OpenStreetMap data.
*   **State Management:** [`provider`](https://pub.dev/packages/provider)
*   **Key Libraries:**
    *   `fuzzywuzzy`: For intelligent text searching.
    *   `image_picker`: For device camera and gallery access.
    *   `google_sign_in`: For native Google authentication flow.
    *   `geocoding` & `geolocator`: For location services.
    *   `shared_preferences` & `persistent_bottom_nav_bar`: For local state and navigation.
    *   `lottie` & `animated_text_kit`: For engaging UI animations.

## Getting Started

### Prerequisites

1.  **Flutter SDK:** Ensure you have Flutter installed and configured.
2.  **Firebase Project:**
    *   Create a Firebase project.
    *   Enable **Authentication** (Email/Password, Google).
    *   Enable **Cloud Firestore**.
    *   Download `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) and place them in `android/app/` and `ios/Runner/` respectively.
3.  **Supabase Project:**
    *   Create a Supabase project.
    *   Create a storage bucket named `rental-images` and `user-avatars`.
    *   Configure RLS (Row Level Security) policies to allow public reads and authenticated uploads.

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/basobaas_map.git
    cd basobaas_map
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Environment Configuration:**
    *   Open `lib/main.dart`.
    *   Replace the `url` and `anonKey` in `Supabase.initialize` with your project's credentials.
    *   Replace the `supabaseUrl` and `supabaseKey` in the `SupabaseClient` instantiation (used for storage operations).

4.  **Run the application:**
    ```bash
    flutter run
    ```
