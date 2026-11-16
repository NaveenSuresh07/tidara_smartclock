import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/city_search_repository.dart';
import '../../../models/horological_models.dart';

sealed class CitySearchState {
  const CitySearchState();
}

class CitySearchInitial extends CitySearchState {
  final List<WorldCity> defaultCities;
  const CitySearchInitial({this.defaultCities = kWorldCities});
}

class CitySearchLoading extends CitySearchState {
  final String query;
  const CitySearchLoading(this.query);
}

class CitySearchLoaded extends CitySearchState {
  final List<WorldCity> cities;
  final String query;
  final bool isOffline;
  final bool isCacheHit;
  final String? infoMessage;

  const CitySearchLoaded({
    required this.cities,
    required this.query,
    this.isOffline = false,
    this.isCacheHit = false,
    this.infoMessage,
  });
}

class CitySearchEmpty extends CitySearchState {
  final String query;
  final bool isOffline;
  const CitySearchEmpty({required this.query, this.isOffline = false});
}

class CitySearchError extends CitySearchState {
  final String message;
  final List<WorldCity> fallbackCities;
  final bool isOffline;

  const CitySearchError({
    required this.message,
    this.fallbackCities = const [],
    this.isOffline = false,
  });
}

class CitySearchCubit extends Cubit<CitySearchState> {
  final CitySearchRepository _repository;
  Timer? _debounceTimer;

  CitySearchCubit({CitySearchRepository? repository})
    : _repository = repository ?? CitySearchRepository(),
      super(const CitySearchInitial());

  CitySearchRepository get repository => _repository;

  /// Trigger a live search with optional debounce (e.g. 350ms for live typing).
  void search(String query, {bool debounce = false}) {
    _debounceTimer?.cancel();

    if (debounce) {
      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        _executeSearch(query);
      });
    } else {
      _executeSearch(query);
    }
  }

  Future<void> _executeSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      emit(
        CitySearchInitial(
          defaultCities: [...kWorldCities, ..._repository.customCities],
        ),
      );
      return;
    }

    emit(CitySearchLoading(clean));

    try {
      final result = await _repository.searchCities(clean);

      if (result.cities.isEmpty) {
        if (result.hasError) {
          emit(
            CitySearchError(
              message: result.errorMessage ?? 'Search failed',
              fallbackCities: const [],
              isOffline: result.isOfflineFallback,
            ),
          );
        } else {
          emit(
            CitySearchEmpty(query: clean, isOffline: result.isOfflineFallback),
          );
        }
      } else {
        emit(
          CitySearchLoaded(
            cities: result.cities,
            query: clean,
            isOffline: result.isOfflineFallback,
            isCacheHit: result.isCacheHit,
            infoMessage: result.errorMessage,
          ),
        );
      }
    } catch (e) {
      emit(
        CitySearchError(
          message: 'Search failed: $e',
          fallbackCities: const [],
          isOffline: true,
        ),
      );
    }
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    emit(
      CitySearchInitial(
        defaultCities: [...kWorldCities, ..._repository.customCities],
      ),
    );
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
