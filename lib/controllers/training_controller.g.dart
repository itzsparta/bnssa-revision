// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TrainingController)
final trainingControllerProvider = TrainingControllerProvider._();

final class TrainingControllerProvider
    extends $NotifierProvider<TrainingController, TrainingState> {
  TrainingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainingControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainingControllerHash();

  @$internal
  @override
  TrainingController create() => TrainingController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrainingState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrainingState>(value),
    );
  }
}

String _$trainingControllerHash() =>
    r'741c7c70236bc7b88dcd56984f43f1a8016d98b4';

abstract class _$TrainingController extends $Notifier<TrainingState> {
  TrainingState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<TrainingState, TrainingState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TrainingState, TrainingState>,
              TrainingState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
