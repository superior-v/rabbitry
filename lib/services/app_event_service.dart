import 'package:flutter/foundation.dart';

/// Global event notifier for instant UI updates across all screens
/// when data (rabbits, litters, tasks, photos, breeding) changes.
final ValueNotifier<int> dataChangeNotifier = ValueNotifier<int>(0);

void notifyDataChanged() {
  dataChangeNotifier.value++;
}

/// Tracks transient external intents (camera/gallery/file picker, print/share)
/// so returning from those system dialogs does not reset the app back to Home.
int _externalActivityDepth = 0;

bool get isExternalActivityActive => _externalActivityDepth > 0;

Future<T> runExternalActivity<T>(Future<T> Function() action) async {
  _externalActivityDepth++;
  try {
    return await action();
  } finally {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (_externalActivityDepth > 0) _externalActivityDepth--;
    });
  }
}
