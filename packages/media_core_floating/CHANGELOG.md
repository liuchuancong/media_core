## 0.1.0

Initial release.

- In-app small window: `FloatingSessionController` manages the handover between a page and the floating window (show / hide / toggle); `FloatingWindowOverlay` is the widget that renders the draggable video surface inside a `Stack`.
- `FloatingDriver` implements `KernelPresentationDriver`, serving `PresentationMode.floating` and publishing `onFloatingChanged` so the overlay visibility is reactive.
- Pure geometry: `FloatingWindowPlacement` computes anchor placement, drag clamping, edge snapping and resize; `FloatingAnchor` names the positions (four corners + center-left / center-right). All testable without rendering.
- Configuration split from presentation: `FloatingConfig` declares behaviour (dismissible, keepPlayingWhenHidden), `FloatingPlacementConfig` declares size, margins, snapping threshold, resize handles and aspect-ratio binding.
- Auto-enter: `FloatingAutoEnterPolicy` controls whether the window opens on page exit (default on) or app background (default off, since an in-app overlay is invisible when the app is not on screen).
- Host escape hatch: `FloatingWindowPresenter` interface lets a host install its own surface (a separate platform window, a system overlay) while sharing the same `isFloating` / `onFloatingChanged` state.
