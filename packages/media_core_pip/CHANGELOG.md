## 0.1.0

Initial release.

- Picture-in-picture: a desktop always-on-top small window and the Android system PiP window, both behind the `PipPlatform` abstraction so hosts get one controller either way.
- Android system window: entering and leaving is described by `SystemPipTrigger`, and the state comes back through `SystemPipStatus`, so host UI never has to ask the system directly.
- Desktop implementations: `WindowManagerPipWindow` (window level) and `FloatingSystemPip` (overlay level), switched and tracked by `PipController`.
- Works with `media_core_presentation`: PiP is one presentation state, so entering it exits the others.
