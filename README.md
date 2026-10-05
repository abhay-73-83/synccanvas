# SyncCanvas

SyncCanvas is a real-time collaborative digital whiteboard application built with **Flutter** and **Firebase**. It allows multiple users to join virtual rooms, collaborate on an infinite-feeling canvas using sticky notes, text cards, uploaded images, and interactive web links, and export their creations as high-resolution PNG images.

---

## 🚀 Features

- **User Onboarding & Identity**: Quick display name setup with anonymous Firebase Authentication.
- **Room Management**: Create rooms with custom names or join existing rooms using 6-character room codes.
- **Recent Rooms History**: Quick access to previously joined room codes stored locally, with auto-cleanup for deleted rooms.
- **Real-Time Shared Canvas**: Multi-user collaboration with synchronized canvas items over Cloud Firestore.
- **Rich Canvas Items**:
  - 📌 **Sticky Notes**: Color-coded notes (Yellow, Green, Blue, Pink) with inline rich text editing.
  - 📝 **Text Cards**: Clean text cards for headings and quick dynamic notes.
  - 🖼️ **Image Sharing**: Upload images from device gallery directly to Firebase Storage.
  - 🔗 **Link Cards**: Add web links with one-tap browser launching via `url_launcher`.
- **Interactive Drag & Reposition**: Fluid 60fps local dragging with persistent coordinate updates stored on drag release.
- **Edit & Delete Items**: Full CRUD operations for canvas elements across all connected devices.
- **Canvas Export & Sharing**: Render canvas content to high-DPI PNG images and share them instantly via native share dialogs.
- **Auto-Expire Rooms (24 Hours)**: Rooms automatically expire 24 hours after creation (`expireAt` timestamp in Firestore). Expired rooms block joining, show `"This room has expired."`, and auto-prune from Recent Rooms. RoomScreen displays a live remaining time indicator.
- **Robust Error Handling**: Real-time Firestore stream cleanup, safe mounted context checks, network status resilience, and offline handling.

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Dart SDK >=3.0.0)
- **State Management**: [Provider](https://pub.dev/packages/provider) (`ChangeNotifier`)
- **Backend & Cloud Services**:
  - **Firebase Authentication**: Anonymous Auth for seamless, zero-friction access
  - **Cloud Firestore**: Real-time database streams (`snapshots()`) for canvas state & active participant tracking
  - **Firebase Storage**: Cloud storage for uploaded canvas images
- **Local Storage**: [SharedPreferences](https://pub.dev/packages/shared_preferences) for user display name & recent rooms
- **Utilities**:
  - `image_picker` for media selection
  - `url_launcher` for external links
  - `share_plus` & `path_provider` for PNG export sharing

---

## 🏗️ Architecture

SyncCanvas follows a clean, decoupled layer architecture separating UI, Business Logic (Providers), Infrastructure (Services), and Data Models.

```
┌─────────────────────────────────────────────────────────┐
│                        UI Layer                         │
│       (Screens, Modal Dialogs, Custom Widgets)          │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                    Provider Layer                       │
│    (UserProvider, RoomProvider, CanvasProvider)         │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                     Service Layer                       │
│   (AuthService, FirestoreService, StorageService, etc)  │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                     Firebase & Local                    │
│   (Cloud Firestore, Firebase Auth, Storage, SharedPref) │
└────────────────────────────┬────────────────────────────┘
```

### Folder Structure

```
lib/
├── models/
│   ├── room.dart                 # Room data model with Firestore mapping & expireAt support
│   └── canvas_item.dart           # Canvas item model (note, text, image, link)
├── screens/
│   ├── onboarding_screen.dart    # First launch display name setup
│   ├── home_screen.dart          # Main dashboard & recent room history
│   ├── create_room_screen.dart   # Room creation screen
│   ├── join_room_screen.dart     # Room code input screen
│   └── room_screen.dart          # Interactive collaborative canvas screen
├── providers/
│   ├── user_provider.dart        # Auth state & display name management
│   ├── room_provider.dart        # Room creation, joining, expiration, & active state
│   └── canvas_provider.dart      # Real-time Firestore canvas stream listener
├── services/
│   ├── auth_service.dart         # Firebase Anonymous Auth wrapper
│   ├── firestore_service.dart    # Firestore CRUD operations & streams
│   ├── storage_service.dart      # SharedPreferences local persistence
│   ├── storage_upload_service.dart# Firebase Storage image uploader
│   └── export_service.dart       # RepaintBoundary PNG rendering & sharing
├── widgets/
│   ├── action_card.dart          # Dashboard action buttons
│   ├── recent_rooms_list.dart    # Recent rooms interactive list
│   ├── sticky_note.dart          # Sticky note widget with color themes
│   ├── text_card.dart            # Minimalist text card widget
│   ├── image_card.dart           # Media image card widget
│   └── link_card.dart            # Web URL link card widget
└── utils/
    └── room_code_generator.dart  # 6-character unique code generator
```

---

## 📊 Firestore Data Structure

### `rooms/{roomCode}`
Document containing room metadata:

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Unique 6-character room code (e.g. `K9X2P7`) |
| `roomName` | `String` | User-defined room name |
| `roomCode` | `String` | Unique 6-character room code |
| `createdBy` | `String` | Creator's user ID |
| `createdByName` | `String` | Creator's display name |
| `createdAt` | `Timestamp` | Creation server timestamp |
| `expireAt` | `Timestamp` | Expiration timestamp (set to exactly 24 hours post-creation) |
| `participantCount` | `int` | Atomic counter tracking active room participants |

### `rooms/{roomCode}/canvasItems/{itemId}`
Subcollection representing elements placed on the canvas:

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Auto-generated Firestore document ID |
| `type` | `String` | Element type: `"note"`, `"text"`, `"image"`, or `"link"` |
| `content` | `String` | Note/text body, image download URL, or website URL |
| `color` | `int` | Color ARGB value (used for sticky note styling) |
| `x` | `double` | Canvas X-coordinate |
| `y` | `double` | Canvas Y-coordinate |
| `width` | `double` | Display width |
| `height` | `double` | Display height |
| `createdBy` | `String` | Display name of the author |
| `createdAt` | `Timestamp` | Item creation timestamp |
| `updatedAt` | `Timestamp` | Last modified timestamp |

---

## 📋 Features Implemented Checklist

- [x] **User Onboarding**: First launch display name prompt & state validation.
- [x] **Anonymous Firebase Auth**: Zero-login seamless setup.
- [x] **Create Room**: Generates unique non-ambiguous 6-character room codes.
- [x] **Join Room**: Uppercase code normalization & room validation.
- [x] **Recent Rooms**: Local caching of joined codes with invalid room auto-pruning.
- [x] **Shared Interactive Canvas**: Dynamic pan canvas supporting multiple item types.
- [x] **Sticky Notes**: 4 color palettes, edit dialog, & soft shadow design.
- [x] **Text Cards**: Clean cards for headings & plain text.
- [x] **Image Sharing**: Gallery image selection, Firebase Storage upload, & image cards.
- [x] **Link Sharing**: Web URL cards with link validation & one-tap launching.
- [x] **Drag & Reposition**: Smooth 60fps local drag with Firestore position updates on drop.
- [x] **Edit & Delete Items**: Modal dialog edits & Firestore deletion broadcasted real-time.
- [x] **Real-Time Synchronization**: Instant stream synchronization across multiple connected devices.
- [x] **Local Persistence**: Persistence for user preferences & active session state.
- [x] **PNG Canvas Export**: RepaintBoundary screenshot capture excluding UI headers/controls.
- [x] **Share Exported Canvas**: Native platform sheet sharing using `share_plus`.
- [x] **Network/Firebase Resilience**: Loading indicators, error banners, and non-blocking failure recovery.

---

## 💻 Setup Instructions

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.0.0 or higher)
- [Dart SDK](https://dart.dev/get-dart) (version 3.0.0 or higher)
- A Firebase project set up in the [Firebase Console](https://console.firebase.google.com/)

### Step-by-Step Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-username/synccanvas.git
   cd synccanvas
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Project Setup**
   - Create a new project in the [Firebase Console](https://console.firebase.google.com/).
   - **Authentication**: Enable **Anonymous** sign-in under *Authentication > Sign-in method*.
   - **Cloud Firestore**: Create a Firestore Database in production/test mode.
   - **Firebase Storage**: Enable Firebase Storage for image uploads.

4. **Add Firebase Configuration Files**
   - **Android**: Download `google-services.json` from your Firebase project settings and place it in `android/app/`.
   - **iOS**: Download `GoogleService-Info.plist` and place it in `ios/Runner/`.
   - Alternatively, use the [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) to configure Firebase automatically:
     ```bash
     flutterfire configure
     ```

5. **Run the Application**
   ```bash
   flutter run
   ```

---

## 🧪 Testing

### Automated Testing & Analysis
The project includes widget tests and static code analysis verification:

- **Run Static Analysis**:
  ```bash
  flutter analyze
  ```
  *Result*: Clean analysis with `0 issues found!`.

- **Run Unit & Widget Tests**:
  ```bash
  flutter test
  ```
  *Result*: All widget tests pass successfully.

### Manual Real-Time Testing Strategy
To verify multi-user real-time collaboration:
1. Launch app instance **User A** on an iOS Simulator / macOS desktop / physical device.
2. Launch app instance **User B** on an Android Emulator / physical device.
3. User A creates a room and shares the 6-character room code.
4. User B joins the room using the code.
5. Create, move, edit, and delete notes/cards on User A's device and observe instantaneous stream updates on User B's device.

---

## 💡 Assumptions & Design Decisions

1. **Optimized Drag Performance**: To prevent Firestore update throttling during drags, item positions update locally at 60fps while dragging and write to Firestore only when the user releases (`onPanEnd`).
2. **Deterministic Item Stacking**: Canvas items are ordered by `createdAt` ascending so all connected devices display identical z-index visual layering.
3. **Room Code Exclusions**: Generated 6-character room codes omit visually ambiguous characters (`0`, `O`, `1`, `I`, `L`) to prevent user entry confusion.
4. **Clean Canvas Export**: The PNG export targets only the actual canvas content via a scoped `RepaintBoundary`, cleanly excluding the top app bar, participant counters, and floating action buttons.

---

## 🖼️ Screenshots

| Home & Onboarding | Create & Join Room | Shared Canvas & Items | PNG Export |
|:---:|:---:|:---:|:---:|
| *(Screenshot Placeholder)* | *(Screenshot Placeholder)* | *(Screenshot Placeholder)* | *(Screenshot Placeholder)* |

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
