part of 'vault.dart';

class VaultBuilder<T> extends StatelessWidget {
  const VaultBuilder({
    super.key,
    required this.vaultKey,
    required this.builder,
  });

  final VaultKey<T> vaultKey;
  final Widget Function(BuildContext context, T value) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: vaultKey.stream.startWith(vaultKey.value),
      initialData: vaultKey.value,
      builder: (context, snapshot) {
        return builder(context, snapshot.data ?? vaultKey.value);
      },
    );
  }
}
