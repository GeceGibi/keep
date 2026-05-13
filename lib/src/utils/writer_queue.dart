part of 'utils.dart';

/// A helper to manage debounced and queued side-effect operations (like
/// writes).
///
/// This class ensures that operations with the same [id] are:
/// 1. **Debounced** — Rapid successive calls cancel previous pending timers so
///    only the latest action's body executes against disk.
/// 2. **Queued** — Operations execute sequentially per [id], waiting for any
///    in-flight previous operation to complete before starting.
/// 3. **Durable for awaiters** — When a pending call is superseded by a newer
///    one (debounced), the original caller's future is NOT silently completed
///    with `null`. Instead it is chained to the next operation that actually
///    runs; the awaiter only resolves once the successor has flushed to disk.
///    This preserves the invariant that `await write()` returning means the
///    underlying data is persistent.
@internal
class KeepWriteQueue {
  /// Currently scheduled (timer not yet fired) operations, keyed by [id].
  final Map<String, _PendingOp<dynamic>> _pendingOps = {};

  /// In-flight operations whose action is currently running, keyed by [id].
  final Map<String, Future<dynamic>> _activeOperations = {};

  /// Completers from operations that were superseded by a newer pending op for
  /// the same [id]. They are resolved (with the same result/error) when the
  /// next successor for that [id] finishes executing, so awaiters see durable
  /// completion instead of a phantom `null`.
  final Map<String, List<Completer<dynamic>>> _supersededCompleters = {};

  bool _disposed = false;

  /// Runs an [action] for the given [id] with an optional [delay].
  ///
  /// Behaviour:
  /// - If another pending op for [id] exists, its timer is cancelled and its
  ///   completer is chained: it will resolve with the result of whichever
  ///   newer op eventually runs to completion.
  /// - Once [delay] elapses, the action joins a sequential queue per [id] and
  ///   waits for any active op to finish before executing.
  ///
  /// The returned [Future] only completes after the action (or a successor
  /// that supersedes it) has finished, providing strong durability semantics
  /// for callers.
  Future<T> run<T>({
    required String id,
    required Future<T> Function() action,
    Duration delay = Duration.zero,
    void Function(KeepException<dynamic> error)? onError,
  }) {
    final completer = Completer<T>();

    if (_disposed) {
      completer.completeError(
        const KeepException<dynamic>(
          'KeepWriteQueue.run called after dispose().',
        ),
      );
      return completer.future;
    }

    // Debounce: transfer the previous pending op's completer to the
    // superseded list. It will be completed when the next successor finishes.
    final existing = _pendingOps.remove(id);
    if (existing != null) {
      existing.timer.cancel();
      _supersededCompleters
          .putIfAbsent(id, () => <Completer<dynamic>>[])
          .add(existing.completer);
    }

    final timer = Timer(delay, () {
      _pendingOps.remove(id);
      unawaited(_executeQueued(id, action, completer, onError));
    });

    _pendingOps[id] = _PendingOp(timer: timer, completer: completer);
    return completer.future;
  }

  /// Executes [action] sequentially per [id]. Waits for any previous active
  /// op to finish (ignoring its error), then runs and propagates the result to
  /// both this op's completer and any superseded completers.
  Future<void> _executeQueued<T>(
    String id,
    Future<T> Function() action,
    Completer<T> completer,
    void Function(KeepException<dynamic> error)? onError,
  ) async {
    final previousOperation = _activeOperations[id];
    if (previousOperation != null) {
      await previousOperation.catchError((Object _) {});
    }

    final currentOperationCompleter = Completer<T>();
    _activeOperations[id] = currentOperationCompleter.future;

    try {
      final result = await action();

      if (!currentOperationCompleter.isCompleted) {
        currentOperationCompleter.complete(result);
      }
      // Resolve superseded BEFORE the current op's completer so that
      // microtask order matches original call order: the supersede list is
      // stored in call order [C0, C1, ..., Cn-1] and the current op is the
      // most recent caller Cn. Completing Cn last guarantees that any
      // post-await side effect installed by callers (e.g. cache writes,
      // listener notifications) ends up reflecting the most recent intent.
      _resolveSuperseded(id, result: result);
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    } catch (error, stackTrace) {
      final exception = error is KeepException
          ? error
          : KeepException<dynamic>(
              error.toString(),
              error: error,
              stackTrace: stackTrace,
            );

      onError?.call(exception);

      if (!currentOperationCompleter.isCompleted) {
        currentOperationCompleter.completeError(exception, stackTrace);
      }
      // Same call-order rationale as the success path above.
      _resolveSuperseded(id, error: exception, stackTrace: stackTrace);
      if (!completer.isCompleted) {
        completer.completeError(exception, stackTrace);
      }
    } finally {
      if (identical(_activeOperations[id], currentOperationCompleter.future)) {
        _activeOperations.remove(id);
      }
    }
  }

  /// Completes any superseded completers waiting on [id] using the successor's
  /// outcome. Type-unsafe completions (different `T`) fall back to `null` or
  /// finally to an error if neither is assignable.
  void _resolveSuperseded(
    String id, {
    Object? result,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final list = _supersededCompleters.remove(id);
    if (list == null) return;

    for (final c in list) {
      if (c.isCompleted) continue;
      if (error != null) {
        c.completeError(error, stackTrace);
        continue;
      }
      try {
        c.complete(result);
      } catch (_) {
        try {
          c.complete(null);
        } catch (_) {
          c.completeError(
            const KeepException<dynamic>(
              'Superseded operation result type mismatch.',
            ),
          );
        }
      }
    }
  }

  /// Awaits any in-flight (active or pending) operation for [id] without
  /// participating in the debounce queue.
  ///
  /// Intended for read paths that need to observe the latest committed write
  /// but must NOT be debounced themselves. Reads call [awaitSettled] then
  /// touch the underlying store directly.
  Future<void> awaitSettled(String id) async {
    final active = _activeOperations[id];
    if (active != null) {
      await active.catchError((Object _) {});
    }
    final pending = _pendingOps[id];
    if (pending != null) {
      await pending.completer.future.catchError((Object _) => null);
    }
  }

  /// Awaits ALL outstanding operations across every [id] to settle without
  /// cancelling anything.
  ///
  /// This is the safe way to ensure durability before tearing down: call
  /// [flush] before [dispose] so that pending writes are not lost.
  ///
  /// Loops because new ops can be scheduled while we're awaiting (e.g. an
  /// active op enqueues a successor). Returns once the queue is drained.
  Future<void> flush() async {
    while (_pendingOps.isNotEmpty || _activeOperations.isNotEmpty) {
      final futures = <Future<void>>[
        for (final f in _activeOperations.values.toList())
          f.then<void>((Object? _) {}, onError: (Object _) {}),
        for (final op in _pendingOps.values.toList())
          op.completer.future
              .then<void>((Object? _) {}, onError: (Object _) {}),
      ];
      if (futures.isEmpty) break;
      await Future.wait(futures);
    }
  }

  /// Abandons all pending operations and prevents further [run] calls.
  ///
  /// Pending and superseded completers are completed with a `KeepException`
  /// so awaiting callers fail fast instead of hanging forever. Callers that
  /// need durability must invoke [flush] BEFORE [dispose].
  void dispose() {
    _disposed = true;

    final abandoned = const KeepException<dynamic>(
      'KeepWriteQueue disposed before pending operation completed.',
    );

    for (final op in _pendingOps.values) {
      op.timer.cancel();
      if (!op.completer.isCompleted) {
        op.completer.completeError(abandoned);
      }
    }
    _pendingOps.clear();

    for (final list in _supersededCompleters.values) {
      for (final c in list) {
        if (!c.isCompleted) {
          c.completeError(abandoned);
        }
      }
    }
    _supersededCompleters.clear();

    _activeOperations.clear();
  }
}

/// Holds a pending debounced operation: its timer and the completer returned
/// to the original caller of [KeepWriteQueue.run].
class _PendingOp<T> {
  _PendingOp({required this.timer, required this.completer});

  /// The timer that will execute the operation once the debounce delay
  /// elapses. Cancelled when the op is superseded or the queue is disposed.
  final Timer timer;

  /// The future surfaced to the caller of [KeepWriteQueue.run]. May be
  /// completed by either the op's own [_executeQueued] invocation or, when
  /// superseded, by [KeepWriteQueue._resolveSuperseded] using a later op's
  /// outcome.
  final Completer<T> completer;
}
