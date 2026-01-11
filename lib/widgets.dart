part of 'vault.dart';

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
    return StreamBuilder(
      stream: vaultKey.stream,
      builder: (context, snapshot) {
        return FutureBuilder(
          future: vaultKey.read<T>(),
          builder: (context, snapshot) {
            return builder(context, snapshot.data);
          },
        );
      },
    );
  }
}
