part of 'vault.dart';

/// A widget that rebuilds when the given [vaultKey] changes.
///
/// This widget combines a [FutureBuilder] for the initial read and a [StreamBuilder]
/// for subsequent updates, ensuring the UI always reflects the latest state of the key.
class VaultBuilder<T> extends StatelessWidget {
  const VaultBuilder({
    super.key,
    required this.vaultKey,
    required this.builder,
  });

  final VaultKey<T> vaultKey;
  final Widget Function(BuildContext context, T? value) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T?>(
      initialData: null,
      future: vaultKey.read(),
      builder: (context, futureSnap) {
        return StreamBuilder<T?>(
          stream: vaultKey.stream,
          initialData: futureSnap.data,
          builder: (context, streamSnap) {
            final data = streamSnap.hasData ? streamSnap.data : futureSnap.data;
            return builder(context, data);
          },
        );
      },
    );
  }
}
