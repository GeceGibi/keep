part of 'vault.dart';

/// A reactive widget that rebuilds when the value of a [VaultKey] changes.
class VaultBuilder<T> extends StatelessWidget {
  /// Creates a [VaultBuilder].
  ///
  /// [vaultKey] The key to listen to.
  /// [builder] Callback that receives the latest value and returns a widget.
  const VaultBuilder({
    required this.vaultKey,
    required this.builder,
    super.key,
  });

  /// The vault key to monitor for changes.
  final VaultKey<T> vaultKey;

  /// The builder function used to construct the UI based on the key's value.
  final Widget Function(BuildContext context, T? value) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: vaultKey.stream,
      builder: (context, snapshot) {
        return FutureBuilder(
          future: vaultKey.read(),
          builder: (context, snapshot) {
            return builder(context, snapshot.data);
          },
        );
      },
    );
  }
}
