import 'package:flutter/material.dart';

/// Keep controllers alive until the closing transition has removed the dialog.
Future<T?> showSettledDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final route = DialogRoute<T>(context: context, builder: builder);
  final value = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  return value;
}
