/// Shared initialization state accessible across the app.
/// Used to signal when background services (Hive, Supabase, etc.) are ready.
class AppInitState {
  AppInitState._();

  static bool servicesReady = false;
}
