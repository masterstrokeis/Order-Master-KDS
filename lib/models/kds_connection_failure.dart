/// Transport-level failure: request timed out or the server was unreachable.
///
/// Distinct from [KdsApiError] so UI can treat connectivity separately from
/// API outcomes such as wrong PIN.
class KdsConnectionFailure implements Exception {
  const KdsConnectionFailure([
    this.message = 'Could not reach the server. Check connection and try again.',
  ]);

  final String message;

  @override
  String toString() => 'KdsConnectionFailure: $message';
}
