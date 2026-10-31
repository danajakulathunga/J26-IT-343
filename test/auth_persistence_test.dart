import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/core/storage/storage_service.dart';
import 'package:bananaguard_ai/models/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await storageService.init();
  });

  group('StorageService Persistent Authentication Tests', () {
    test('Tokens are persisted and cleared appropriately', () async {
      await storageService.saveTokens(
        accessToken: 'access_abc_123',
        refreshToken: 'refresh_xyz_789',
      );

      final access = await storageService.getAccessToken();
      final refresh = await storageService.getRefreshToken();

      expect(access, 'access_abc_123');
      expect(refresh, 'refresh_xyz_789');

      await storageService.clearTokens();

      final accessAfter = await storageService.getAccessToken();
      final refreshAfter = await storageService.getRefreshToken();

      expect(accessAfter, isNull);
      expect(refreshAfter, isNull);
    });

    test('User profile is securely persisted and restored on subsequent launches', () async {
      final user = UserModel(
        id: 'user_456',
        email: 'grower@bananaguard.ai',
        fullName: 'Kamal Perera',
        preferredLanguage: 'si',
        isGuest: false,
      );

      await storageService.saveUser(user);

      final restored = await storageService.getSavedUser();
      expect(restored, isNotNull);
      expect(restored!.id, 'user_456');
      expect(restored.email, 'grower@bananaguard.ai');
      expect(restored.fullName, 'Kamal Perera');
      expect(restored.preferredLanguage, 'si');
      expect(restored.isGuest, isFalse);

      await storageService.clearUser();
      final cleared = await storageService.getSavedUser();
      expect(cleared, isNull);
    });

    test('Free Using state and guest display name are persisted across app closures', () async {
      expect(storageService.isFreeUsing(), isFalse);

      await storageService.setGuestName('Sunil Shantha');
      await storageService.setFreeUsing(true);

      // Verify state survived
      expect(storageService.isFreeUsing(), isTrue);
      expect(storageService.getGuestName(), 'Sunil Shantha');

      final guestId = storageService.getOrCreateGuestId();
      expect(guestId, isNotEmpty);

      // Reopening check
      expect(storageService.getOrCreateGuestId(), guestId); // Same persistent guestId

      // User explicitly exits guest session
      await storageService.clearGuest();
      expect(storageService.isFreeUsing(), isFalse);
      expect(storageService.getGuestName(), isNull);
    });

    test('clearAllSession performs complete wipe for explicit sign-out', () async {
      await storageService.saveTokens(accessToken: 'token1', refreshToken: 'token2');
      await storageService.saveUser(UserModel(id: 'u1', email: 'e', fullName: 'f', preferredLanguage: 'en'));
      await storageService.setGuestName('GuestUser');
      await storageService.setFreeUsing(true);

      // Explicit logout
      await storageService.clearAllSession();

      expect(await storageService.getAccessToken(), isNull);
      expect(await storageService.getRefreshToken(), isNull);
      expect(await storageService.getSavedUser(), isNull);
      expect(storageService.isFreeUsing(), isFalse);
      expect(storageService.getGuestName(), isNull);
    });

    test('Custom server URL (including trycloudflare.com tunnel) persists permanently across restarts and sessions', () async {
      const tunnelUrl = 'https://research-banana-tunnel.trycloudflare.com';
      await storageService.setCustomServerUrl(tunnelUrl);

      // Verify stored in storageService
      expect(storageService.getCustomServerUrl(), tunnelUrl);

      // Verify AppConstants.defaultApiBaseUrl returns it and does NOT auto-clear it
      expect(AppConstants.defaultApiBaseUrl, tunnelUrl);
      expect(storageService.getCustomServerUrl(), tunnelUrl);

      // Verify session logout preserves server configuration
      await storageService.clearAllSession();
      expect(AppConstants.defaultApiBaseUrl, tunnelUrl);
      expect(storageService.getCustomServerUrl(), tunnelUrl);
    });
  });
}
