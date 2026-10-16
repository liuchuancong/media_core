/// Test doubles for hosts that drive a player under test.
///
/// Deliberately absent from `media_core.dart`: an app must not be able to reach
/// a fake through the library it already imports. Take this library rather than
/// `package:media_core/testing/<file>.dart`, which is a directory layout and not
/// an API contract.
library;

export 'package:media_core/testing/library.dart';
