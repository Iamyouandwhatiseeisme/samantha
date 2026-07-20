import 'package:samantha/common/extensions/context_x.dart';
import 'package:flutter/widgets.dart';

String formatErrorMessage(String raw, BuildContext context) {
  final lower = raw.toLowerCase();

  if (lower.contains('connection refused') ||
      lower.contains('failed to connect') ||
      lower.contains('connection failed') ||
      lower.contains('no route to host') ||
      lower.contains('network is unreachable')) {
    return context.l10n.errorCouldNotReachServer;
  }

  if (lower.contains('timed out') || lower.contains('timeout')) {
    return context.l10n.errorServerDidNotRespond;
  }

  if (lower.contains('authentication failed') || lower.contains('auth failed')) {
    return context.l10n.errorInvalidAuthToken;
  }

  if (lower.contains('not configured')) {
    return context.l10n.errorEnterConnectionDetails;
  }

  if (lower.contains('websocket') && lower.contains('failed')) {
    return context.l10n.errorCouldNotEstablishConnection;
  }

  if (lower.contains('invalid response') || lower.contains('failed to parse')) {
    return context.l10n.errorInvalidResponseFromServer;
  }

  if (lower.contains('connection lost') || lower.contains('stream closed')) {
    return context.l10n.errorConnectionLost;
  }

  return context.l10n.errorSomethingWentWrong;
}
