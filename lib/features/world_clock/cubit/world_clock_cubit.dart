import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/horological_models.dart';

class WorldClockState {
  final WorldCity selectedCity;
  final List<String> pinnedCityIds;
  final List<WorldCity> customCities;

  const WorldClockState({
    required this.selectedCity,
    this.pinnedCityIds = const ['bengaluru', 'stockholm', 'tokyo', 'newyork'],
    this.customCities = const [],
  });

  List<WorldCity> get allCities => [...kWorldCities, ...customCities];

  WorldCity resolveCity(String id) {
    for (final c in customCities) {
      if (c.id == id) return c;
    }
    for (final c in kWorldCities) {
      if (c.id == id) return c;
    }
    return selectedCity;
  }

  WorldClockState copyWith({
    WorldCity? selectedCity,
    List<String>? pinnedCityIds,
    List<WorldCity>? customCities,
  }) {
    return WorldClockState(
      selectedCity: selectedCity ?? this.selectedCity,
      pinnedCityIds: pinnedCityIds ?? this.pinnedCityIds,
      customCities: customCities ?? this.customCities,
    );
  }
}

class WorldClockCubit extends Cubit<WorldClockState> {
  final void Function()? onStateChanged;

  WorldClockCubit({
    required WorldCity initialCity,
    List<String> initialPinnedIds = const [
      'bengaluru',
      'stockholm',
      'tokyo',
      'newyork',
    ],
    List<WorldCity> initialCustomCities = const [],
    this.onStateChanged,
  }) : super(
         WorldClockState(
           selectedCity: initialCity,
           pinnedCityIds: initialPinnedIds,
           customCities: initialCustomCities,
         ),
       );

  void selectCity(WorldCity city) {
    List<WorldCity> updatedCustom = List<WorldCity>.from(state.customCities);
    if (city.isCustom && !updatedCustom.any((c) => c.id == city.id)) {
      updatedCustom.add(city);
    }
    emit(state.copyWith(selectedCity: city, customCities: updatedCustom));
    onStateChanged?.call();
  }

  void addCustomCity(WorldCity city) {
    if (state.customCities.any((c) => c.id == city.id)) return;
    final updated = List<WorldCity>.from(state.customCities)..add(city);
    emit(state.copyWith(customCities: updated));
    onStateChanged?.call();
  }

  void togglePinCity(String cityId) {
    final updatedPinned = List<String>.from(state.pinnedCityIds);
    if (updatedPinned.contains(cityId)) {
      if (updatedPinned.length > 1) {
        updatedPinned.remove(cityId);
      }
    } else {
      updatedPinned.add(cityId);
    }
    emit(state.copyWith(pinnedCityIds: updatedPinned));
    onStateChanged?.call();
  }

  void hydrate({
    WorldCity? selectedCity,
    List<String>? pinnedCityIds,
    List<WorldCity>? customCities,
  }) {
    emit(
      state.copyWith(
        selectedCity: selectedCity ?? state.selectedCity,
        pinnedCityIds: pinnedCityIds ?? state.pinnedCityIds,
        customCities: customCities ?? state.customCities,
      ),
    );
  }
}
