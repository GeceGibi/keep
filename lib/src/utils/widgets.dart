part of 'utils.dart';

/// A reactive widget that rebuilds when the value of a [KeepKey] changes.
///
/// Unlike a `StreamBuilder<FutureBuilder>` combination, [KeepBuilder] holds
/// the latest value in widget state. This avoids re-issuing a `read()` future
/// on every parent rebuild (the classic FutureBuilder-in-build anti-pattern)
/// and prevents transient `null` frames while the future resolves.
class KeepBuilder<T> extends StatefulWidget {
  /// Creates a [KeepBuilder].
  ///
  /// [keepKey] The key to listen to.
  /// [builder] Callback that receives the latest value and returns a widget.
  const KeepBuilder({
    required this.keepKey,
    required this.builder,
    super.key,
  });

  /// The keep key to monitor for changes.
  final KeepKey<T> keepKey;

  /// The builder function used to construct the UI based on the key's value.
  final Widget Function(BuildContext context, T? value) builder;

  @override
  State<KeepBuilder<T>> createState() => _KeepBuilderState<T>();
}

class _KeepBuilderState<T> extends State<KeepBuilder<T>> {
  T? _value;
  StreamSubscription<KeepKey<T>>? _sub;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    // Fast path: surface any cached value synchronously so we don't render an
    // initial null frame when the value is already known.
    try {
      _value = widget.keepKey.readSync();
    } catch (_) {
      _value = null;
    }

    _sub?.cancel();
    _sub = widget.keepKey.stream.listen((_) => _load());

    // Always kick off an async read; this also covers the case where the
    // owning Keep instance has not finished initializing yet.
    _load();
  }

  Future<void> _load() async {
    try {
      final next = await widget.keepKey.read();
      if (!mounted) return;
      if (!_valuesEqual(next, _value)) {
        setState(() => _value = next);
      }
    } catch (_) {
      // Errors are already surfaced through Keep.onError; the UI keeps the
      // last known value rather than throwing during build.
    }
  }

  static bool _valuesEqual(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a == b;
  }

  @override
  void didUpdateWidget(covariant KeepBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.keepKey, widget.keepKey)) {
      _attach();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
