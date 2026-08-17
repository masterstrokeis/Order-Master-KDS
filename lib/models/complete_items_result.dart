/// Outcome of [OrderController.completeItems] batch completion.
class CompleteItemsResult {
  const CompleteItemsResult({
    required this.completed,
    required this.skippedNotStarted,
    required this.failedDisplayNumbers,
  });

  final int completed;
  final int skippedNotStarted;
  final List<String> failedDisplayNumbers;

  int get failed => failedDisplayNumbers.length;

  int get attempted => completed + skippedNotStarted + failed;
}
