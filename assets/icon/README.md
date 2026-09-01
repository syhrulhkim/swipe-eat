# App icon sources

Drop two PNGs here, then run `dart run flutter_launcher_icons` from the repo
root. That rewrites every Android mipmap and the iOS `AppIcon.appiconset`, so
the generated files are committed output — edit these sources, never the
generated ones.

| File | Size | Alpha | Notes |
| --- | --- | --- | --- |
| `app_icon.png` | 1024×1024 | **must have none** | The App Store icon and the base for every generated size. Apple rejects a transparent or semi-transparent icon, and adds the rounded corners itself — ship a full-bleed square. |
| `app_icon_fg.png` | 1024×1024 | required | Android adaptive-icon foreground. Keep the artwork inside the centre ~66% (about 690×690); anything outside can be cropped by the launcher's mask. The background is the flat `#16150F` set in `pubspec.yaml`. |

Both are referenced from the `flutter_launcher_icons` block in
`pubspec.yaml`. `docs/store-release.md` lists the rest of the store assets.
