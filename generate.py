from pathlib import Path
import sys


PROJECT_NAME = "media_core"

ROOT = Path(__file__).resolve().parent
PACKAGE_ROOT = ROOT / "packages" / PROJECT_NAME


# ============================================================================
# Directory Structure
# ============================================================================

DIRECTORIES = [
    "lib",

    # ------------------------------------------------------------------------
    # Core
    # Public player API and fundamental player models.
    # ------------------------------------------------------------------------
    "lib/core",

    # ------------------------------------------------------------------------
    # Reactive
    # Reactive abstractions built on top of RxDart.
    # ------------------------------------------------------------------------
    "lib/reactive",

    # ------------------------------------------------------------------------
    # Error
    # Error model, classification, formatting and policies.
    # ------------------------------------------------------------------------
    "lib/error",

    # ------------------------------------------------------------------------
    # Result
    # Unified result abstraction.
    # ------------------------------------------------------------------------
    "lib/result",

    # ------------------------------------------------------------------------
    # Operation
    # High-level asynchronous/business operations.
    # ------------------------------------------------------------------------
    "lib/operation",

    # ------------------------------------------------------------------------
    # Bug / Fault Injection
    # Debug and fault injection infrastructure.
    # ------------------------------------------------------------------------
    "lib/bug",

    # ------------------------------------------------------------------------
    # Utility
    # Generic reusable utilities.
    # ------------------------------------------------------------------------
    "lib/util",

    # ------------------------------------------------------------------------
    # Identity
    # All cross-module identity/value objects.
    # ------------------------------------------------------------------------
    "lib/identity",

    # ------------------------------------------------------------------------
    # Task
    # Execution and scheduling units.
    # ------------------------------------------------------------------------
    "lib/task",

    # ------------------------------------------------------------------------
    # State Machine
    # Generic state machine infrastructure.
    # ------------------------------------------------------------------------
    "lib/state_machine",

    # ------------------------------------------------------------------------
    # Concurrency
    # Mutex, semaphore, serial execution, concurrency control.
    # ------------------------------------------------------------------------
    "lib/concurrency",

    # ------------------------------------------------------------------------
    # Network
    # Network abstraction and network state/metrics.
    # ------------------------------------------------------------------------
    "lib/network",

    # ------------------------------------------------------------------------
    # Source
    # Media source abstraction.
    # ------------------------------------------------------------------------
    "lib/source",

    # ------------------------------------------------------------------------
    # Adapter
    # Player backend adapter abstraction.
    # ------------------------------------------------------------------------
    "lib/adapter",

    # ------------------------------------------------------------------------
    # Factory
    # Player/backend factory and selection.
    # ------------------------------------------------------------------------
    "lib/factory",

    # ------------------------------------------------------------------------
    # Session
    # One playback lifecycle/session.
    # ------------------------------------------------------------------------
    "lib/session",

    # ------------------------------------------------------------------------
    # Slot
    # Logical player slot.
    # ------------------------------------------------------------------------
    "lib/slot",

    # ------------------------------------------------------------------------
    # Pool
    # Player instance pool.
    # ------------------------------------------------------------------------
    "lib/pool",

    # ------------------------------------------------------------------------
    # Coordinator
    # Cross-module coordination.
    # ------------------------------------------------------------------------
    "lib/coordinator",

    # ------------------------------------------------------------------------
    # Reconciler
    # Desired-state -> actual-state reconciliation.
    # ------------------------------------------------------------------------
    "lib/reconciler",

    # ------------------------------------------------------------------------
    # Lifecycle
    # App/page/player lifecycle.
    # ------------------------------------------------------------------------
    "lib/lifecycle",

    # ------------------------------------------------------------------------
    # Visibility
    # Player visibility management.
    # ------------------------------------------------------------------------
    "lib/visibility",

    # ------------------------------------------------------------------------
    # Preload
    # Preloading and warm-up.
    # ------------------------------------------------------------------------
    "lib/preload",

    # ------------------------------------------------------------------------
    # Resource
    # Memory/decoder/bandwidth/thermal resources.
    # ------------------------------------------------------------------------
    "lib/resource",

    # ------------------------------------------------------------------------
    # Audio
    # Audio focus/session/route/volume.
    # ------------------------------------------------------------------------
    "lib/audio",

    # ------------------------------------------------------------------------
    # Presentation
    # Fullscreen/PiP/floating presentation.
    # ------------------------------------------------------------------------
    "lib/presentation",

    # ------------------------------------------------------------------------
    # Renderer
    # Rendering abstraction.
    # ------------------------------------------------------------------------
    "lib/renderer",

    # ------------------------------------------------------------------------
    # Geometry
    # Video/display geometry.
    # ------------------------------------------------------------------------
    "lib/geometry",

    # ------------------------------------------------------------------------
    # Playback
    # Playback state and commands.
    # ------------------------------------------------------------------------
    "lib/playback",

    # ------------------------------------------------------------------------
    # Recovery
    # Recovery and retry.
    # ------------------------------------------------------------------------
    "lib/recovery",

    # ------------------------------------------------------------------------
    # Fallback
    # Backend/line/quality fallback.
    # ------------------------------------------------------------------------
    "lib/fallback",

    # ------------------------------------------------------------------------
    # Cache
    # Memory/disk/cache abstractions.
    # ------------------------------------------------------------------------
    "lib/cache",

    # ------------------------------------------------------------------------
    # Event
    # Player event infrastructure.
    # ------------------------------------------------------------------------
    "lib/event",

    # ------------------------------------------------------------------------
    # Policy
    # All cross-module policies live here.
    # ------------------------------------------------------------------------
    "lib/policy",

    # ------------------------------------------------------------------------
    # Platform
    # Platform abstraction.
    # ------------------------------------------------------------------------
    "lib/platform",

    # ------------------------------------------------------------------------
    # Diagnostics
    # Logging, performance, memory/network diagnostics.
    # ------------------------------------------------------------------------
    "lib/diagnostics",

    # ------------------------------------------------------------------------
    # Recording
    # Recording abstraction.
    # ------------------------------------------------------------------------
    "lib/recording",

    # ------------------------------------------------------------------------
    # Testing
    # Test doubles and test infrastructure.
    # Not exported by media_core.dart.
    # ------------------------------------------------------------------------
    "lib/testing",

    # ------------------------------------------------------------------------
    # Tests
    # ------------------------------------------------------------------------
    "test",

    "test/core",
    "test/reactive",
    "test/error",
    "test/result",
    "test/operation",
    "test/bug",
    "test/identity",
    "test/task",
    "test/state_machine",
    "test/concurrency",
    "test/network",
    "test/source",
    "test/adapter",
    "test/factory",
    "test/session",
    "test/slot",
    "test/pool",
    "test/coordinator",
    "test/reconciler",
    "test/lifecycle",
    "test/visibility",
    "test/preload",
    "test/resource",
    "test/audio",
    "test/presentation",
    "test/renderer",
    "test/geometry",
    "test/playback",
    "test/recovery",
    "test/fallback",
    "test/cache",
    "test/event",
    "test/policy",
    "test/platform",
    "test/diagnostics",
    "test/recording",
    "test/testing",
]


# ============================================================================
# File Structure
# ============================================================================

FILES = [

    # ========================================================================
    # Root
    # ========================================================================

    "lib/media_core.dart",

    # ========================================================================
    # Core
    #
    # Rule:
    #   constants/status -> plain Dart
    #   capabilities      -> Equatable
    #   state/config/info/snapshot/metrics/error -> Freezed
    #   player            -> normal class / interface
    # ========================================================================

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

    # ========================================================================
    # Reactive
    # ========================================================================

    "lib/reactive/reactive.dart",
    "lib/reactive/subject.dart",
    "lib/reactive/behavior.dart",
    "lib/reactive/stream_extensions.dart",
    "lib/reactive/stream_controller.dart",
    "lib/reactive/combine.dart",
    "lib/reactive/debounce.dart",
    "lib/reactive/throttle.dart",
    "lib/reactive/distinct.dart",
    "lib/reactive/stream_cache.dart",
    "lib/reactive/stream_cancellation.dart",
    "lib/reactive/stream_debouncer.dart",
    "lib/reactive/stream_disposable.dart",
    "lib/reactive/stream_event.dart",
    "lib/reactive/stream_gate.dart",
    "lib/reactive/stream_lifecycle.dart",
    "lib/reactive/stream_mutex.dart",
    "lib/reactive/stream_queue.dart",
    "lib/reactive/stream_result.dart",
    "lib/reactive/stream_retry.dart",
    "lib/reactive/stream_safe.dart",
    "lib/reactive/stream_scheduler.dart",
    "lib/reactive/stream_state.dart",
    "lib/reactive/stream_subject.dart",
    "lib/reactive/stream_transform.dart",

    # ========================================================================
    # Error
    # ========================================================================

    "lib/error/player_exception.dart",
    "lib/error/player_failure.dart",
    "lib/error/player_error_code.dart",
    "lib/error/player_error_category.dart",
    "lib/error/error_context.dart",
    "lib/error/error_policy.dart",
    "lib/error/error_classifier.dart",
    "lib/error/error_formatter.dart",

    # ========================================================================
    # Result
    #
    # Single source of truth for operation results.
    # ========================================================================

    "lib/result/result.dart",
    "lib/result/result_error.dart",
    "lib/result/result_status.dart",
    "lib/result/operation_result.dart",
    "lib/result/async_result.dart",

    # ========================================================================
    # Operation
    #
    # NOTE:
    # operation_id.dart removed.
    # operation_result.dart removed.
    #
    # IDs belong to identity/.
    # Results belong to result/.
    # ========================================================================

    "lib/operation/operation.dart",
    "lib/operation/operation_type.dart",
    "lib/operation/operation_state.dart",
    "lib/operation/operation_context.dart",
    "lib/operation/operation_registry.dart",
    "lib/operation/operation_tracker.dart",
    "lib/operation/operation_timeout.dart",
    "lib/operation/operation_cancel_token.dart",

    # ========================================================================
    # Bug / Fault Injection
    # ========================================================================

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

    # ========================================================================
    # Utility
    # ========================================================================

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

    # ========================================================================
    # Identity
    #
    # ALL IDs live here.
    #
    # Value objects should use Equatable.
    # ========================================================================

    "lib/identity/player_id.dart",
    "lib/identity/session_id.dart",
    "lib/identity/slot_id.dart",
    "lib/identity/source_id.dart",
    "lib/identity/operation_id.dart",
    "lib/identity/request_id.dart",
    "lib/identity/generation_id.dart",

    # ========================================================================
    # Task
    #
    # Task is an execution unit.
    # It is different from Operation.
    # ========================================================================

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

    # ========================================================================
    # State Machine
    # ========================================================================

    "lib/state_machine/state_machine.dart",
    "lib/state_machine/state.dart",
    "lib/state_machine/state_transition.dart",
    "lib/state_machine/state_transition_result.dart",
    "lib/state_machine/state_machine_event.dart",
    "lib/state_machine/state_machine_context.dart",
    "lib/state_machine/state_machine_controller.dart",

    # ========================================================================
    # Concurrency
    #
    # Policy is centralized in policy/.
    # ========================================================================

    "lib/concurrency/concurrency_manager.dart",
    "lib/concurrency/concurrency_limit.dart",
    "lib/concurrency/concurrency_key.dart",
    "lib/concurrency/mutex.dart",
    "lib/concurrency/semaphore.dart",
    "lib/concurrency/lock.dart",
    "lib/concurrency/exclusive_task.dart",
    "lib/concurrency/serial_executor.dart",

    # ========================================================================
    # Network
    # ========================================================================

    "lib/network/network_manager.dart",
    "lib/network/network_state.dart",
    "lib/network/network_type.dart",
    "lib/network/network_quality.dart",
    "lib/network/network_monitor.dart",
    "lib/network/network_request.dart",
    "lib/network/network_response.dart",
    "lib/network/network_metrics.dart",
    "lib/network/network_condition.dart",

    # ========================================================================
    # Source
    #
    # NOTE:
    # source_id.dart removed.
    # Source identity belongs to identity/source_id.dart.
    # ========================================================================

    "lib/source/player_source.dart",
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
    "lib/source/source_resolver.dart",
    "lib/source/source_inspector.dart",
    "lib/source/source_validator.dart",

    # ========================================================================
    # Adapter
    # ========================================================================

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

    # ========================================================================
    # Factory
    # ========================================================================

    "lib/factory/player_factory.dart",
    "lib/factory/player_factory_config.dart",
    "lib/factory/backend_factory.dart",
    "lib/factory/backend_registry.dart",
    "lib/factory/backend_selector.dart",
    "lib/factory/backend_descriptor.dart",
    "lib/factory/backend_capabilities.dart",
    "lib/factory/backend_instance.dart",
    "lib/factory/backend_selection_request.dart",
    "lib/factory/backend_selection_result.dart",

    # ========================================================================
    # Session
    #
    # NOTE:
    # session_id.dart removed.
    # Identity belongs to identity/session_id.dart.
    # ========================================================================

    "lib/session/player_session.dart",
    "lib/session/session_generation.dart",
    "lib/session/session_state.dart",
    "lib/session/session_context.dart",
    "lib/session/session_snapshot.dart",
    "lib/session/session_manager.dart",
    "lib/session/session_controller.dart",
    "lib/session/session_lifecycle.dart",
    "lib/session/session_operation.dart",
    "lib/session/session_event.dart",

    # ========================================================================
    # Slot
    # ========================================================================

    "lib/slot/player_slot.dart",
    "lib/slot/player_slot_state.dart",
    "lib/slot/player_slot_manager.dart",
    "lib/slot/player_slot_owner.dart",
    "lib/slot/player_slot_assignment.dart",
    "lib/slot/player_slot_snapshot.dart",

    # ========================================================================
    # Pool
    # ========================================================================

    "lib/pool/player_pool.dart",
    "lib/pool/player_pool_config.dart",
    "lib/pool/player_pool_manager.dart",
    "lib/pool/player_pool_state.dart",
    "lib/pool/player_pool_metrics.dart",
    "lib/pool/player_pool_snapshot.dart",
    "lib/pool/player_pool_allocator.dart",
    "lib/pool/player_pool_recycler.dart",

    # ========================================================================
    # Coordinator
    # ========================================================================

    "lib/coordinator/player_coordinator.dart",
    "lib/coordinator/playback_coordinator.dart",
    "lib/coordinator/page_coordinator.dart",
    "lib/coordinator/audio_coordinator.dart",
    "lib/coordinator/resource_coordinator.dart",
    "lib/coordinator/preload_coordinator.dart",
    "lib/coordinator/lifecycle_coordinator.dart",
    "lib/coordinator/presentation_coordinator.dart",
    "lib/coordinator/global_player_coordinator.dart",

    # ========================================================================
    # Reconciler
    # ========================================================================

    "lib/reconciler/player_reconciler.dart",
    "lib/reconciler/reconcile_action.dart",
    "lib/reconciler/reconcile_state.dart",
    "lib/reconciler/reconcile_queue.dart",
    "lib/reconciler/reconcile_context.dart",
    "lib/reconciler/reconcile_plan.dart",
    "lib/reconciler/reconcile_result.dart",
    "lib/reconciler/reconcile_scheduler.dart",

    # ========================================================================
    # Lifecycle
    #
    # Policy lives in policy/.
    # ========================================================================

    "lib/lifecycle/player_lifecycle.dart",
    "lib/lifecycle/lifecycle_controller.dart",
    "lib/lifecycle/lifecycle_state.dart",
    "lib/lifecycle/lifecycle_observer.dart",
    "lib/lifecycle/lifecycle_event.dart",
    "lib/lifecycle/lifecycle_snapshot.dart",

    # ========================================================================
    # Visibility
    # ========================================================================

    "lib/visibility/visibility_controller.dart",
    "lib/visibility/visibility_observer.dart",
    "lib/visibility/visibility_state.dart",
    "lib/visibility/visibility_event.dart",
    "lib/visibility/visibility_snapshot.dart",
    "lib/visibility/visibility_metrics.dart",

    # ========================================================================
    # Preload
    # ========================================================================

    "lib/preload/preload_manager.dart",
    "lib/preload/preload_task.dart",
    "lib/preload/preload_scheduler.dart",
    "lib/preload/preload_priority.dart",
    "lib/preload/preload_state.dart",
    "lib/preload/preload_request.dart",
    "lib/preload/preload_context.dart",
    "lib/preload/preload_metrics.dart",

    # ========================================================================
    # Resource
    # ========================================================================

    "lib/resource/resource_manager.dart",
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

    # ========================================================================
    # Audio
    # ========================================================================

    "lib/audio/audio_manager.dart",
    "lib/audio/audio_focus.dart",
    "lib/audio/audio_focus_state.dart",
    "lib/audio/audio_session.dart",
    "lib/audio/audio_session_state.dart",
    "lib/audio/audio_coordinator.dart",
    "lib/audio/audio_route.dart",
    "lib/audio/audio_volume.dart",
    "lib/audio/audio_mute.dart",

    # ========================================================================
    # Presentation
    # ========================================================================

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

    # ========================================================================
    # Renderer
    # ========================================================================

    "lib/renderer/player_renderer.dart",
    "lib/renderer/player_view.dart",
    "lib/renderer/player_surface.dart",
    "lib/renderer/player_overlay.dart",
    "lib/renderer/renderer_config.dart",
    "lib/renderer/renderer_state.dart",
    "lib/renderer/renderer_capabilities.dart",
    "lib/renderer/renderer_controller.dart",

    # ========================================================================
    # Geometry
    # ========================================================================

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

    # ========================================================================
    # Playback
    # ========================================================================

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

    # ========================================================================
    # Recovery
    #
    # Policy lives in policy/.
    # ========================================================================

    "lib/recovery/recovery_manager.dart",
    "lib/recovery/recovery_action.dart",
    "lib/recovery/recovery_state.dart",
    "lib/recovery/recovery_reason.dart",
    "lib/recovery/recovery_context.dart",
    "lib/recovery/recovery_snapshot.dart",
    "lib/recovery/retry_scheduler.dart",
    "lib/recovery/retry_state.dart",

    # ========================================================================
    # Fallback
    # ========================================================================

    "lib/fallback/fallback_manager.dart",
    "lib/fallback/backend_fallback.dart",
    "lib/fallback/backend_fallback_state.dart",
    "lib/fallback/line_fallback.dart",
    "lib/fallback/line_fallback_state.dart",
    "lib/fallback/quality_fallback.dart",
    "lib/fallback/quality_fallback_state.dart",
    "lib/fallback/fallback_reason.dart",
    "lib/fallback/fallback_context.dart",
    "lib/fallback/fallback_result.dart",

    # ========================================================================
    # Cache
    #
    # Policy lives in policy/.
    # ========================================================================

    "lib/cache/cache_manager.dart",
    "lib/cache/cache_entry.dart",
    "lib/cache/cache_key.dart",
    "lib/cache/cache_state.dart",
    "lib/cache/cache_result.dart",
    "lib/cache/memory_cache.dart",
    "lib/cache/disk_cache.dart",
    "lib/cache/cache_storage.dart",
    "lib/cache/cache_eviction.dart",
    "lib/cache/cache_metrics.dart",

    # ========================================================================
    # Event
    # ========================================================================

    "lib/event/player_event.dart",
    "lib/event/player_event_type.dart",
    "lib/event/player_event_bus.dart",
    "lib/event/event_dispatcher.dart",
    "lib/event/event_context.dart",
    "lib/event/event_priority.dart",
    "lib/event/event_filter.dart",
    "lib/event/event_subscription.dart",

    # ========================================================================
    # Policy
    #
    # SINGLE source of truth for policies.
    # ========================================================================

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
    "lib/policy/cache_policy.dart",
    "lib/policy/policy_context.dart",

    # ========================================================================
    # Platform
    # ========================================================================

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

    # ========================================================================
    # Diagnostics
    #
    # IMPORTANT:
    # player_metrics.dart is NOT duplicated here.
    # Public PlayerMetrics belongs to core/.
    # Diagnostics contains diagnostic-specific samples/snapshots.
    # ========================================================================

    "lib/diagnostics/player_logger.dart",
    "lib/diagnostics/log_level.dart",
    "lib/diagnostics/log_category.dart",
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

    # ========================================================================
    # Recording
    # ========================================================================

    "lib/recording/recording_manager.dart",
    "lib/recording/recording_config.dart",
    "lib/recording/recording_session.dart",
    "lib/recording/recording_state.dart",
    "lib/recording/recording_source.dart",
    "lib/recording/recording_format.dart",
    "lib/recording/recording_result.dart",
    "lib/recording/recording_error.dart",
    "lib/recording/recording_backend.dart",

    # ========================================================================
    # Testing
    #
    # Internal testing infrastructure.
    # Do not export from media_core.dart.
    # ========================================================================

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

    # ========================================================================
    # Tests
    # ========================================================================

    "test/media_core_test.dart",

    # Core
    "test/core/player_state_test.dart",
    "test/core/player_config_test.dart",
    "test/core/player_error_test.dart",
    "test/core/player_capabilities_test.dart",
    "test/core/player_snapshot_test.dart",

    # Reactive
    "test/reactive/stream_extensions_test.dart",
    "test/reactive/subject_test.dart",
    "test/reactive/behavior_test.dart",

    # Error
    "test/error/player_exception_test.dart",
    "test/error/player_failure_test.dart",
    "test/error/error_classifier_test.dart",
    "test/error/error_formatter_test.dart",

    # Result
    "test/result/result_test.dart",
    "test/result/operation_result_test.dart",
    "test/result/async_result_test.dart",

    # Operation
    "test/operation/operation_registry_test.dart",
    "test/operation/operation_tracker_test.dart",
    "test/operation/operation_timeout_test.dart",
    "test/operation/operation_cancel_token_test.dart",

    # Bug
    "test/bug/bug_mode_test.dart",
    "test/bug/fault_injector_test.dart",

    # Identity
    "test/identity/player_id_test.dart",
    "test/identity/session_id_test.dart",
    "test/identity/source_id_test.dart",
    "test/identity/operation_id_test.dart",
    "test/identity/request_id_test.dart",
    "test/identity/generation_id_test.dart",

    # Task
    "test/task/player_task_test.dart",
    "test/task/task_queue_test.dart",
    "test/task/task_scheduler_test.dart",
    "test/task/task_manager_test.dart",
    "test/task/task_cancel_token_test.dart",

    # State Machine
    "test/state_machine/state_machine_test.dart",

    # Concurrency
    "test/concurrency/mutex_test.dart",
    "test/concurrency/semaphore_test.dart",
    "test/concurrency/serial_executor_test.dart",

    # Network
    "test/network/network_state_test.dart",
    "test/network/network_request_test.dart",
    "test/network/network_manager_test.dart",

    # Source
    "test/source/player_source_test.dart",
    "test/source/source_inspector_test.dart",
    "test/source/source_validator_test.dart",

    # Adapter
    "test/adapter/player_adapter_test.dart",

    # Factory
    "test/factory/player_factory_test.dart",
    "test/factory/backend_registry_test.dart",

    # Session
    "test/session/player_session_test.dart",
    "test/session/session_generation_test.dart",
    "test/session/session_manager_test.dart",

    # Slot
    "test/slot/player_slot_test.dart",

    # Pool
    "test/pool/player_pool_test.dart",

    # Coordinator
    "test/coordinator/player_coordinator_test.dart",

    # Reconciler
    "test/reconciler/player_reconciler_test.dart",

    # Lifecycle
    "test/lifecycle/lifecycle_controller_test.dart",

    # Visibility
    "test/visibility/visibility_controller_test.dart",

    # Preload
    "test/preload/preload_manager_test.dart",

    # Resource
    "test/resource/resource_manager_test.dart",

    # Audio
    "test/audio/audio_manager_test.dart",

    # Presentation
    "test/presentation/presentation_controller_test.dart",

    # Renderer
    "test/renderer/renderer_controller_test.dart",

    # Geometry
    "test/geometry/video_geometry_test.dart",

    # Playback
    "test/playback/playback_controller_test.dart",
    "test/playback/playback_position_test.dart",

    # Recovery
    "test/recovery/recovery_manager_test.dart",

    # Fallback
    "test/fallback/fallback_manager_test.dart",

    # Cache
    "test/cache/cache_manager_test.dart",

    # Event
    "test/event/player_event_bus_test.dart",

    # Policy
    "test/policy/player_policy_test.dart",

    # Platform
    "test/platform/platform_capabilities_test.dart",

    # Diagnostics
    "test/diagnostics/diagnostics_manager_test.dart",

    # Recording
    "test/recording/recording_manager_test.dart",

    # Testing
    "test/testing/fake_player_test.dart",
]


# ============================================================================
# Freezed / JSON generated files
#
# These files are intentionally NOT created by this script.
# build_runner generates them after Dart implementations are added.
#
# Examples:
#
#   player_state.freezed.dart
#   player_state.g.dart
#   player_config.freezed.dart
#   player_config.g.dart
#
# Run:
#
#   dart run build_runner build --delete-conflicting-outputs
#
# ============================================================================


def create_directories() -> None:
    """Create all package directories."""
    for directory in DIRECTORIES:
        path = PACKAGE_ROOT / directory
        path.mkdir(parents=True, exist_ok=True)


def create_files() -> None:
    """Create empty Dart files without overwriting existing files."""
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
    """Print package statistics."""
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

    dart_files = [
        p for p in files
        if p.suffix == ".dart"
    ]

    generated_files = [
        p for p in files
        if p.name.endswith(".freezed.dart")
        or p.name.endswith(".g.dart")
    ]

    print(f"Package root:       {PACKAGE_ROOT}")
    print(f"Directories:        {len(directories)}")
    print(f"Files:              {len(files)}")
    print(f"Dart files:         {len(dart_files)}")
    print(f"Generated files:    {len(generated_files)}")
    print()


def print_architecture() -> None:
    """Print architecture rules."""
    print()
    print("=" * 72)
    print("Architecture Rules")
    print("=" * 72)

    print()
    print("1. Identity")
    print("   All cross-module IDs live in lib/identity/.")

    print()
    print("2. Result")
    print("   All generic operation results live in lib/result/.")

    print()
    print("3. Policy")
    print("   All policies live in lib/policy/.")

    print()
    print("4. Core")
    print("   Public player API and fundamental models live in lib/core/.")

    print()
    print("5. Value Objects")
    print("   Prefer Equatable for small immutable value objects.")

    print()
    print("6. Immutable Models")
    print("   Prefer Freezed + json_serializable for state/config/snapshot/DTO.")

    print()
    print("7. Managers / Controllers")
    print("   Use normal classes. Do not use Equatable for lifecycle objects.")

    print()
    print("8. Reactive")
    print("   RxDart is the underlying reactive implementation.")

    print()
    print("9. Time")
    print("   Prefer clock.now() over DateTime.now() in testable code.")

    print()
    print("10. Async")
    print("    Prefer async package primitives where appropriate.")

    print()
    print("11. Testing")
    print("    lib/testing is internal testing infrastructure.")

    print()
    print("12. Generated files")
    print("    *.freezed.dart and *.g.dart are generated by build_runner.")

    print()
    print("13. No duplicated IDs")
    print("    Do not create operation/session/source ID classes elsewhere.")

    print()
    print("14. No duplicated policies")
    print("    Do not create module-local *_policy.dart files.")

    print()
    print("15. No duplicated PlayerMetrics")
    print("    Public PlayerMetrics belongs to lib/core/.")


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
    print_architecture()

    print()
    print("=" * 72)
    print("Generation completed.")
    print("=" * 72)
    print()

    print("No Dart implementation code was generated.")
    print("All newly created Dart files are empty.")
    print()

    print("Important:")
    print("  Existing files are never overwritten.")
    print("  Remove obsolete files manually if they already exist.")
    print()

    print("Package:")
    print(f"  {PROJECT_NAME}")
    print()

    print("Next steps:")
    print()
    print("  flutter pub get")
    print()
    print("  dart run build_runner build --delete-conflicting-outputs")
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