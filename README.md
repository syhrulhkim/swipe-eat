# Swipe Eat Mobile Starter

This repo now contains a Flutter starter app with:

- Forui as the main UI system
- Login, register, and dashboard screens
- Laravel-friendly auth plumbing using bearer tokens
- Auth persistence with `flutter_secure_storage`

## Setup

1. Use the bundled Flutter SDK in `./flutter-sdk`.
2. If you want to use that SDK from this shell session, run:

```bash
export PATH="$PWD/flutter-sdk/bin:$PATH"
```

3. Run `flutter pub get`.
4. Start the app with a Laravel API URL:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

## Laravel contract

The app is ready for a Laravel API that exposes these endpoints:

- `POST /api/login`
- `POST /api/register`
- `GET /api/user`
- `POST /api/logout`

Expected auth response shape:

```json
{
  "token": "your-bearer-token",
  "user": {
    "id": 1,
    "name": "Jane Doe",
    "email": "jane@example.com"
  }
}
```

The app also accepts `access_token` as the token key and will fall back to `GET /api/user` if the user object is not included in the login or register response.

## Demo account

If you want to get into the dashboard immediately without a backend, use:

- Email: `demo@swipeeat.test`
- Password: `password`

This demo account is handled locally in the app and does not require Laravel.

## Notes

- The default API base URL is `http://10.0.2.2:8000/api`, which is convenient for the Android emulator talking to a Laravel app running on your machine.
- If you are testing on a physical device, point `API_BASE_URL` to your machine's LAN IP instead.
- The code is structured so you can extend the dashboard with real task data later without changing the auth flow.
