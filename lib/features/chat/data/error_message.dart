String formatErrorMessage(String raw) {
  final lower = raw.toLowerCase();

  if (lower.contains('connection refused') ||
      lower.contains('failed to connect') ||
      lower.contains('connection failed') ||
      lower.contains('no route to host') ||
      lower.contains('network is unreachable')) {
    return 'Could not reach the server';
  }

  if (lower.contains('timed out') || lower.contains('timeout')) {
    return 'Server did not respond in time';
  }

  if (lower.contains('authentication failed') || lower.contains('auth failed')) {
    return 'Invalid auth token';
  }

  if (lower.contains('not configured')) {
    return 'Please enter your connection details';
  }

  if (lower.contains('websocket') && lower.contains('failed')) {
    return 'Could not establish connection';
  }

  if (lower.contains('invalid response') || lower.contains('failed to parse')) {
    return 'Received invalid response from server';
  }

  if (lower.contains('connection lost') || lower.contains('stream closed')) {
    return 'Connection lost';
  }

  return 'Something went wrong. Please try again.';
}
