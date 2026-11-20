import 'package:tefmanager/core/secrets.dart';

/// Magic seeds for the TEFManager easter egg.
///
/// Values are `Secrets.ToSecret(normalize(input))`, mirroring Terraria 1.4.5's
/// secret-seed pipeline (BCrypt.Net CryptRaw + 1000 swaps, see `secrets.dart`),
/// so the plaintext seeds are not stored in the source.
const kEasterOfficialCode = 'pHt1Sdq8GGGmAqfSbFTLTuX7l1H0xCn5';
const kEasterStinkCode = 'CCSGwoUR1RNhISyX0IqxECleZDJF6/ML';
const kEasterSecretCode = 'utPjCvzZ07jypKpWd20BEERac727B/av';

const kEasterOfficialUrl = 'https://github.com/eternalfuture-e38299/TEFManager';
const kEasterBilibiliUrl = 'https://www.bilibili.com/video/BV1cphe65EFo';

const kEasterSecretText = r'''
桑百颗够吗
唉！！！！
应该够吧
来吧，试一下米妮!
这个波斯，用这个枪来打从来没有试过
超囊的对我来说
蚩尤说又是这个囊的过分的波斯
真的真的快死了
啊
手没了就好，好一点了
可以庄心的躲这个骷髅头
可能因为平常我打这个波斯死了就是因为那个手
亡了亡了
哎呦，我没有史莱姆ang阿
还是失误了，我以为我有史莱姆ang你知道吗
''';

enum EasterEffect { none, hideUi, openOfficial, stinkNumber, secretText }

/// Decides the effect for a raw seed input, using the same normalization as
/// Terraria's `SecretSeed.Check`.
EasterEffect resolveEasterEffect(String raw) {
  final normalized = normalizeSeed(raw);
  if (normalized.isEmpty) return EasterEffect.hideUi;

  final code = toSecret(normalized);
  if (code == kEasterOfficialCode) return EasterEffect.openOfficial;
  if (code == kEasterStinkCode) return EasterEffect.stinkNumber;
  if (code == kEasterSecretCode) return EasterEffect.secretText;
  return EasterEffect.none;
}
