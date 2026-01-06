import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilovepdf_flutter/services/favorites_service.dart';

void main() {
  group('FavoritesService', () {
    late FavoritesService service;

    setUp(() async {
      // Initialize SharedPreferences with empty values for testing
      SharedPreferences.setMockInitialValues({});
      service = FavoritesService();
      // Wait for async initialization to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    group('initialization', () {
      test('starts with empty favorites', () {
        expect(service.favorites.isEmpty, true);
      });

      test('loads saved favorites on init', () async {
        // Set up mock with saved favorites
        SharedPreferences.setMockInitialValues({
          'favorite_tools': '["merge","compress"]',
        });
        
        final loadedService = FavoritesService();
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(loadedService.favorites.contains('merge'), true);
        expect(loadedService.favorites.contains('compress'), true);
      });
    });

    group('isFavorite', () {
      test('returns false for non-favorited tool', () {
        expect(service.isFavorite('merge'), false);
      });

      test('returns true after adding favorite', () async {
        await service.addFavorite('merge');
        expect(service.isFavorite('merge'), true);
      });
    });

    group('addFavorite', () {
      test('adds tool to favorites', () async {
        await service.addFavorite('compress');
        expect(service.favorites.contains('compress'), true);
      });

      test('does not add duplicate favorites', () async {
        await service.addFavorite('compress');
        await service.addFavorite('compress');
        expect(service.favorites.where((f) => f == 'compress').length, 1);
      });

      test('can add multiple different favorites', () async {
        await service.addFavorite('merge');
        await service.addFavorite('split');
        await service.addFavorite('compress');
        
        expect(service.favorites.length, 3);
        expect(service.favorites.contains('merge'), true);
        expect(service.favorites.contains('split'), true);
        expect(service.favorites.contains('compress'), true);
      });
    });

    group('removeFavorite', () {
      test('removes tool from favorites', () async {
        await service.addFavorite('merge');
        await service.removeFavorite('merge');
        expect(service.favorites.contains('merge'), false);
      });

      test('does nothing when removing non-existent favorite', () async {
        await service.addFavorite('merge');
        await service.removeFavorite('compress'); // not in favorites
        expect(service.favorites.length, 1);
        expect(service.favorites.contains('merge'), true);
      });
    });

    group('toggleFavorite', () {
      test('adds favorite if not present', () async {
        expect(service.isFavorite('merge'), false);
        await service.toggleFavorite('merge');
        expect(service.isFavorite('merge'), true);
      });

      test('removes favorite if present', () async {
        await service.addFavorite('merge');
        expect(service.isFavorite('merge'), true);
        await service.toggleFavorite('merge');
        expect(service.isFavorite('merge'), false);
      });

      test('toggle twice returns to original state', () async {
        expect(service.isFavorite('merge'), false);
        await service.toggleFavorite('merge'); // true
        await service.toggleFavorite('merge'); // false
        expect(service.isFavorite('merge'), false);
      });
    });

    group('clearFavorites', () {
      test('removes all favorites', () async {
        await service.addFavorite('merge');
        await service.addFavorite('split');
        await service.addFavorite('compress');
        
        expect(service.favorites.length, 3);
        
        await service.clearFavorites();
        
        expect(service.favorites.isEmpty, true);
      });

      test('clearing empty favorites does not throw', () async {
        expect(service.favorites.isEmpty, true);
        await service.clearFavorites();
        expect(service.favorites.isEmpty, true);
      });
    });

    group('persistence', () {
      test('favorites persist across service instances', () async {
        SharedPreferences.setMockInitialValues({});
        
        // First service instance - add favorites
        final service1 = FavoritesService();
        await Future.delayed(const Duration(milliseconds: 100));
        await service1.addFavorite('merge');
        await service1.addFavorite('compress');
        
        // Get saved prefs
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('favorite_tools');
        expect(saved, isNotNull);
        
        // Second service instance with same prefs
        SharedPreferences.setMockInitialValues({
          'favorite_tools': saved!,
        });
        
        final service2 = FavoritesService();
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(service2.favorites.contains('merge'), true);
        expect(service2.favorites.contains('compress'), true);
      });
    });

    group('favorites getter', () {
      test('returns unmodifiable set', () async {
        await service.addFavorite('merge');
        final favorites = service.favorites;
        
        // Trying to modify should throw
        expect(() => favorites.add('split'), throwsUnsupportedError);
      });
    });
  });
}
