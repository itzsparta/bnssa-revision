// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(userDoc)
final userDocProvider = UserDocProvider._();

final class UserDocProvider
    extends
        $FunctionalProvider<
          AsyncValue<DocumentSnapshot<Map<String, dynamic>>>,
          DocumentSnapshot<Map<String, dynamic>>,
          Stream<DocumentSnapshot<Map<String, dynamic>>>
        >
    with
        $FutureModifier<DocumentSnapshot<Map<String, dynamic>>>,
        $StreamProvider<DocumentSnapshot<Map<String, dynamic>>> {
  UserDocProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userDocProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userDocHash();

  @$internal
  @override
  $StreamProviderElement<DocumentSnapshot<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> create(Ref ref) {
    return userDoc(ref);
  }
}

String _$userDocHash() => r'9183f469a3c9920e2a1d4b58f5177179ceb350ee';

@ProviderFor(questions)
final questionsProvider = QuestionsFamily._();

final class QuestionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Question>>,
          List<Question>,
          FutureOr<List<Question>>
        >
    with $FutureModifier<List<Question>>, $FutureProvider<List<Question>> {
  QuestionsProvider._({
    required QuestionsFamily super.from,
    required ({String themeId, String themeTitle}) super.argument,
  }) : super(
         retry: null,
         name: r'questionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$questionsHash();

  @override
  String toString() {
    return r'questionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Question>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Question>> create(Ref ref) {
    final argument = this.argument as ({String themeId, String themeTitle});
    return questions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is QuestionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$questionsHash() => r'a267ece55a6acd0f725df7a17e76dd62c5bc2ba0';

final class QuestionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Question>>,
          ({String themeId, String themeTitle})
        > {
  QuestionsFamily._()
    : super(
        retry: null,
        name: r'questionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  QuestionsProvider call(({String themeId, String themeTitle}) params) =>
      QuestionsProvider._(argument: params, from: this);

  @override
  String toString() => r'questionsProvider';
}
