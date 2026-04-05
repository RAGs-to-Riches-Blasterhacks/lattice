# Lattice

A skill-building app where an LLM agent creates personalized learning plans with git-like plan branching.

## Local Development

### Backend

```bash
cd Backend/FastAPI
pip install -r requirements.txt
cp .env.example .env   # fill in your credentials
uvicorn main:app --reload
```

Health check: `GET http://localhost:8000/health`

### Frontend

```bash
cd Frontend/Flutter
flutter pub get
flutter run --dart-define=FIREBASE_API_KEY=<your-firebase-web-api-key>
```

By default the app connects to `http://127.0.0.1:8000/api`. The `FIREBASE_API_KEY` enables automatic token refresh — without it the app still works but users will need to re-login after 1 hour.

## Deploying to Railway (Backend)

### 1. Install the Railway CLI

```bash
npm install -g @railway/cli
railway login
```

### 2. Link your project

```bash
cd Backend/FastAPI
railway link
```

Select your project and environment when prompted.

### 3. Set environment variables

In the Railway dashboard (or via `railway variables set`), add:

| Variable | Description |
|----------|-------------|
| `MONGO_URI` | MongoDB Atlas connection string |
| `MONGO_DB_NAME` | Database name (e.g. `lattice`) |
| `FIREBASE_CREDENTIALS_JSON` | Entire contents of your `firebase-service-account.json` as a single string |
| `FIREBASE_API_KEY` | Firebase Web API key |
| `OPENAI_API_KEY` | OpenAI API key (used by the ADK agents via LiteLLM) |
| `GOOGLE_API_KEY` | Google API key (YouTube, Books, Custom Search) |
| `GOOGLE_CSE_ID` | Google Custom Search Engine ID |
| `EVENTBRITE_TOKEN` | Eventbrite private OAuth token |
| `ALLOWED_ORIGINS` | Comma-separated allowed origins for CORS (optional, not needed for mobile-only) |

### 4. Deploy

```bash
railway up
```

Or connect your GitHub repo in the Railway dashboard for automatic deploys on push.

### 5. Verify

```bash
curl https://<your-app>.railway.app/health
# → {"status":"ok"}
```

Note your Railway URL — you'll need it for the APK build.

## Building the APK

### 1. Prerequisites

- Flutter SDK installed
- Android SDK with build-tools
- Java 17+

### 2. Build

```bash
cd Frontend/Flutter
flutter build apk --release \
  --dart-define=API_URL=https://<your-app>.railway.app/api \
  --dart-define=FIREBASE_API_KEY=<your-firebase-web-api-key>
```

Replace `<your-app>.railway.app` with your actual Railway domain and `<your-firebase-web-api-key>` with your Firebase Web API key (found in the Firebase Console under Project Settings → General). The API key is required for automatic token refresh — without it, users will be logged out after 1 hour when their Firebase ID token expires.

### 3. Find the APK

```
build/app/outputs/flutter-apk/app-release.apk
```

Share this file directly — users install it by opening the `.apk` on their Android device (they'll need to allow "Install from unknown sources").

## Flutter Auth Integration

The auth flow:

1. Call `/api/auth/login` (or `/register`, `/oauth`) — get back `id_token`, `refresh_token`, and `custom_token`
2. Token is stored in encrypted secure storage (Android Keystore / iOS Keychain)
3. `Authorization: Bearer <id_token>` is attached to every subsequent API call
4. When the `id_token` expires (1 hour), use the `refresh_token` to get a new one via the Firebase REST API (`securetoken.googleapis.com/v1/token?key=<API_KEY>`)

## Environment Variables Reference

See `Backend/FastAPI/.env.example` for the full list of required variables.