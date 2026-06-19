enum Flavor { development, production }

class AppConfig {
  static Flavor flavor = Flavor.production;

  static String get baseUrl {
    switch (flavor) {
      case Flavor.development:
        return 'http://10.0.2.2:8000'; // emulator
      case Flavor.production:
        return 'https://heart-alert-api.onrender.com'; // your real IP
    }
  }
}