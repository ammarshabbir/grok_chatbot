# grokchatbot

Run the app with your xAI key passed at build time instead of committing it:

```bash
flutter run --dart-define=XAI_API_KEY=your_xai_api_key
```

For release builds, pass the same `--dart-define` value to `flutter build`.
