import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/address/widgets/location_permission_dialog.dart';
import 'package:customer/features/location/cubit/user_location_cubit.dart';
import 'package:customer/features/location/screens/location_search_screen.dart';
import 'package:customer/features/location/services/live_location_service.dart';
import 'package:customer/features/location/widgets/location_required_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Full-screen "set your location" gate shown before entering [RouteNames.main]
/// whenever [SettingsHiveBox.hasLocation] is false (post-onboarding, post-login, etc).
/// Replaces the current route once location is set.
class LocationRequiredScreen extends StatefulWidget {
  const LocationRequiredScreen({super.key});

  @override
  State<LocationRequiredScreen> createState() => _LocationRequiredScreenState();
}

class _LocationRequiredScreenState extends State<LocationRequiredScreen> {
  /// True while the screen is automatically resolving the location on open.
  bool _autoResolving = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoResolve());
  }

  /// Live location first (asks permission once); if it can't be read, the
  /// default location (Jadupur) is used. Either way the user goes straight in.
  Future<void> _autoResolve() async {
    final outcome = await LiveLocationService.refresh(requestPermission: true);
    if (outcome == LiveLocationOutcome.failed &&
        !SettingsHiveBox.instance.hasLocation) {
      await LiveLocationService.applyDefault();
    }
    if (!mounted) return;
    setState(() => _autoResolving = false);
    _goToMainIfLocationSet(context);
  }

  Future<void> _openSearch(BuildContext context) async {
    final saved = await AppNavigator.push<bool>(
      context,
      const LocationSearchScreen(),
    );
    if (!context.mounted) return;
    if (saved == true) _goToMainIfLocationSet(context);
  }

  void _goToMainIfLocationSet(BuildContext context) {
    if (SettingsHiveBox.instance.hasLocation) {
      AppNavigator.pushReplacementNamed(context, RouteNames.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UserLocationCubit(),
      child: BlocConsumer<UserLocationCubit, UserLocationState>(
        listener: (context, state) async {
          if (state is UserLocationDetected) {
            if (SettingsHiveBox.instance.hasLocation) {
              AppNavigator.pushReplacementNamed(context, RouteNames.main);
            }
          } else if (state is UserLocationPermissionDenied) {
            await showLocationPermissionDialog(context);
            if (context.mounted) {
              context.read<UserLocationCubit>().reset();
            }
          } else if (state is UserLocationError) {
            AppSnackBar.show(
              context: context,
              message: state.message,
              type: SnackBarType.error,
            );
            context.read<UserLocationCubit>().reset();
          }
        },
        builder: (context, state) {
          return LocationRequiredView(
            isSettingLocation:
                _autoResolving || state is UserLocationDetecting,
            onSetLocation: () =>
                context.read<UserLocationCubit>().detectCurrentLocation(),
            onSearchManually: () => _openSearch(context),
            onLocationConfirmed: () => _goToMainIfLocationSet(context),
          );
        },
      ),
    );
  }
}
