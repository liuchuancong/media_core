from pathlib import Path
import sys


PROJECT_NAME = "media_core"

ROOT = Path(__file__).resolve().parent
PACKAGE_ROOT = ROOT / "packages" / PROJECT_NAME


DIRECTORIES = [
    "lib",

    # Core
    "lib/core",

    # Reactive
    "lib/reactive",

    # Error
    "lib/error",

    # Result
    "lib/result",

    # Operation
    "lib/operation",

    # Bug / Fault Injection
    "lib/bug",

    # Utility
    "lib/util",

    # Identity
    "lib/identity",

    # Task / Async
    "lib/task",

    # State Machine
    "lib/state_machine",

    # Concurrency
    "lib/concurrency",

    # Network
    "lib/network",

    # Source
    "lib/source",

    # Adapter
    "lib/adapter",

    # Factory
    "lib/factory",

    # Session
    "lib/session",

    # Slot
    "lib/slot",

    # Pool
    "lib/pool",

    # Coordinator
    "lib/coordinator",

    # Reconciler
    "lib/reconciler",

    # Lifecycle
    "lib/lifecycle",

    # Visibility
    "lib/visibility",

    # Preload
    "lib/preload",

    # Resource
    "lib/resource",

    # Audio
    "lib/audio",

    # Presentation
    "lib/presentation",

    # Renderer
    "lib/renderer",

    # Geometry
    "lib/geometry",

    # Playback
    "lib/playback",

    # Recovery
    "lib/recovery",

    # Fallback
    "lib/fallback",

    # Cache
    "lib/cache",

    # Event
    "lib/event",

    # Policy
    "lib/policy",

    # Platform
    "lib/platform",

    # Diagnostics
    "lib/diagnostics",

    # Recording
    "lib/recording",

    # Testing
    "lib/testing",

    # Tests
    "test",
]


FILES = [
    "lib/media_core.dart",

    # ============================================================
    # Core
    # ============================================================

    "lib/core/player.dart",
    "lib/core/player_config.dart",
    "lib/core/player_error.dart",
    "lib/core/player_info.dart",
    "lib/core/player_metrics.dart",
    "lib/core/player_state.dart",
    "lib/core/player_status.dart",
    "lib/core/player_capabilities.dart",
    "lib/core/player_constants.dart",
    "lib/core/player_options.dart",
    "lib/core/player_snapshot.dart",

    # ============================================================
    # Reactive
    # ============================================================

    "lib/reactive/reactive.dart",
    "lib/reactive/subject.dart",
    "lib/reactive/behavior.dart",
    "lib/reactive/stream_extensions.dart",
    "lib/reactive/stream_controller.dart",
    "lib/reactive/combine.dart",
    "lib/reactive/debounce.dart",
    "lib/reactive/throttle.dart",
    "lib/reactive/distinct.dart",
    "lib/reactive/disposable_subscription.dart",

    # ============================================================
    # Error
    # ============================================================

    "lib/error/player_exception.dart",
    "lib/error/player_failure.dart",
    "lib/error/player_error_code.dart",
    "lib/error/player_error_category.dart",
    "lib/error/error_context.dart",
    "lib/error/error_policy.dart",
    "lib/error/error_classifier.dart",
    "lib/error/error_formatter.dart",

    # ============================================================
    # Result
    # ============================================================

    "lib/result/result.dart",
    "lib/result/result_error.dart",
    "lib/result/result_status.dart",
    "lib/result/operation_result.dart",
    "lib/result/async_result.dart",

    # ============================================================
    # Operation
    # ============================================================

    "lib/operation/operation.dart",
    "lib/operation/operation_id.dart",
    "lib/operation/operation_type.dart",
    "lib/operation/operation_state.dart",
    "lib/operation/operation_context.dart",
    "lib/operation/operation_registry.dart",
    "lib/operation/operation_tracker.dart",
    "lib/operation/operation_timeout.dart",
    "lib/operation/operation_cancel_token.dart",
    "lib/operation/operation_result.dart",

    # ============================================================
    # Bug Mode / Fault Injection
    # ============================================================

    "lib/bug/bug_mode.dart",
    "lib/bug/bug_mode_config.dart",
    "lib/bug/bug_mode_controller.dart",
    "lib/bug/fault_injector.dart",
    "lib/bug/fault_type.dart",
    "lib/bug/fault_config.dart",
    "lib/bug/fault_event.dart",
    "lib/bug/fault_scenario.dart",
    "lib/bug/fault_scheduler.dart",
    "lib/bug/bug_hooks.dart",

    # ============================================================
    # Utility
    # ============================================================

    "lib/util/id_generator.dart",
    "lib/util/duration_utils.dart",
    "lib/util/uri_utils.dart",
    "lib/util/header_utils.dart",
    "lib/util/cookie_utils.dart",
    "lib/util/mime_utils.dart",
    "lib/util/platform_utils.dart",
    "lib/util/retry_utils.dart",
    "lib/util/future_utils.dart",
    "lib/util/stream_utils.dart",
    "lib/util/dispose_utils.dart",
    "lib/util/validation_utils.dart",
    "lib/util/debug_utils.dart",
    "lib/util/math_utils.dart",
    "lib/util/string_utils.dart",
    "lib/util/list_utils.dart",
    "lib/util/map_utils.dart",
    "lib/util/time_utils.dart",
    "lib/util/enum_utils.dart",

    # ============================================================
    # Identity
    # ============================================================

    "lib/identity/player_id.dart",
    "lib/identity/session_id.dart",
    "lib/identity/slot_id.dart",
    "lib/identity/source_id.dart",
    "lib/identity/operation_id.dart",
    "lib/identity/request_id.dart",
    "lib/identity/generation_id.dart",

    # ============================================================
    # Task / Async
    # ============================================================

    "lib/task/player_task.dart",
    "lib/task/task_id.dart",
    "lib/task/task_type.dart",
    "lib/task/task_state.dart",
    "lib/task/task_priority.dart",
    "lib/task/task_queue.dart",
    "lib/task/task_scheduler.dart",
    "lib/task/task_context.dart",
    "lib/task/task_manager.dart",
    "lib/task/task_cancel_token.dart",

    # ============================================================
    # State Machine
    # ============================================================

    "lib/state_machine/state_machine.dart",
    "lib/state_machine/state.dart",
    "lib/state_machine/state_transition.dart",
    "lib/state_machine/state_transition_result.dart",
    "lib/state_machine/state_machine_event.dart",
    "lib/state_machine/state_machine_context.dart",
    "lib/state_machine/state_machine_controller.dart",

    # ============================================================
    # Concurrency
    # ============================================================

    "lib/concurrency/concurrency_manager.dart",
    "lib/concurrency/concurrency_policy.dart",
    "lib/concurrency/concurrency_limit.dart",
    "lib/concurrency/concurrency_key.dart",
    "lib/concurrency/mutex.dart",
    "lib/concurrency/semaphore.dart",
    "lib/concurrency/lock.dart",
    "lib/concurrency/exclusive_task.dart",
    "lib/concurrency/serial_executor.dart",

    # ============================================================
    # Network
    # ============================================================

    "lib/network/network_manager.dart",
    "lib/network/network_state.dart",
    "lib/network/network_type.dart",
    "lib/network/network_quality.dart",
    "lib/network/network_monitor.dart",
    "lib/network/network_request.dart",
    "lib/network/network_response.dart",
    "lib/network/network_policy.dart",
    "lib/network/network_metrics.dart",
    "lib/network/network_condition.dart",

    # ============================================================
    # Source
    # ============================================================

    "lib/source/player_source.dart",
    "lib/source/source_id.dart",
    "lib/source/source_type.dart",
    "lib/source/source_protocol.dart",
    "lib/source/source_media_type.dart",
    "lib/source/source_format.dart",
    "lib/source/source_headers.dart",
    "lib/source/source_metadata.dart",
    "lib/source/source_descriptor.dart",
    "lib/source/source_request.dart",
    "lib/source/source_location.dart",
    "lib/source/source_identity.dart",
    "lib/source/source_policy.dart",
    "lib/source/source_resolver.dart",
    "lib/source/source_inspector.dart",
    "lib/source/source_validator.dart",

    # ============================================================
    # Adapter
    # ============================================================

    "lib/adapter/player_adapter.dart",
    "lib/adapter/player_adapter_config.dart",
    "lib/adapter/player_adapter_capabilities.dart",
    "lib/adapter/player_adapter_event.dart",
    "lib/adapter/player_adapter_state.dart",
    "lib/adapter/player_adapter_error.dart",
    "lib/adapter/player_adapter_factory.dart",
    "lib/adapter/player_adapter_registry.dart",
    "lib/adapter/player_adapter_selector.dart",
    "lib/adapter/player_adapter_context.dart",
    "lib/adapter/player_adapter_metrics.dart",

    # ============================================================
    # Factory
    # ============================================================

    "lib/factory/player_factory.dart",
    "lib/factory/player_factory_config.dart",
    "lib/factory/backend_factory.dart",
    "lib/factory/backend_registry.dart",
    "lib/factory/backend_selector.dart",
    "lib/factory/backend_descriptor.dart",
    "lib/factory/backend_capabilities.dart",

    # ============================================================
    # Session
    # ============================================================

    "lib/session/player_session.dart",
    "lib/session/session_id.dart",
    "lib/session/session_generation.dart",
    "lib/session/session_state.dart",
    "lib/session/session_context.dart",
    "lib/session/session_snapshot.dart",
    "lib/session/session_manager.dart",
    "lib/session/session_controller.dart",
    "lib/session/session_lifecycle.dart",
    "lib/session/session_operation.dart",
    "lib/session/session_event.dart",

    # ============================================================
    # Slot
    # ============================================================

    "lib/slot/player_slot.dart",
    "lib/slot/player_slot_state.dart",
    "lib/slot/player_slot_manager.dart",
    "lib/slot/player_slot_owner.dart",
    "lib/slot/player_slot_assignment.dart",
    "lib/slot/player_slot_snapshot.dart",

    # ============================================================
    # Pool
    # ============================================================

    "lib/pool/player_pool.dart",
    "lib/pool/player_pool_config.dart",
    "lib/pool/player_pool_manager.dart",
    "lib/pool/player_pool_policy.dart",
    "lib/pool/player_pool_state.dart",
    "lib/pool/player_pool_metrics.dart",
    "lib/pool/player_pool_snapshot.dart",
    "lib/pool/player_pool_allocator.dart",
    "lib/pool/player_pool_recycler.dart",

    # ============================================================
    # Coordinator
    # ============================================================

    "lib/coordinator/player_coordinator.dart",
    "lib/coordinator/playback_coordinator.dart",
    "lib/coordinator/page_coordinator.dart",
    "lib/coordinator/audio_coordinator.dart",
    "lib/coordinator/resource_coordinator.dart",
    "lib/coordinator/preload_coordinator.dart",
    "lib/coordinator/lifecycle_coordinator.dart",
    "lib/coordinator/presentation_coordinator.dart",
    "lib/coordinator/global_player_coordinator.dart",

    # ============================================================
    # Reconciler
    # ============================================================

    "lib/reconciler/player_reconciler.dart",
    "lib/reconciler/reconcile_action.dart",
    "lib/reconciler/reconcile_state.dart",
    "lib/reconciler/reconcile_queue.dart",
    "lib/reconciler/reconcile_context.dart",
    "lib/reconciler/reconcile_plan.dart",
    "lib/reconciler/reconcile_result.dart",
    "lib/reconciler/reconcile_scheduler.dart",

    # ============================================================
    # Lifecycle
    # ============================================================

    "lib/lifecycle/player_lifecycle.dart",
    "lib/lifecycle/lifecycle_controller.dart",
    "lib/lifecycle/lifecycle_state.dart",
    "lib/lifecycle/lifecycle_observer.dart",
    "lib/lifecycle/lifecycle_event.dart",
    "lib/lifecycle/lifecycle_policy.dart",
    "lib/lifecycle/lifecycle_snapshot.dart",

    # ============================================================
    # Visibility
    # ============================================================

    "lib/visibility/visibility_controller.dart",
    "lib/visibility/visibility_observer.dart",
    "lib/visibility/visibility_policy.dart",
    "lib/visibility/visibility_state.dart",
    "lib/visibility/visibility_event.dart",
    "lib/visibility/visibility_snapshot.dart",
    "lib/visibility/visibility_metrics.dart",

    # ============================================================
    # Preload
    # ============================================================

    "lib/preload/preload_manager.dart",
    "lib/preload/preload_task.dart",
    "lib/preload/preload_scheduler.dart",
    "lib/preload/preload_policy.dart",
    "lib/preload/preload_priority.dart",
    "lib/preload/preload_state.dart",
    "lib/preload/preload_request.dart",
    "lib/preload/preload_context.dart",
    "lib/preload/preload_metrics.dart",

    # ============================================================
    # Resource
    # ============================================================

    "lib/resource/resource_manager.dart",
    "lib/resource/resource_policy.dart",
    "lib/resource/resource_state.dart",
    "lib/resource/resource_snapshot.dart",
    "lib/resource/decoder_budget.dart",
    "lib/resource/decoder_manager.dart",
    "lib/resource/memory_budget.dart",
    "lib/resource/memory_manager.dart",
    "lib/resource/thermal_manager.dart",
    "lib/resource/thermal_state.dart",
    "lib/resource/bandwidth_manager.dart",
    "lib/resource/bandwidth_budget.dart",
    "lib/resource/resource_pressure.dart",
    "lib/resource/resource_metrics.dart",

    # ============================================================
    # Audio
    # ============================================================

    "lib/audio/audio_manager.dart",
    "lib/audio/audio_focus.dart",
    "lib/audio/audio_focus_state.dart",
    "lib/audio/audio_policy.dart",
    "lib/audio/audio_session.dart",
    "lib/audio/audio_session_state.dart",
    "lib/audio/audio_coordinator.dart",
    "lib/audio/audio_route.dart",
    "lib/audio/audio_volume.dart",
    "lib/audio/audio_mute.dart",

    # ============================================================
    # Presentation
    # ============================================================

    "lib/presentation/presentation_controller.dart",
    "lib/presentation/presentation_mode.dart",
    "lib/presentation/presentation_state.dart",
    "lib/presentation/presentation_request.dart",
    "lib/presentation/presentation_snapshot.dart",
    "lib/presentation/pip_controller.dart",
    "lib/presentation/pip_state.dart",
    "lib/presentation/fullscreen_controller.dart",
    "lib/presentation/fullscreen_state.dart",
    "lib/presentation/floating_controller.dart",
    "lib/presentation/floating_state.dart",

    # ============================================================
    # Renderer
    # ============================================================

    "lib/renderer/player_renderer.dart",
    "lib/renderer/player_view.dart",
    "lib/renderer/player_surface.dart",
    "lib/renderer/player_overlay.dart",
    "lib/renderer/renderer_config.dart",
    "lib/renderer/renderer_state.dart",
    "lib/renderer/renderer_capabilities.dart",
    "lib/renderer/renderer_controller.dart",

    # ============================================================
    # Geometry
    # ============================================================

    "lib/geometry/video_geometry.dart",
    "lib/geometry/geometry_session.dart",
    "lib/geometry/geometry_controller.dart",
    "lib/geometry/geometry_state.dart",
    "lib/geometry/geometry_event.dart",
    "lib/geometry/aspect_ratio.dart",
    "lib/geometry/video_orientation.dart",
    "lib/geometry/video_rotation.dart",
    "lib/geometry/video_size.dart",
    "lib/geometry/display_size.dart",
    "lib/geometry/pixel_ratio.dart",
    "lib/geometry/geometry_snapshot.dart",

    # ============================================================
    # Playback
    # ============================================================

    "lib/playback/playback_controller.dart",
    "lib/playback/playback_state.dart",
    "lib/playback/playback_position.dart",
    "lib/playback/playback_duration.dart",
    "lib/playback/playback_command.dart",
    "lib/playback/playback_command_type.dart",
    "lib/playback/playback_options.dart",
    "lib/playback/playback_request.dart",
    "lib/playback/playback_snapshot.dart",
    "lib/playback/playback_rate.dart",
    "lib/playback/playback_volume.dart",

    # ============================================================
    # Recovery
    # ============================================================

    "lib/recovery/recovery_manager.dart",
    "lib/recovery/recovery_policy.dart",
    "lib/recovery/recovery_action.dart",
    "lib/recovery/recovery_state.dart",
    "lib/recovery/recovery_reason.dart",
    "lib/recovery/recovery_context.dart",
    "lib/recovery/recovery_snapshot.dart",
    "lib/recovery/retry_scheduler.dart",
    "lib/recovery/retry_policy.dart",
    "lib/recovery/retry_state.dart",

    # ============================================================
    # Fallback
    # ============================================================

    "lib/fallback/fallback_manager.dart",
    "lib/fallback/backend_fallback.dart",
    "lib/fallback/backend_fallback_policy.dart",
    "lib/fallback/backend_fallback_state.dart",
    "lib/fallback/line_fallback.dart",
    "lib/fallback/line_fallback_policy.dart",
    "lib/fallback/line_fallback_state.dart",
    "lib/fallback/quality_fallback.dart",
    "lib/fallback/quality_fallback_policy.dart",
    "lib/fallback/quality_fallback_state.dart",
    "lib/fallback/fallback_reason.dart",
    "lib/fallback/fallback_context.dart",
    "lib/fallback/fallback_result.dart",

    # ============================================================
    # Cache
    # ============================================================

    "lib/cache/cache_manager.dart",
    "lib/cache/cache_policy.dart",
    "lib/cache/cache_entry.dart",
    "lib/cache/cache_key.dart",
    "lib/cache/cache_state.dart",
    "lib/cache/cache_result.dart",
    "lib/cache/memory_cache.dart",
    "lib/cache/disk_cache.dart",
    "lib/cache/cache_storage.dart",
    "lib/cache/cache_eviction.dart",
    "lib/cache/cache_metrics.dart",

    # ============================================================
    # Event
    # ============================================================

    "lib/event/player_event.dart",
    "lib/event/player_event_type.dart",
    "lib/event/player_event_bus.dart",
    "lib/event/event_dispatcher.dart",
    "lib/event/event_context.dart",
    "lib/event/event_priority.dart",
    "lib/event/event_filter.dart",
    "lib/event/event_subscription.dart",

    # ============================================================
    # Policy
    # ============================================================

    "lib/policy/player_policy.dart",
    "lib/policy/playback_policy.dart",
    "lib/policy/preload_policy.dart",
    "lib/policy/concurrency_policy.dart",
    "lib/policy/memory_policy.dart",
    "lib/policy/thermal_policy.dart",
    "lib/policy/audio_policy.dart",
    "lib/policy/lifecycle_policy.dart",
    "lib/policy/recovery_policy.dart",
    "lib/policy/resource_policy.dart",
    "lib/policy/visibility_policy.dart",
    "lib/policy/fallback_policy.dart",
    "lib/policy/presentation_policy.dart",
    "lib/policy/policy_context.dart",

    # ============================================================
    # Platform
    # ============================================================

    "lib/platform/platform_capabilities.dart",
    "lib/platform/platform_provider.dart",
    "lib/platform/platform_type.dart",
    "lib/platform/platform_pip.dart",
    "lib/platform/platform_audio.dart",
    "lib/platform/platform_lifecycle.dart",
    "lib/platform/platform_renderer.dart",
    "lib/platform/platform_surface.dart",
    "lib/platform/platform_network.dart",
    "lib/platform/platform_info.dart",

    # ============================================================
    # Diagnostics
    # ============================================================

    "lib/diagnostics/player_logger.dart",
    "lib/diagnostics/log_level.dart",
    "lib/diagnostics/log_category.dart",
    "lib/diagnostics/player_metrics.dart",
    "lib/diagnostics/player_debug_snapshot.dart",
    "lib/diagnostics/performance_monitor.dart",
    "lib/diagnostics/performance_sample.dart",
    "lib/diagnostics/memory_monitor.dart",
    "lib/diagnostics/memory_snapshot.dart",
    "lib/diagnostics/network_monitor.dart",
    "lib/diagnostics/network_snapshot.dart",
    "lib/diagnostics/diagnostics_manager.dart",
    "lib/diagnostics/diagnostics_config.dart",
    "lib/diagnostics/diagnostics_event.dart",

    # ============================================================
    # Recording
    # ============================================================

    "lib/recording/recording_manager.dart",
    "lib/recording/recording_config.dart",
    "lib/recording/recording_session.dart",
    "lib/recording/recording_state.dart",
    "lib/recording/recording_source.dart",
    "lib/recording/recording_format.dart",
    "lib/recording/recording_result.dart",
    "lib/recording/recording_error.dart",
    "lib/recording/recording_backend.dart",

    # ============================================================
    # Testing
    # ============================================================

    "lib/testing/fake_clock.dart",
    "lib/testing/fake_timer.dart",
    "lib/testing/fake_player.dart",
    "lib/testing/fake_player_adapter.dart",
    "lib/testing/fake_network.dart",
    "lib/testing/fake_visibility.dart",
    "lib/testing/fake_lifecycle.dart",
    "lib/testing/fake_platform.dart",
    "lib/testing/test_player_factory.dart",
    "lib/testing/test_session_factory.dart",
    "lib/testing/test_source_factory.dart",
    "lib/testing/test_scenarios.dart",
    "lib/testing/test_assertions.dart",

    # ============================================================
    # Tests
    # ============================================================

    "test/media_core_test.dart",

    "test/core/player_state_test.dart",
    "test/core/player_config_test.dart",
    "test/core/player_error_test.dart",

    "test/source/player_source_test.dart",
    "test/source/source_inspector_test.dart",
    "test/source/source_validator_test.dart",

    "test/session/player_session_test.dart",
    "test/session/session_generation_test.dart",
    "test/session/session_manager_test.dart",

    "test/adapter/player_adapter_test.dart",

    "test/operation/operation_registry_test.dart",
    "test/operation/operation_tracker_test.dart",

    "test/reactive/stream_extensions_test.dart",

    "test/bug/bug_mode_test.dart",
    "test/bug/fault_injector_test.dart",

    "test/geometry/video_geometry_test.dart",

    "test/state_machine/state_machine_test.dart",

    "test/concurrency/mutex_test.dart",
    "test/concurrency/semaphore_test.dart",

    "test/recovery/recovery_manager_test.dart",
    "test/fallback/fallback_manager_test.dart",

    "test/pool/player_pool_test.dart",
    "test/slot/player_slot_test.dart",

    "test/reconciler/player_reconciler_test.dart",

    "test/testing/fake_player_test.dart",
]


def create_directories() -> None:
    for directory in DIRECTORIES:
        path = PACKAGE_ROOT / directory
        path.mkdir(parents=True, exist_ok=True)


def create_files() -> None:
    created = 0
    existing = 0

    for file in FILES:
        path = PACKAGE_ROOT / file
        path.parent.mkdir(parents=True, exist_ok=True)

        if path.exists():
            existing += 1
            continue

        path.touch()
        created += 1

    print(f"New files:  {created}")
    print(f"Existing:   {existing}")


def print_tree() -> None:
    print()
    print("=" * 72)
    print("Package Structure")
    print("=" * 72)

    directories = sorted(
        p for p in PACKAGE_ROOT.rglob("*")
        if p.is_dir()
    )

    files = sorted(
        p for p in PACKAGE_ROOT.rglob("*")
        if p.is_file()
    )

    print(f"Package root: {PACKAGE_ROOT}")
    print(f"Directories:  {len(directories)}")
    print(f"Files:        {len(files)}")
    print()


def main() -> None:
    print("=" * 72)
    print(f"Generating {PROJECT_NAME}")
    print("=" * 72)
    print()

    print(f"Workspace root: {ROOT}")
    print(f"Package root:   {PACKAGE_ROOT}")
    print()

    if PACKAGE_ROOT.exists():
        print("Package directory already exists.")
        print("Existing files will NOT be overwritten.")
        print()

    create_directories()
    create_files()
    print_tree()

    print("=" * 72)
    print("Generation completed.")
    print("=" * 72)
    print()
    print("No Dart implementation code was generated.")
    print("All newly created Dart files are empty.")
    print()
    print("Package:")
    print(f"  {PROJECT_NAME}")
    print()
    print("Next step:")
    print()
    print("  flutter pub get")
    print()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        print("Generation cancelled.")
        sys.exit(130)
    except Exception as error:
        print()
        print(f"Generation failed: {error}")
        sys.exit(1)