/// DLNA/UPnP casting backend for media_core.
///
/// An independent, complete DLNA/UPnP control-point core — SSDP
/// discovery, device and service description parsing, SOAP control
/// with typed UPnP error mapping — layered as domain / application /
/// infrastructure per TECHNICAL_DESIGN.md, plus DlnaCastBackend,
/// the adapter that presents it behind media_core's protocol-neutral
/// MediaCastBackend.
///
/// Delivery status (see TECHNICAL_DESIGN.md §27): phases 0-9 complete —
/// discovery, description parsing, SOAP control, capability negotiation,
/// the media server, cast sessions with playback control, GENA event
/// subscription, RenderingControl with recovery, the vendor
/// compatibility layer, structured logging and diagnostics. Phase 10
/// (multi-platform real-device matrix and release hardening) is the
/// remaining gate.
library;

export 'src/adapter/didl_lite.dart';
export 'src/adapter/dlna_cast_backend.dart';
export 'src/application/device/dlna_device_registry.dart';
export 'src/application/discovery/dlna_discovery_manager.dart';
export 'src/application/discovery/dlna_discovery_options.dart';
export 'src/application/dlna_client.dart';
export 'src/application/dlna_diagnostics.dart';
export 'src/application/media/dlna_capability_resolver.dart';
export 'src/application/media/dlna_media_selector.dart';
export 'src/application/playback/dlna_command_queue.dart';
export 'src/application/playback/dlna_playback_controller.dart';
export 'src/application/playback/dlna_playback_monitor.dart';
export 'src/application/session/dlna_recovery_policy.dart';
export 'src/application/session/dlna_session.dart';
export 'src/application/session/dlna_session_manager.dart';
export 'src/domain/contracts/soap_transport.dart';
export 'src/domain/entities/dlna_device.dart';
export 'src/domain/entities/dlna_media.dart';
export 'src/domain/entities/dlna_media_capability.dart';
export 'src/domain/entities/dlna_media_resource.dart';
export 'src/domain/entities/dlna_media_selection.dart';
export 'src/domain/entities/dlna_playback_state.dart';
export 'src/domain/entities/dlna_service.dart';
export 'src/domain/enums/dlna_connection_state.dart';
export 'src/domain/enums/dlna_discovery_state.dart';
export 'src/domain/enums/dlna_media_type.dart';
export 'src/domain/enums/dlna_transport_state.dart';
export 'src/domain/enums/upnp_error_code.dart';
export 'src/domain/exceptions/dlna_exception.dart';
export 'src/domain/value_objects/media_protocol_info.dart';
export 'src/domain/value_objects/service_type.dart';
export 'src/infrastructure/compatibility/device_compatibility.dart';
export 'src/infrastructure/control/gena/gena_callback_server.dart';
export 'src/infrastructure/control/gena/gena_message_parser.dart';
export 'src/infrastructure/control/gena/gena_subscriber.dart';
export 'src/infrastructure/control/http_soap_transport.dart';
export 'src/infrastructure/control/services/av_transport_service.dart';
export 'src/infrastructure/control/services/rendering_control_service.dart';
export 'src/infrastructure/control/soap/didl_metadata.dart';
export 'src/infrastructure/control/soap/soap_client.dart';
export 'src/infrastructure/control/soap/soap_fault_parser.dart';
export 'src/infrastructure/control/soap/soap_request_builder.dart';
export 'src/infrastructure/control/soap/soap_response_parser.dart';
export 'src/infrastructure/description/description_http_fetcher.dart';
export 'src/infrastructure/description/device_description_parser.dart';
export 'src/infrastructure/description/service_description_parser.dart';
export 'src/infrastructure/discovery/bonsoir/bonsoir_discovery.dart';
export 'src/infrastructure/discovery/ssdp/ssdp_client.dart';
export 'src/infrastructure/discovery/ssdp/ssdp_constants.dart';
export 'src/infrastructure/discovery/ssdp/ssdp_message.dart';
export 'src/infrastructure/discovery/ssdp/ssdp_search.dart';
export 'src/infrastructure/media/http/media_http_handler.dart';
export 'src/infrastructure/media/http/media_http_range.dart';
export 'src/infrastructure/media/http/media_http_server.dart';
export 'src/infrastructure/media/http/media_resource_registry.dart';
export 'src/infrastructure/media/http/remote_proxy_handler.dart';
export 'src/infrastructure/media/http/remote_proxy_registry.dart';
export 'src/infrastructure/network/ip_address_selector.dart';
export 'src/logging/dlna_log.dart';
export 'src/utils/duration_parser.dart';
export 'src/utils/mime_type.dart';
