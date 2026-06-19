# Heart Alert – Flutter App

## Project Structure

```
heart_alert/
├── lib/
│   ├── main.dart                  ← App entry point
│   ├── theme/
│   │   └── app_theme.dart         ← Colors, text styles, theme
│   ├── utils/
│   │   └── app_routes.dart        ← All named routes (add screens here)
│   ├── screens/
│   │   └── intro_screen.dart      ← Intro animation screen ✅
│   │   └── home_screen.dart       ← (coming soon)
│   └── widgets/
│       └── (shared widgets go here)
├── assets/
│   ├── images/                    ← Put image assets here
│   └── icons/                     ← Put icon assets here
└── pubspec.yaml
```

## Getting Started

```bash
cd heart_alert
flutter pub get
flutter run
```

## Color Palette
| Name        | Hex         |
|-------------|-------------|
| Cream       | `#F5F0E8`   |
| Black       | `#1A1A1A`   |
| Sage Green  | `#7A9E7E`   |
| Sage Light  | `#A8C5A0`   |
| Sage Dark   | `#4E7252`   |

## Adding a New Screen
1. Create `lib/screens/your_screen.dart`
2. Add route in `lib/utils/app_routes.dart`
3. Uncomment the `Navigator.pushReplacementNamed(...)` in `intro_screen.dart`
