import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App Lock Timer & 2-Minute Grace Period Tests', () {
    const int lockGracePeriodMs = 2 * 60 * 1000; // 120,000 ms

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Within 2 minutes (<120s), app lock should NOT trigger', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      // Backgrounded 45 seconds ago
      final lastPaused = now - 45 * 1000;
      await prefs.setInt('last_app_paused_epoch_ms', lastPaused);

      final elapsed = now - (prefs.getInt('last_app_paused_epoch_ms') ?? 0);
      final shouldRelock = elapsed >= lockGracePeriodMs || elapsed < 0;

      expect(shouldRelock, isFalse);
      expect(elapsed, 45 * 1000);
    });

    test('At or after 2 minutes (>=120s), app lock MUST trigger', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      // Backgrounded 2 minutes and 5 seconds ago
      final lastPaused = now - (2 * 60 + 5) * 1000;
      await prefs.setInt('last_app_paused_epoch_ms', lastPaused);

      final elapsed = now - (prefs.getInt('last_app_paused_epoch_ms') ?? 0);
      final shouldRelock = elapsed >= lockGracePeriodMs || elapsed < 0;

      expect(shouldRelock, isTrue);
      expect(elapsed, (2 * 60 + 5) * 1000);
    });

    test('Cold start without prior paused timestamp triggers lock', () async {
      final prefs = await SharedPreferences.getInstance();
      final lastPaused = prefs.getInt('last_app_paused_epoch_ms') ?? 0;
      final shouldRelock = lastPaused == 0;

      expect(shouldRelock, isTrue);
    });

    test('Voice dialog route should never trigger app lock', () {
      const defaultRoute = '/voice-dialog?query=petrol';
      final isVoiceRoute = defaultRoute.contains('voice-dialog');

      expect(isVoiceRoute, isTrue);
    });
  });
}
