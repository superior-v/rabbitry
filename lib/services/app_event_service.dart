import 'package:flutter/foundation.dart';

/// Global event notifier for instant UI updates across all screens
/// when data (rabbits, litters, tasks, photos, breeding) changes.
final ValueNotifier<int> dataChangeNotifier = ValueNotifier<int>(0);

void notifyDataChanged() {
  dataChangeNotifier.value++;
}
