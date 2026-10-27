import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';

/// Pins the transition-clearing behaviour the presentation layer always
/// meant to have: an attempt that ends — started, completed, failed, changed
/// from outside, or disposed — must not carry the previous attempt's error or
/// pending target into the next state.
///
/// Under freezed these call sites passed `error: null` / `targetMode: null`,
/// which its generated `copyWith` silently ignored, so a stale error survived
/// every successful transition. They now clear explicitly.
void main() {
  const reducer = PresentationReducer();

  /// A state in the middle of a failed attempt: an error from the last try and
  /// a target still pending.
  PresentationState stale() {
    return PresentationState.initial().copyWith(
      targetMode: PresentationMode.pip,
      transitioning: true,
      generation: 1,
      error: 'system refused the overlay',
    );
  }

  group('PresentationReducer clears what an ended attempt left behind', () {
    test('a new attempt reports no leftover error and targets the new mode', () {
      final next = reducer.reduce(
        stale(),
        const PresentationEvent.started(mode: PresentationMode.fullscreen, generation: 2),
      );

      expect(next.error, isNull);
      expect(next.targetMode, PresentationMode.fullscreen);
      expect(next.transitioning, isTrue);
      expect(next.mode, PresentationMode.normal, reason: 'the running mode is unchanged mid-transition');
    });

    test('a completed transition reports neither error nor pending target', () {
      final next = reducer.reduce(
        stale(),
        const PresentationEvent.completed(mode: PresentationMode.fullscreen, generation: 2),
      );

      expect(next.error, isNull);
      expect(next.targetMode, isNull);
      expect(next.transitioning, isFalse);
      expect(next.mode, PresentationMode.fullscreen);
    });

    test('a failed transition replaces the message and drops the pending target', () {
      final next = reducer.reduce(stale(), const PresentationEvent.failed(error: 'backend went away', generation: 2));

      expect(next.error, 'backend went away');
      expect(next.targetMode, isNull);
      expect(next.transitioning, isFalse);
      expect(next.mode, PresentationMode.normal);
    });

    test('an external change clears both the error and the pending target', () {
      final next = reducer.reduce(
        stale(),
        const PresentationEvent.changed(mode: PresentationMode.normal, generation: 2),
      );

      expect(next.error, isNull);
      expect(next.targetMode, isNull);
      expect(next.transitioning, isFalse);
      expect(next.mode, PresentationMode.normal);
    });

    test('a dispose drops the pending target', () {
      final next = reducer.reduce(stale(), const PresentationEvent.disposed(generation: 4));

      expect(next.targetMode, isNull);
      expect(next.transitioning, isFalse);
      expect(next.generation, 4);
    });

    test('a stale event still cannot overwrite a newer state', () {
      final next = reducer.reduce(
        stale(),
        const PresentationEvent.completed(mode: PresentationMode.fullscreen),
      );

      expect(next, stale(), reason: 'events older than the state are ignored wholesale');
    });
  });

  group('PresentationState helpers', () {
    test('transitioningTo starts clean', () {
      final next = stale().transitioningTo(PresentationMode.pip);

      expect(next.error, isNull);
      expect(next.targetMode, PresentationMode.pip);
      expect(next.transitioning, isTrue);
    });

    test('completed leaves nothing pending', () {
      final next = stale().completed(PresentationMode.pip);

      expect(next.error, isNull);
      expect(next.targetMode, isNull);
      expect(next.mode, PresentationMode.pip);
    });

    test('copyWith keeps an omitted field, which is why clearing is explicit', () {
      final kept = stale().copyWith(transitioning: false);

      expect(kept.error, 'system refused the overlay');
      expect(kept.targetMode, PresentationMode.pip);
    });
  });

  group('mode controllers begin a transition clean', () {
    test('floating forgets an error the adapter reported', () async {
      final controller = FloatingController()
        ..update(FloatingState.initial().copyWith(available: true, error: 'overlay surface died'));

      await controller.enter();

      expect(controller.current.error, isNull);
      expect(controller.current.transitioning, isTrue);
    });

    test('picture-in-picture forgets an error the adapter reported', () async {
      final controller = PipController()
        ..update(PipState.initial().copyWith(available: true, error: 'system closed the picture'));

      await controller.enter();

      expect(controller.current.error, isNull);
      expect(controller.current.transitioning, isTrue);
    });

    test('fullscreen forgets an error the adapter reported', () async {
      final controller = FullscreenController()
        ..update(
          FullscreenState.initial().copyWith(available: true, error: 'the window would not cover the screen'),
        );

      await controller.enter();

      expect(controller.current.error, isNull);
      expect(controller.current.transitioning, isTrue);
    });
  });
}
