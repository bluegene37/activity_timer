import 'package:flutter/material.dart';

/// Shows messages and dialogs from places that have no `BuildContext`.
///
/// Controllers must not import Flutter's widget tree, but they do need to
/// report a failed save. GetX solved this with `Get.snackbar` reaching into
/// a global context; this keeps the same convenience without the global —
/// the app installs its keys once at startup, and everything else talks to
/// this narrow interface.
class UiMessenger {
  factory UiMessenger() => _instance;

  UiMessenger._internal();

  static final UiMessenger _instance = UiMessenger._internal();

  /// Installed on `MaterialApp.scaffoldMessengerKey`.
  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Installed on the router so dialogs can be raised without a context.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Test seam: when set, messages are recorded here instead of shown.
  List<String>? recorder;

  BuildContext? get _context => navigatorKey.currentContext;

  /// A transient message — a failed save, a rejected import.
  void showMessage(String message, {String? title}) {
    final text = title == null ? message : '$title: $message';
    final record = recorder;
    if (record != null) {
      record.add(text);
      return;
    }
    messengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  /// A yes/no question. Returns false when the user dismisses it, and when
  /// there is no UI to ask with — callers treat that as "do not proceed".
  Future<bool> confirm({
    required String title,
    required String message,
    String confirmLabel = 'OK',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final context = _context;
    if (context == null) {
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(cancelLabel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style:
                    isDestructive
                        ? TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(dialogContext).colorScheme.error,
                        )
                        : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  /// Raises an arbitrary dialog from a place with no context.
  Future<T?> showDialogBuilder<T>(WidgetBuilder builder) async {
    final context = _context;
    if (context == null) {
      return null;
    }
    return showDialog<T>(context: context, builder: builder);
  }
}
