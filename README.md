# lattice
Grigliator


### Backend dev

To run the backend run: ```bash uvicorn main:app --reload```


### Flutter Auth integration:

From Flutter the only auth-related thing you send on every request is the id_token as a Bearer header:

  Authorization: Bearer <id_token>

  The Flutter flow is:
  1. Call /api/auth/login (or register/oauth) — get back id_token, refresh_token, and custom_token
  2. Store the id_token and refresh_token locally (secure storage)
  3. Attach Authorization: Bearer <id_token> to every subsequent API call
  4. When the id_token expires (1 hour), use the refresh_token to get a new one via the Firebase REST API
  (securetoken.googleapis.com/v1/token?key=<API_KEY>)

  Alternatively, if you use the Firebase Flutter SDK, you can call signInWithCustomToken(custom_token) and let the SDK handle token refresh
  automatically — then just grab the current ID token with user.getIdToken() before each request.