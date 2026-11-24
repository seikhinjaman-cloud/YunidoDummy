import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/address/models/google_places_model.dart';
import 'package:customer/features/address/repositories/address_repository.dart';
import 'package:geolocator/geolocator.dart';

/// Result of a live-location attempt.
enum LiveLocationOutcome {
  /// GPS not available (permission denied, service off, timeout, error).
  failed,

  /// Got a position, but it is basically where the saved location already is.
  unchanged,

  /// Got a position and saved it as the new user location.
  updated,
}

/// Reads the device's live location and stores it as the app's user location.
/// Falls back to [AppConfig] default location (Jadupur) when asked to.
class LiveLocationService {
  LiveLocationService._();

  /// Movement (in metres) below which the saved location is left as it is,
  /// so the home screen isn't reloaded for GPS jitter.
  static const double _minMoveMeters = 150;

  static bool _running = false;

  /// Tries to read the live location and save it.
  ///
  /// [requestPermission] — ask the user for permission if not decided yet.
  /// When false, it only works if permission was already granted (silent).
  static Future<LiveLocationOutcome> refresh({
    bool requestPermission = false,
  }) async {
    if (_running) return LiveLocationOutcome.failed;
    _running = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LiveLocationOutcome.failed;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return LiveLocationOutcome.failed;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) return LiveLocationOutcome.failed;

      final hive = SettingsHiveBox.instance;
      final oldLat = double.tryParse(hive.userLatitude) ?? 0;
      final oldLng = double.tryParse(hive.userLongitude) ?? 0;
      if (hive.hasLocation && oldLat != 0 && oldLng != 0) {
        final moved = Geolocator.distanceBetween(
          oldLat,
          oldLng,
          position.latitude,
          position.longitude,
        );
        if (moved < _minMoveMeters) return LiveLocationOutcome.unchanged;
      }

      await _save(position.latitude, position.longitude);
      return LiveLocationOutcome.updated;
    } catch (_) {
      return LiveLocationOutcome.failed;
    } finally {
      _running = false;
    }
  }

  /// Saves the default location (Jadupur) as the user location.
  static Future<void> applyDefault() {
    return SettingsHiveBox.instance.saveUserLocation(
      latitude: AppConfig.defaultLocationLatitude.toString(),
      longitude: AppConfig.defaultLocationLongitude.toString(),
      label: AppConfig.defaultLocationLabel,
      address: AppConfig.defaultLocationAddress,
    );
  }

  static Future<void> _save(double latitude, double longitude) async {
    var label = '';
    var address = '';
    try {
      final response = await AddressRepository().getGeocodingByLatLng(
        latitude: latitude.toString(),
        longitude: longitude.toString(),
      );
      final result = GeocodingResult.fromJson(response);
      address = result.formattedAddress;
      label = result.city.isNotEmpty
          ? result.city
          : result.formattedAddress.split(',').first.trim();
    } catch (_) {
      // Address lookup failed — still keep the coordinates.
    }
    if (label.isEmpty) label = 'Current location';

    await SettingsHiveBox.instance.saveUserLocation(
      latitude: latitude.toString(),
      longitude: longitude.toString(),
      label: label,
      address: address,
    );
  }
}
