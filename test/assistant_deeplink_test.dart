import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Google Assistant & Next.js Deep Link Route Parsing Tests', () {
    test('Verifies custom scheme manikutti://voice-dialog with query parameter', () {
      final uri = Uri.parse('manikutti://voice-dialog?query=200%20for%20petrol');
      final isVoice = uri.host == 'voice-expense' ||
          uri.host == 'voice-dialog' ||
          (uri.host == 'manikutti.vercel.app' &&
              (uri.path.contains('voice-dialog') ||
                  uri.path.contains('voice-expense')));

      expect(isVoice, isTrue);
      expect(uri.queryParameters['query'], '200 for petrol');
    });

    test('Verifies HTTPS Next.js deep link https://manikutti.vercel.app/voice-dialog', () {
      final uri = Uri.parse('https://manikutti.vercel.app/voice-dialog?query=100%20tea');
      final isVoice = uri.host == 'voice-expense' ||
          uri.host == 'voice-dialog' ||
          (uri.host == 'manikutti.vercel.app' &&
              (uri.path.contains('voice-dialog') ||
                  uri.path.contains('voice-expense')));

      expect(isVoice, isTrue);
      expect(uri.queryParameters['query'], '100 tea');
    });

    test('Verifies HTTPS Next.js alias https://manikutti.vercel.app/voice-expense', () {
      final uri = Uri.parse('https://manikutti.vercel.app/voice-expense');
      final isVoice = uri.host == 'voice-expense' ||
          uri.host == 'voice-dialog' ||
          (uri.host == 'manikutti.vercel.app' &&
              (uri.path.contains('voice-dialog') ||
                  uri.path.contains('voice-expense')));

      expect(isVoice, isTrue);
      expect(uri.queryParameters['query'], isNull);
    });

    test('Verifies HTTPS Next.js add transaction link https://manikutti.vercel.app/add-transaction', () {
      final uri = Uri.parse('https://manikutti.vercel.app/add-transaction');
      final isAdd = uri.host == 'add-transaction' ||
          (uri.host == 'manikutti.vercel.app' &&
              uri.path.contains('add-transaction'));

      expect(isAdd, isTrue);
    });

    test('Verifies Android Intent URI construction for Google Assistant Routines', () {
      const query = '50 auto';
      final intentUrl = 'intent://voice-dialog?query=${Uri.encodeComponent(query)}#Intent;scheme=manikutti;package=com.abhilash.manikutti;end';
      
      expect(intentUrl, contains('scheme=manikutti'));
      expect(intentUrl, contains('package=com.abhilash.manikutti'));
      expect(intentUrl, contains('query=50%20auto'));
    });
  });
}
