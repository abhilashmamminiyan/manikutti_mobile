import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReleaseHighlight {
  final String title;
  final String description;
  final String iconName;

  const ReleaseHighlight({
    required this.title,
    required this.description,
    required this.iconName,
  });
}

class AppReleaseNote {
  final String version;
  final String title;
  final String releaseDate;
  final List<ReleaseHighlight> highlights;

  const AppReleaseNote({
    required this.version,
    required this.title,
    required this.releaseDate,
    required this.highlights,
  });
}

class WhatsNewService {
  static final WhatsNewService instance = WhatsNewService._internal();
  WhatsNewService._internal();

  static const String currentVersion = '2.2.1';
  static const String _prefKeyLastSeenVersion = 'last_seen_release_version';

  final ValueNotifier<bool> hasUnreadNotifier = ValueNotifier<bool>(false);

  final List<AppReleaseNote> releases = const [
    AppReleaseNote(
      version: '2.2.1',
      title: 'Voice Logging, Home Widget & Quick Shortcuts',
      releaseDate: 'October 2026',
      highlights: [
        ReleaseHighlight(
          title: 'Smart Voice Expense Logging',
          description:
              'Speak your daily expenses naturally in Malayalam, Manglish, or English without typing a single digit.',
          iconName: 'mic',
        ),
        ReleaseHighlight(
          title: 'Home Screen Expense Widget',
          description:
              'Place a real-time expense and bill reminder widget on your phone screen with instant 1-tap voice recording.',
          iconName: 'widgets',
        ),
        ReleaseHighlight(
          title: 'Google Assistant & Quick Settings',
          description:
              'Say "Hey Google, log expense on Manikutti" or tap the notification shade tile from any screen or lock screen.',
          iconName: 'assistant',
        ),
        ReleaseHighlight(
          title: 'Bank Statement Importer (PDF & CSV)',
          description:
              'Directly import your monthly bank statements from SBI, Canara Bank, and others with automatic duplicate protection.',
          iconName: 'statement',
        ),
      ],
    ),
    AppReleaseNote(
      version: '2.1.0',
      title: 'Biometric Security & Family Ledger Upgrades',
      releaseDate: 'September 2026',
      highlights: [
        ReleaseHighlight(
          title: 'Biometric Fingerprint & Face Unlock',
          description:
              'Secure your sensitive financial records with your phone’s biometric sensor and custom 4-digit PIN.',
          iconName: 'security',
        ),
        ReleaseHighlight(
          title: 'Family Shared Expenses & EMIs',
          description:
              'Collaborate on household spending, loan EMIs, and monthly recharge reminders with your family.',
          iconName: 'family',
        ),
        ReleaseHighlight(
          title: 'Dynamic Dark Mode & Malayalam Support',
          description:
              'Full Malayalam localization and dark mode designed for eye comfort and battery savings.',
          iconName: 'palette',
        ),
      ],
    ),
  ];

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString(_prefKeyLastSeenVersion) ?? '';
      hasUnreadNotifier.value = (lastSeen != currentVersion);
    } catch (_) {
      hasUnreadNotifier.value = false;
    }
  }

  Future<void> markAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyLastSeenVersion, currentVersion);
      hasUnreadNotifier.value = false;
    } catch (_) {}
  }
}
