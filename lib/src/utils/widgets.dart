part of 'utils.dart';

/// A reactive widget that rebuilds when the value of a [KeepKey] changes.
class KeepBuilder<T> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: keepKey,
      builder: (context, snapshot) {
        return FutureBuilder(
          future: keepKey.read(),
          builder: (context, snapshot) {
            return builder(context, snapshot.data);
          },
        );
      },
    );
  }
}
