import '../../app/app_routes.dart';
import 'details/trip_details_screen.dart';
import 'driver/driver_profile_screen.dart';
import 'data/search_filter.dart';
import 'filter/filter_sheet.dart';
import 'search_screen.dart';

/// Маршруты раздела «search».
final Map<String, RouteBuilder> searchRoutes = {
  AppRoutes.search: (context, args) => const SearchScreen(),
  AppRoutes.searchFilter: (context, args) => FilterPage(
        args: args is SearchFilterArgs
            ? args
            : const SearchFilterArgs(filter: SearchFilter.empty, nearAvailable: false),
      ),
  AppRoutes.searchDetails: (context, args) => TripDetailsScreen(tripId: args as String),
  AppRoutes.searchDriver: (context, args) => DriverProfileScreen(userId: args as String),
};
