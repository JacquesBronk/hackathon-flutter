# Cash Me Outside — Walking Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This plan is also the source for the Bureau task graph: plan Task N = Bureau task TN; dependencies are listed per task.

**Goal:** An offline peer-to-peer Flutter wallet slice: onboard (Ed25519 keypair + biometric gate), see balance, move pinnies device-to-device via a two-scan QR handshake.

**Architecture:** Ports-and-adapters with Riverpod. `lib/domain` is pure Dart (signed-transaction CRDT ledger); every hardware capability is a port with an in-memory fake (tests run headless) and a plugin adapter (verified on-device by a human).

**Tech Stack:** Flutter, flutter_riverpod, cryptography (Ed25519), crypto (SHA-256), uuid (v7), drift (SQLite), flutter_secure_storage, local_auth, mobile_scanner, qr_flutter, shared_preferences.

**Spec:** `docs/superpowers/specs/2026-08-01-walking-skeleton-design.md` — normative for all protocol rules. On any conflict, the spec wins.

## Global Constraints

Every task's requirements implicitly include all of these.

- **Gate (run before claiming done):** `bash tool/check.sh` — build_runner → `dart format --set-exit-if-changed .` → `flutter analyze` → `flutter test`, in that order. Run `dart format .` before committing so generated files are committed formatted.
- **Protocol constants:** `mintAmount = 500`; valid transfer/mint amount range `1 ≤ amount ≤ 9007199254740991` (2^53−1); mint valid only when `from == to && amount == 500`, at most one counted per address (first in replay order).
- **Replay order:** ascending `(lamportTs, id)`, `id` compared as a string (bytewise). Balances always derive from full replay in this order. Negative balances are allowed and displayed; sends are never blocked by balance.
- **Encodings:** address = base64url **no padding** of raw 32-byte Ed25519 public key; signature = base64url no padding of raw 64-byte signature; `id` = lowercase canonical UUIDv7 (`uuid` package `v7()`); ledger set key = lowercase hex SHA-256 of canonical signing bytes.
- **Canonical signing bytes:** UTF-8 of `jsonEncode` over a map built by inserting keys in exactly this order: `amount, from, id, lamportTs, memo, to, type`. `memo` always present (`null` when empty). `signature` excluded. Verifiers re-canonicalize from parsed fields.
- **QR formats:** `cmo:rr1:<b64u(json)>` (receive-request `{addr, name, amount?}`) and `cmo:tx1:<b64u(tx json incl. signature)>`. Anything else → `QrDecodeException`, never a crash. rr `name` is unauthenticated: any UI showing it also shows the truncated address.
- **Android config (T1 owns, nobody else touches `android/`):** applicationId `dev.jcqb.cashmeoutside`; minSdk 24; compileSdk 36; `MainActivity : FlutterFragmentActivity`; launch theme parented on `Theme.AppCompat`; manifest has `USE_BIOMETRIC` + `CAMERA`; `android:allowBackup="false"`.
- **Shared-surface ownership:** only T1 edits `pubspec.yaml`, `lib/app.dart`, `lib/main.dart`, `analysis_options.yaml`, `tool/check.sh`, `android/`, fonts/assets. T3 creates `lib/providers.dart`; T7 is the only later editor of `lib/main.dart`/`lib/providers.dart`. All other tasks only add/modify files inside their own listed paths.
- **Tests never use `--dart-define`:** widget tests pass fakes via explicit `ProviderScope(overrides: ...)`. `FAKE_HARDWARE=true` dart-define is only for `flutter run` click-throughs.
- **No plugin import outside `lib/adapters/`** (exception: `qr_flutter`'s `QrImageView` is UI rendering, allowed in features).
- **Route names (registered by T1):** `/` (RootGate), `/send`, `/receive`, `/history`.
- **Avatar presets (exact list):** `['🦫','🦜','🐸','🦊','🐙','🦔','🐳','🦩','🐢','🦉','🦄','🐝']`.
- Commit after each green step-cycle; message style `feat:`/`test:`/`chore:` one-liners.

---

### Task 1: Toolchain probe + project foundation

**Bureau:** T1, Wave 1, no dependencies. **Everything else depends on this task.**

**Files:**
- Create: entire Flutter scaffold at repo root, `tool/check.sh`, `tool/PROBE.md`, `lib/app.dart`, `lib/theme/tokens.dart`, `lib/theme/coin.dart`, `lib/features/root/root_gate.dart` (placeholder), `assets/fonts/*`
- Modify: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/dev/jcqb/cashmeoutside/MainActivity.kt`, `android/app/src/main/res/values/styles.xml` (+ `values-night/styles.xml`)
- Test: `test/theme/coin_test.dart`, `test/smoke_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: the app shell later tasks live in. `buildCmoTheme() → ThemeData` and `CmoColors.{green,cream,orange,navy,brass}` (`lib/theme/tokens.dart`); `PinnieCoin({double size = 96, bool flipOnBuild = false})` widget (`lib/theme/coin.dart`); `CashMeOutsideApp({List<Override> overrides = const []})` root widget (`lib/app.dart`) with the route table; placeholder `RootGate` widget; `tool/check.sh` gate script; complete dependency set in `pubspec.yaml`.

- [ ] **Step 1: Toolchain probe — record, decide APK-gate fallback**

Run and capture output into `tool/PROBE.md`:

```bash
flutter --version
flutter doctor -v
java -version 2>&1 || echo "NO JAVA"
```

Then prove (or disprove) APK capability with a throwaway project **outside the repo**:

```bash
cd "$(mktemp -d)" && flutter create probe_apk --org dev.jcqb --platforms android && cd probe_apk && flutter build apk --debug && echo "APK_OK" || echo "APK_UNAVAILABLE"
```

Record the verdict in `tool/PROBE.md`. **If `APK_UNAVAILABLE`: per spec §6 the APK gates are dropped from this graph (the owner builds locally); do not fail the task — record the fallback and continue.**

- [ ] **Step 2: Scaffold the real app**

```bash
cd <repo root> && flutter create . --org dev.jcqb --project-name cash_me_outside --platforms android,web
```

- [ ] **Step 3: Add all dependencies (single owner: this task)**

```bash
flutter pub add flutter_riverpod cryptography crypto uuid drift drift_flutter flutter_secure_storage local_auth mobile_scanner qr_flutter shared_preferences
flutter pub add --dev build_runner drift_dev
```

- [ ] **Step 4: Android config (exact edits)**

`android/app/src/main/kotlin/dev/jcqb/cashmeoutside/MainActivity.kt` — replace file:

```kotlin
package dev.jcqb.cashmeoutside

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

`android/app/build.gradle.kts` — in `android {}` set `compileSdk = 36`; in `defaultConfig {}` set `applicationId = "dev.jcqb.cashmeoutside"`, `minSdk = 24`.

`android/app/src/main/AndroidManifest.xml` — add above `<application>`:

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

and on the `<application>` tag set `android:allowBackup="false"`.

Both `res/values/styles.xml` and `res/values-night/styles.xml`: change `LaunchTheme`/`NormalTheme` parents to `Theme.AppCompat.DayNight.NoActionBar` (local_auth requirement).

- [ ] **Step 5: Fonts**

```bash
mkdir -p assets/fonts
curl -fL -o assets/fonts/AlfaSlabOne-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/alfaslabone/AlfaSlabOne-Regular.ttf"
curl -fL -o "assets/fonts/Inter-Variable.ttf" "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf"
```

Register in `pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: AlfaSlabOne
      fonts:
        - asset: assets/fonts/AlfaSlabOne-Regular.ttf
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Variable.ttf
```

If both downloads fail (no network to GitHub), record in `tool/PROBE.md` and skip the `fonts:` block — `buildCmoTheme` falls back to default families via the same API, and the human adds fonts before the demo.

- [ ] **Step 6: analysis_options.yaml**

```yaml
include: package:flutter_lints/flutter.yaml
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.drift.dart"
```

- [ ] **Step 7: Gate script `tool/check.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

`chmod +x tool/check.sh`.

- [ ] **Step 8: Failing test for theme + coin**

`test/theme/coin_test.dart`:

```dart
import 'package:cash_me_outside/theme/coin.dart';
import 'package:cash_me_outside/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('palette matches spec', () {
    expect(CmoColors.green, const Color(0xFF3E6B4F));
    expect(CmoColors.cream, const Color(0xFFF2EBD9));
    expect(CmoColors.orange, const Color(0xFFFF5A1F));
    expect(CmoColors.navy, const Color(0xFF1E2733));
    expect(CmoColors.brass, const Color(0xFFC9A54A));
  });

  testWidgets('coin renders and its flip animation terminates', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PinnieCoin(flipOnBuild: true))));
    expect(find.byType(PinnieCoin), findsOneWidget);
    await tester.pumpAndSettle(); // hangs forever if the animation loops
  });
}
```

Run: `flutter test test/theme/coin_test.dart` — expected: FAIL (files missing).

- [ ] **Step 9: Implement `lib/theme/tokens.dart`**

```dart
import 'package:flutter/material.dart';

abstract final class CmoColors {
  static const green = Color(0xFF3E6B4F);
  static const cream = Color(0xFFF2EBD9);
  static const orange = Color(0xFFFF5A1F); // money-in-motion ONLY
  static const navy = Color(0xFF1E2733);
  static const brass = Color(0xFFC9A54A);
}

/// Slab display style for amounts/headers. Tabular figures everywhere numbers appear.
TextStyle cmoAmountStyle({double size = 40, Color color = CmoColors.navy}) =>
    TextStyle(
      fontFamily: 'AlfaSlabOne',
      fontSize: size,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData buildCmoTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: CmoColors.green,
      primary: CmoColors.green,
      surface: CmoColors.cream,
    ),
    scaffoldBackgroundColor: CmoColors.cream,
    fontFamily: 'Inter',
    useMaterial3: true,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: CmoColors.navy,
      displayColor: CmoColors.navy,
    ),
  );
}
```

- [ ] **Step 10: Implement `lib/theme/coin.dart`**

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tokens.dart';

/// The pinnie coin — the design system's single reusable money asset.
/// Flip is FINITE (single run): looping controllers hang pumpAndSettle.
class PinnieCoin extends StatefulWidget {
  const PinnieCoin({super.key, this.size = 96, this.flipOnBuild = false});
  final double size;
  final bool flipOnBuild;

  @override
  State<PinnieCoin> createState() => PinnieCoinState();
}

class PinnieCoinState extends State<PinnieCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    if (widget.flipOnBuild) _c.forward();
  }

  void flip() => _c.forward(from: 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_c.value * math.pi * 2),
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _CoinPainter(),
          ),
        ),
      );
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(center, r, Paint()..color = CmoColors.brass);
    canvas.drawCircle(
        center,
        r * 0.86,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06
          ..color = CmoColors.navy.withValues(alpha: 0.25));
    final tp = TextPainter(
      text: TextSpan(
          text: 'ᵽ',
          style: TextStyle(
              fontSize: r,
              color: CmoColors.navy,
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

- [ ] **Step 11: App shell — `lib/app.dart`, `lib/main.dart`, placeholder RootGate**

`lib/features/root/root_gate.dart` (placeholder — T5 rewrites this file wholesale):

```dart
import 'package:flutter/material.dart';

class RootGate extends StatelessWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Cash Me Outside')));
}
```

`lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/root/root_gate.dart';
import 'theme/tokens.dart';

class CashMeOutsideApp extends StatelessWidget {
  const CashMeOutsideApp({super.key, this.overrides = const []});
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          title: 'Cash Me Outside',
          theme: buildCmoTheme(),
          routes: {'/': (_) => const RootGate()},
          // '/send', '/receive', '/history' are pushed with MaterialPageRoute
          // by feature code (T5/T6) — no additional named-route edits here.
        ),
      );
}
```

`lib/main.dart` — replace file:

```dart
import 'package:flutter/material.dart';
import 'app.dart';

void main() => runApp(const CashMeOutsideApp());
```

`test/smoke_test.dart`:

```dart
import 'package:cash_me_outside/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const CashMeOutsideApp());
    expect(find.text('Cash Me Outside'), findsOneWidget);
  });
}
```

- [ ] **Step 12: Run the full gate**

Run: `bash tool/check.sh` — expected: PASS (build_runner is a no-op until T4).

- [ ] **Step 13: APK proof (skip if Step 1 recorded APK_UNAVAILABLE)**

Run: `flutter build apk --debug` — expected: `app-debug.apk` produced; note path in `tool/PROBE.md`.

- [ ] **Step 14: Commit**

```bash
git add -A && git commit -m "feat: scaffold app shell, theme, coin, gate script, android config"
```

---

### Task 2: Domain — keys, transactions, ledger, QR codecs

**Bureau:** T2, Wave 2, depends on T1. Pure Dart; nothing here imports Flutter.

**Files:**
- Create: `lib/domain/keys.dart`, `lib/domain/transaction.dart`, `lib/domain/canonical.dart`, `lib/domain/ledger.dart`, `lib/domain/qr_codec.dart`
- Test: `test/domain/canonical_test.dart`, `test/domain/keys_test.dart`, `test/domain/ledger_test.dart`, `test/domain/qr_codec_test.dart`

**Interfaces:**
- Consumes: `pubspec` deps `cryptography`, `crypto`, `uuid` (from T1).
- Produces (exact — later tasks import these):
  - `keys.dart`: `class WalletKeys { final String address; static Future<WalletKeys> generate(); static Future<WalletKeys> fromSeed(List<int> seed32); Future<Uint8List> seed(); Future<String> sign(List<int> message); }`, `String b64u(List<int>)`, `Uint8List b64uDecode(String)`, `Future<bool> verifyTransactionSignature({required String from, required List<int> canonicalBytes, required String signature})`, `String truncateAddr(String)`.
  - `transaction.dart`: `class Transaction { final String id, type, from, to, signature; final int amount, lamportTs; final String? memo; Map<String, Object?> toJson(); factory Transaction.fromJson(Map<String, Object?>); }` with `const txTypeMint = 'mint'; const txTypeTransfer = 'transfer';`.
  - `canonical.dart`: `const int mintAmount = 500; const int maxAmount = 9007199254740991;`, `Uint8List canonicalBytesOf(Transaction)`, `String ledgerKeyOf(Transaction)` (lowercase hex SHA-256).
  - `ledger.dart`: `enum IngestStatus { added, duplicate, rejected }`, `class IngestResult { final IngestStatus status; final String? reason; }`, `class LamportClock { int get value; int next(int highestSeen); }`, `class Ledger { List<Transaction> get ordered; int get highestLamport; Map<String, int> balances(); Future<IngestResult> ingest(Transaction tx); }`, `Future<Transaction> buildSigned({required WalletKeys keys, required String to, required int amount, String? memo, required String type, required int lamportTs, String? id})`.
  - `qr_codec.dart`: `sealed class QrPayload`, `class ReceiveRequest extends QrPayload { final String addr; final String name; final int? amount; }`, `class SignedTransactionPayload extends QrPayload { final Transaction transaction; }`, `class QrDecodeException implements Exception { final String message; }`, `String encodeReceiveRequest(ReceiveRequest)`, `String encodeTransaction(Transaction)`, `QrPayload decodeQr(String raw)`.

- [ ] **Step 1: Failing tests — canonical bytes + keys**

`test/domain/canonical_test.dart`:

```dart
import 'dart:convert';
import 'package:cash_me_outside/domain/canonical.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction tx({int amount = 500, String? memo, String type = txTypeMint}) =>
    Transaction(
        id: '01890000-0000-7000-8000-000000000001',
        type: type,
        from: 'AAA',
        to: 'AAA',
        amount: amount,
        memo: memo,
        lamportTs: 1,
        signature: 'sig');

void main() {
  test('canonical bytes: exact layout, sorted keys, memo:null when empty', () {
    expect(
        utf8.decode(canonicalBytesOf(tx())),
        '{"amount":500,"from":"AAA","id":"01890000-0000-7000-8000-000000000001",'
        '"lamportTs":1,"memo":null,"to":"AAA","type":"mint"}');
  });

  test('memo and unicode participate in the bytes', () {
    expect(canonicalBytesOf(tx(memo: 'pizza 🍕')),
        isNot(equals(canonicalBytesOf(tx()))));
  });

  test('signature is excluded: same fields different sig → same ledger key', () {
    final a = tx();
    final b = Transaction(
        id: a.id, type: a.type, from: a.from, to: a.to, amount: a.amount,
        memo: a.memo, lamportTs: a.lamportTs, signature: 'other');
    expect(ledgerKeyOf(a), ledgerKeyOf(b));
    expect(ledgerKeyOf(a), matches(RegExp(r'^[0-9a-f]{64}$')));
  });
}
```

`test/domain/keys_test.dart`:

```dart
import 'package:cash_me_outside/domain/keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('address is unpadded base64url of 32-byte pubkey; deterministic from seed',
      () async {
    final k1 = await WalletKeys.fromSeed(List.filled(32, 7));
    final k2 = await WalletKeys.fromSeed(List.filled(32, 7));
    expect(k1.address, k2.address);
    expect(k1.address.contains('='), isFalse);
    expect(b64uDecode(k1.address).length, 32);
  });

  test('sign/verify round trip; wrong key fails', () async {
    final k1 = await WalletKeys.fromSeed(List.filled(32, 1));
    final k2 = await WalletKeys.fromSeed(List.filled(32, 2));
    final msg = [1, 2, 3];
    final sig = await k1.sign(msg);
    expect(
        await verifyTransactionSignature(
            from: k1.address, canonicalBytes: msg, signature: sig),
        isTrue);
    expect(
        await verifyTransactionSignature(
            from: k2.address, canonicalBytes: msg, signature: sig),
        isFalse);
    expect(
        await verifyTransactionSignature(
            from: 'not-an-address', canonicalBytes: msg, signature: sig),
        isFalse);
  });

  test('truncateAddr', () {
    expect(truncateAddr('abcdefghijklmnop'), 'abcdef…mnop');
    expect(truncateAddr('short'), 'short');
  });
}
```

Run: `flutter test test/domain/` — expected: FAIL (nothing exists).

- [ ] **Step 2: Implement `lib/domain/keys.dart`**

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

final _ed25519 = Ed25519();

String b64u(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List b64uDecode(String s) {
  final pad = (4 - s.length % 4) % 4;
  return base64Url.decode('$s${'=' * pad}');
}

String truncateAddr(String a) =>
    a.length <= 12 ? a : '${a.substring(0, 6)}…${a.substring(a.length - 4)}';

/// Wallet identity. address = b64u(raw 32-byte Ed25519 public key).
class WalletKeys {
  WalletKeys._(this._keyPair, this.address);
  final SimpleKeyPair _keyPair;
  final String address;

  static Future<WalletKeys> generate() async =>
      _from(await _ed25519.newKeyPair());

  static Future<WalletKeys> fromSeed(List<int> seed32) async =>
      _from(await _ed25519.newKeyPairFromSeed(seed32));

  static Future<WalletKeys> _from(SimpleKeyPair kp) async {
    final pub = await kp.extractPublicKey();
    return WalletKeys._(kp, b64u(pub.bytes));
  }

  Future<Uint8List> seed() async =>
      Uint8List.fromList(await _keyPair.extractPrivateKeyBytes());

  Future<String> sign(List<int> message) async {
    final sig = await _ed25519.sign(message, keyPair: _keyPair);
    return b64u(sig.bytes);
  }
}

/// The signature MUST verify against the key decoded from `from` — anything
/// else is forgery (spec §2.1).
Future<bool> verifyTransactionSignature(
    {required String from,
    required List<int> canonicalBytes,
    required String signature}) async {
  try {
    final pubBytes = b64uDecode(from);
    final sigBytes = b64uDecode(signature);
    if (pubBytes.length != 32 || sigBytes.length != 64) return false;
    return await _ed25519.verify(
      canonicalBytes,
      signature: Signature(sigBytes,
          publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519)),
    );
  } catch (_) {
    return false;
  }
}
```

- [ ] **Step 3: Implement `lib/domain/transaction.dart`**

```dart
const txTypeMint = 'mint';
const txTypeTransfer = 'transfer';

class Transaction {
  const Transaction(
      {required this.id,
      required this.type,
      required this.from,
      required this.to,
      required this.amount,
      required this.memo,
      required this.lamportTs,
      required this.signature});

  final String id; // lowercase canonical UUIDv7
  final String type;
  final String from; // address
  final String to; // address
  final int amount; // integer pinnies
  final String? memo;
  final int lamportTs;
  final String signature; // b64u(64 bytes)

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type,
        'from': from,
        'to': to,
        'amount': amount,
        'memo': memo,
        'lamportTs': lamportTs,
        'signature': signature,
      };

  factory Transaction.fromJson(Map<String, Object?> json) {
    final id = json['id'], type = json['type'], from = json['from'],
        to = json['to'], amount = json['amount'], memo = json['memo'],
        lamportTs = json['lamportTs'], signature = json['signature'];
    if (id is! String || type is! String || from is! String || to is! String ||
        amount is! int || lamportTs is! int || signature is! String ||
        (memo != null && memo is! String)) {
      throw const FormatException('malformed transaction');
    }
    return Transaction(
        id: id, type: type, from: from, to: to, amount: amount,
        memo: memo as String?, lamportTs: lamportTs, signature: signature);
  }
}
```

- [ ] **Step 4: Implement `lib/domain/canonical.dart`**

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'transaction.dart';

const int mintAmount = 500; // protocol constant — replay-enforced
const int maxAmount = 9007199254740991; // 2^53 - 1, web-safe

/// Pinned canonicalizer (spec §2.1): keys inserted in this exact order,
/// memo ALWAYS present (null when empty), jsonEncode, UTF-8.
Uint8List canonicalBytesOf(Transaction tx) {
  final map = <String, Object?>{
    'amount': tx.amount,
    'from': tx.from,
    'id': tx.id,
    'lamportTs': tx.lamportTs,
    'memo': tx.memo,
    'to': tx.to,
    'type': tx.type,
  };
  return Uint8List.fromList(utf8.encode(jsonEncode(map)));
}

/// Ledger set key: id collisions must not fork the CRDT (spec §2.2).
String ledgerKeyOf(Transaction tx) =>
    sha256.convert(canonicalBytesOf(tx)).toString();
```

- [ ] **Step 5: Run canonical + keys tests**

Run: `flutter test test/domain/canonical_test.dart test/domain/keys_test.dart` — expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain test/domain && git commit -m "feat: domain keys, transaction, canonical bytes"
```

- [ ] **Step 7: Failing tests — ledger**

`test/domain/ledger_test.dart`:

```dart
import 'package:cash_me_outside/domain/canonical.dart';
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

late WalletKeys alice, bob;

Future<Transaction> mint(WalletKeys k, {String? id, int amount = 500}) =>
    buildSigned(keys: k, to: k.address, amount: amount, type: txTypeMint,
        lamportTs: 1, id: id);

Future<Transaction> pay(WalletKeys from, WalletKeys to, int amount,
        {int lamport = 2, String? memo}) =>
    buildSigned(keys: from, to: to.address, amount: amount, memo: memo,
        type: txTypeTransfer, lamportTs: lamport);

void main() {
  setUpAll(() async {
    alice = await WalletKeys.fromSeed(List.filled(32, 1));
    bob = await WalletKeys.fromSeed(List.filled(32, 2));
  });

  test('mint + transfer replay; negative balances allowed', () async {
    final l = Ledger();
    await l.ingest(await mint(alice));
    await l.ingest(await pay(alice, bob, 700));
    expect(l.balances()[alice.address], -200);
    expect(l.balances()[bob.address], 700);
  });

  test('convergence: permuted merge orders yield identical state', () async {
    final txs = [
      await mint(alice),
      await mint(bob),
      await pay(alice, bob, 100),
      await pay(bob, alice, 30, lamport: 3),
    ];
    final l1 = Ledger();
    final l2 = Ledger();
    for (final t in txs) { await l1.ingest(t); }
    for (final t in txs.reversed) { await l2.ingest(t); }
    expect(l1.balances(), l2.balances());
    expect(l1.ordered.map((t) => t.id), l2.ordered.map((t) => t.id));
  });

  test('id collision: both distinct-bytes transactions survive', () async {
    final a = await mint(alice, id: '01890000-0000-7000-8000-00000000aaaa');
    final b = await pay(alice, bob, 9);
    final c = Transaction(
        id: a.id, type: b.type, from: b.from, to: b.to, amount: b.amount,
        memo: b.memo, lamportTs: b.lamportTs, signature: b.signature);
    // c reuses a's id but b's content — resign it properly:
    final cSigned = await buildSigned(keys: alice, to: bob.address, amount: 9,
        type: txTypeTransfer, lamportTs: 2, id: a.id);
    final l = Ledger();
    expect((await l.ingest(a)).status, IngestStatus.added);
    expect((await l.ingest(cSigned)).status, IngestStatus.added);
    expect(l.ordered.length, 2);
  });

  test('forgery rejected: tampered amount, wrong signer', () async {
    final t = await pay(alice, bob, 100);
    final tampered = Transaction(
        id: t.id, type: t.type, from: t.from, to: t.to, amount: 9999,
        memo: t.memo, lamportTs: t.lamportTs, signature: t.signature);
    final wrongSigner = await buildSigned(keys: bob, to: bob.address,
        amount: 5, type: txTypeTransfer, lamportTs: 2)
      .then((x) => Transaction(id: x.id, type: x.type, from: alice.address,
        to: x.to, amount: x.amount, memo: x.memo, lamportTs: x.lamportTs,
        signature: x.signature));
    final l = Ledger();
    expect((await l.ingest(tampered)).status, IngestStatus.rejected);
    expect((await l.ingest(wrongSigner)).status, IngestStatus.rejected);
  });

  test('amount range: 0, negative, > 2^53-1 rejected', () async {
    final l = Ledger();
    for (final bad in [0, -5, maxAmount + 1]) {
      final t = await buildSigned(keys: alice, to: bob.address, amount: bad,
          type: txTypeTransfer, lamportTs: 2);
      expect((await l.ingest(t)).status, IngestStatus.rejected,
          reason: 'amount $bad must be rejected');
    }
  });

  test('mint rules: wrong amount, wrong recipient rejected; duplicate mint '
      'counted once deterministically under any merge order', () async {
    final l = Ledger();
    expect((await l.ingest(await mint(alice, amount: 501))).status,
        IngestStatus.rejected);
    final notSelf = await buildSigned(keys: alice, to: bob.address,
        amount: 500, type: txTypeMint, lamportTs: 1);
    expect((await l.ingest(notSelf)).status, IngestStatus.rejected);

    final m1 = await mint(alice, id: '01890000-0000-7000-8000-000000000001');
    final m2 = await mint(alice, id: '01890000-0000-7000-8000-000000000002');
    final la = Ledger();
    final lb = Ledger();
    await la.ingest(m1); await la.ingest(m2);
    await lb.ingest(m2); await lb.ingest(m1);
    expect(la.balances()[alice.address], 500);
    expect(lb.balances()[alice.address], 500);
  });

  test('duplicate ingest is idempotent; unknown type retained but ignored',
      () async {
    final l = Ledger();
    final t = await mint(alice);
    expect((await l.ingest(t)).status, IngestStatus.added);
    expect((await l.ingest(t)).status, IngestStatus.duplicate);
    final burn = await buildSigned(keys: alice, to: bob.address, amount: 5,
        type: 'burn', lamportTs: 4);
    expect((await l.ingest(burn)).status, IngestStatus.added);
    expect(l.balances()[bob.address], isNot(5));
    expect(l.ordered.any((x) => x.type == 'burn'), isTrue);
  });

  test('lamport clock', () {
    final c = LamportClock();
    expect(c.next(0), 1);
    expect(c.next(10), 11);
    expect(c.next(3), 12);
    expect(c.value, 12);
  });
}
```

(Delete the stray `final l1 = Ledger()..;` line when writing the real file — shown here to flag: use two fresh ledgers `la`/`lb`.)

Run: `flutter test test/domain/ledger_test.dart` — expected: FAIL.

- [ ] **Step 8: Implement `lib/domain/ledger.dart`**

```dart
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'canonical.dart';
import 'keys.dart';
import 'transaction.dart';

enum IngestStatus { added, duplicate, rejected }

class IngestResult {
  const IngestResult(this.status, [this.reason]);
  final IngestStatus status;
  final String? reason;
}

class LamportClock {
  LamportClock([this._value = 0]);
  int _value;
  int get value => _value;
  int next(int highestSeen) => _value = math.max(_value, highestSeen) + 1;
}

/// Grow-only CRDT set keyed on sha256(canonical bytes) — spec §2.2.
class Ledger {
  final Map<String, Transaction> _byKey = {};

  /// Deterministic total replay order: (lamportTs, id), id bytewise.
  List<Transaction> get ordered {
    final list = _byKey.values.toList();
    list.sort((a, b) {
      final c = a.lamportTs.compareTo(b.lamportTs);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return list;
  }

  int get highestLamport =>
      _byKey.values.fold(0, (m, t) => math.max(m, t.lamportTs));

  Future<IngestResult> ingest(Transaction tx) async {
    final key = ledgerKeyOf(tx);
    if (_byKey.containsKey(key)) {
      return const IngestResult(IngestStatus.duplicate);
    }
    if (tx.amount < 1 || tx.amount > maxAmount) {
      return const IngestResult(IngestStatus.rejected, 'amount out of range');
    }
    if (tx.type == txTypeMint &&
        (tx.from != tx.to || tx.amount != mintAmount)) {
      return const IngestResult(IngestStatus.rejected, 'invalid mint');
    }
    final ok = await verifyTransactionSignature(
        from: tx.from,
        canonicalBytes: canonicalBytesOf(tx),
        signature: tx.signature);
    if (!ok) return const IngestResult(IngestStatus.rejected, 'bad signature');
    _byKey[key] = tx;
    return const IngestResult(IngestStatus.added);
  }

  /// Replay in total order. Unknown types are retained but ignored.
  /// At most one mint per address counts (first in replay order).
  Map<String, int> balances() {
    final bal = <String, int>{};
    final minted = <String>{};
    for (final tx in ordered) {
      switch (tx.type) {
        case txTypeMint:
          if (minted.add(tx.from)) {
            bal[tx.to] = (bal[tx.to] ?? 0) + tx.amount;
          }
        case txTypeTransfer:
          bal[tx.from] = (bal[tx.from] ?? 0) - tx.amount;
          bal[tx.to] = (bal[tx.to] ?? 0) + tx.amount;
        default:
          break; // forward-compat: ignore
      }
    }
    return bal;
  }
}

/// Create + sign a transaction with [keys] as sender.
Future<Transaction> buildSigned(
    {required WalletKeys keys,
    required String to,
    required int amount,
    String? memo,
    required String type,
    required int lamportTs,
    String? id}) async {
  final unsigned = Transaction(
      id: id ?? const Uuid().v7(),
      type: type,
      from: keys.address,
      to: to,
      amount: amount,
      memo: memo,
      lamportTs: lamportTs,
      signature: '');
  final sig = await keys.sign(canonicalBytesOf(unsigned));
  return Transaction(
      id: unsigned.id, type: type, from: keys.address, to: to,
      amount: amount, memo: memo, lamportTs: lamportTs, signature: sig);
}
```

- [ ] **Step 9: Run ledger tests**

Run: `flutter test test/domain/ledger_test.dart` — expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/domain test/domain && git commit -m "feat: CRDT ledger with deterministic replay and mint rules"
```

- [ ] **Step 11: Failing tests — QR codecs**

`test/domain/qr_codec_test.dart`:

```dart
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('receive-request round trip, with and without amount', () {
    for (final amount in [null, 250]) {
      final rr = ReceiveRequest(addr: 'someaddr', name: 'Thabo', amount: amount);
      final decoded = decodeQr(encodeReceiveRequest(rr)) as ReceiveRequest;
      expect(decoded.addr, 'someaddr');
      expect(decoded.name, 'Thabo');
      expect(decoded.amount, amount);
    }
  });

  test('signed transaction round trips byte-identically', () async {
    final k = await WalletKeys.fromSeed(List.filled(32, 3));
    final tx = await buildSigned(keys: k, to: k.address, amount: 500,
        type: txTypeMint, lamportTs: 1);
    final decoded =
        (decodeQr(encodeTransaction(tx)) as SignedTransactionPayload)
            .transaction;
    expect(decoded.toJson(), tx.toJson());
  });

  test('malformed and unknown inputs throw QrDecodeException, never crash', () {
    for (final bad in [
      'hello', 'cmo:', 'cmo:zz1:aaaa', 'cmo:rr2:aaaa', 'cmo:rr1:%%%',
      'cmo:tx1:aGVsbG8', // valid b64u, not json
      'cmo:rr1:e30', // {} — missing fields
    ]) {
      expect(() => decodeQr(bad), throwsA(isA<QrDecodeException>()),
          reason: bad);
    }
  });
}
```

Run: `flutter test test/domain/qr_codec_test.dart` — expected: FAIL.

- [ ] **Step 12: Implement `lib/domain/qr_codec.dart`**

```dart
import 'dart:convert';
import 'keys.dart';
import 'transaction.dart';

sealed class QrPayload {}

class ReceiveRequest extends QrPayload {
  ReceiveRequest({required this.addr, required this.name, this.amount});
  final String addr;
  final String name; // UNAUTHENTICATED — UI must show truncated addr alongside
  final int? amount;
}

class SignedTransactionPayload extends QrPayload {
  SignedTransactionPayload(this.transaction);
  final Transaction transaction;
}

class QrDecodeException implements Exception {
  QrDecodeException(this.message);
  final String message;
}

String _wrap(String kind, Map<String, Object?> json) =>
    'cmo:$kind:${b64u(utf8.encode(jsonEncode(json)))}';

String encodeReceiveRequest(ReceiveRequest rr) => _wrap('rr1', {
      'addr': rr.addr,
      'name': rr.name,
      if (rr.amount != null) 'amount': rr.amount,
    });

String encodeTransaction(Transaction tx) => _wrap('tx1', tx.toJson());

QrPayload decodeQr(String raw) {
  final parts = raw.split(':');
  if (parts.length != 3 || parts[0] != 'cmo') {
    throw QrDecodeException('not a pinnie code');
  }
  final Map<String, Object?> json;
  try {
    json = jsonDecode(utf8.decode(b64uDecode(parts[2])))
        as Map<String, Object?>;
  } catch (_) {
    throw QrDecodeException('not a pinnie code');
  }
  switch (parts[1]) {
    case 'rr1':
      final addr = json['addr'], name = json['name'], amount = json['amount'];
      if (addr is! String || name is! String ||
          (amount != null && amount is! int)) {
        throw QrDecodeException('not a pinnie code');
      }
      return ReceiveRequest(addr: addr, name: name, amount: amount as int?);
    case 'tx1':
      try {
        return SignedTransactionPayload(Transaction.fromJson(json));
      } on FormatException {
        throw QrDecodeException('not a pinnie code');
      }
    default:
      throw QrDecodeException('not a pinnie code');
  }
}
```

- [ ] **Step 13: Full gate + commit**

Run: `bash tool/check.sh` — expected: PASS.

```bash
git add -A && git commit -m "feat: QR payload codecs (rr1/tx1)"
```

---

### Task 3: Ports, fakes, app-state controllers, providers

**Bureau:** T3, Wave 3, depends on T2 (uses `Transaction`, `WalletKeys`, `Ledger`).

**Files:**
- Create: `lib/ports/key_vault.dart`, `lib/ports/biometric_gate.dart`, `lib/ports/qr_scanner.dart`, `lib/ports/ledger_store.dart`, `lib/ports/profile_store.dart`, `lib/ports/peer_directory.dart`, `lib/fakes/fakes.dart`, `lib/state/ledger_controller.dart`, `lib/state/profile_controller.dart`, `lib/providers.dart`
- Test: `test/fakes/fakes_test.dart`, `test/state/controllers_test.dart`

**Interfaces:**
- Consumes (from T2): `Transaction`, `WalletKeys` (incl. `.seed()`, `.fromSeed`, `.generate`, `.address`), `Ledger`, `LamportClock`, `IngestResult`/`IngestStatus`, `buildSigned`, `txTypeMint`/`txTypeTransfer`, `mintAmount`.
- Produces (exact — T4 implements the ports; T5/T6/T7 consume providers/controllers):

```dart
// lib/ports/key_vault.dart
abstract interface class KeyVault {
  Future<void> storeSeed(Uint8List seed32);
  Future<Uint8List?> loadSeed();
}

// lib/ports/biometric_gate.dart
abstract interface class BiometricGate {
  Future<bool> get isAvailable;
  Future<bool> authenticate(String reason);
}

// lib/ports/qr_scanner.dart
abstract interface class QrScanner {
  Stream<String> get scans;
  Widget buildPreview(); // UI never imports the scanner plugin directly
}

// lib/ports/ledger_store.dart
abstract interface class LedgerStore {
  Future<List<Transaction>> loadAll();
  Future<void> save(Transaction tx);
  Future<int> loadLamport();
  Future<void> saveLamport(int value);
}

// lib/ports/profile_store.dart
class Profile {
  const Profile({required this.name, required this.avatar, required this.onboarded});
  final String name;
  final String avatar; // one emoji from the preset list
  final bool onboarded;
}
abstract interface class ProfileStore {
  Future<Profile?> load();
  Future<void> save(Profile profile);
}

// lib/ports/peer_directory.dart
abstract interface class PeerDirectory {
  Future<void> record(String addr, String name);
  Future<String?> nameFor(String addr);
}
```

  - `lib/fakes/fakes.dart`: `InMemoryKeyVault`, `FakeBiometricGate({bool approve = true, bool available = true, Duration delay = Duration.zero})`, `FakeQrScanner` (with `void emit(String payload)`; preview = placeholder box), `InMemoryLedgerStore`, `InMemoryProfileStore`, `InMemoryPeerDirectory`.
  - `lib/state/ledger_controller.dart`: `class LedgerState { final Map<String, int> balances; final List<Transaction> ordered; }` and `class LedgerController extends AsyncNotifier<LedgerState>` with `Future<IngestResult> ingestExternal(Transaction tx)`, `Future<Transaction> send({required String to, required int amount, String? memo})`, `Future<void> mintSelf()`.
  - `lib/state/profile_controller.dart`: `class ProfileController extends AsyncNotifier<Profile?>` with `Future<void> createWallet({required String name, required String avatar})` (generates keys → stores seed → saves Profile(onboarded:false) → mints via LedgerController), `Future<void> markOnboarded()`.
  - `lib/providers.dart`:

```dart
final keyVaultProvider = Provider<KeyVault>((_) => throw UnimplementedError());
final biometricGateProvider = Provider<BiometricGate>((_) => throw UnimplementedError());
final qrScannerProvider = Provider<QrScanner>((_) => throw UnimplementedError());
final ledgerStoreProvider = Provider<LedgerStore>((_) => throw UnimplementedError());
final profileStoreProvider = Provider<ProfileStore>((_) => throw UnimplementedError());
final peerDirectoryProvider = Provider<PeerDirectory>((_) => throw UnimplementedError());
final walletKeysProvider = FutureProvider<WalletKeys?>(...); // null until onboarded
final ledgerControllerProvider = AsyncNotifierProvider<LedgerController, LedgerState>(LedgerController.new);
final profileControllerProvider = AsyncNotifierProvider<ProfileController, Profile?>(ProfileController.new);
List<Override> fakeHardwareOverrides({FakeQrScanner? scanner, FakeBiometricGate? gate}) => [...]; // every port → fake
const presetAvatars = ['🦫','🦜','🐸','🦊','🐙','🦔','🐳','🦩','🐢','🦉','🦄','🐝'];
```

- [ ] **Step 1: Write the six port files exactly as the Interfaces block above** (add the needed imports: `dart:typed_data` for KeyVault, `flutter/widgets.dart` for QrScanner, `../domain/transaction.dart` for LedgerStore).

- [ ] **Step 2: Failing tests — fakes**

`test/fakes/fakes_test.dart`:

```dart
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

void main() {
  test('InMemoryKeyVault round trips a seed', () async {
    final v = InMemoryKeyVault();
    expect(await v.loadSeed(), isNull);
    await v.storeSeed(Uint8List.fromList(List.filled(32, 9)));
    expect((await v.loadSeed())!.length, 32);
  });

  test('FakeBiometricGate approve/deny, zero delay by default', () async {
    expect(await FakeBiometricGate().authenticate('r'), isTrue);
    expect(await FakeBiometricGate(approve: false).authenticate('r'), isFalse);
    expect(await FakeBiometricGate(available: false).isAvailable, isFalse);
  });

  test('FakeQrScanner emits into scans stream', () async {
    final s = FakeQrScanner();
    final got = <String>[];
    final sub = s.scans.listen(got.add);
    s.emit('cmo:rr1:abc');
    await Future<void>.delayed(Duration.zero);
    expect(got, ['cmo:rr1:abc']);
    await sub.cancel();
  });

  test('InMemoryProfileStore + InMemoryPeerDirectory round trip', () async {
    final p = InMemoryProfileStore();
    await p.save(const Profile(name: 'J', avatar: '🦫', onboarded: true));
    expect((await p.load())!.onboarded, isTrue);
    final d = InMemoryPeerDirectory();
    await d.record('addr1', 'Anna');
    expect(await d.nameFor('addr1'), 'Anna');
    expect(await d.nameFor('nope'), isNull);
  });
}
```

Run: `flutter test test/fakes/` — expected: FAIL.

- [ ] **Step 3: Implement `lib/fakes/fakes.dart`**

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import '../domain/canonical.dart';
import '../domain/transaction.dart';
import '../ports/biometric_gate.dart';
import '../ports/key_vault.dart';
import '../ports/ledger_store.dart';
import '../ports/peer_directory.dart';
import '../ports/profile_store.dart';
import '../ports/qr_scanner.dart';

class InMemoryKeyVault implements KeyVault {
  Uint8List? _seed;
  @override
  Future<Uint8List?> loadSeed() async => _seed;
  @override
  Future<void> storeSeed(Uint8List seed32) async => _seed = seed32;
}

class FakeBiometricGate implements BiometricGate {
  FakeBiometricGate(
      {this.approve = true, this.available = true, this.delay = Duration.zero});
  final bool approve;
  final bool available;
  final Duration delay; // Duration.zero default: pending Timers fail widget tests
  int authCalls = 0;
  @override
  Future<bool> get isAvailable async => available;
  @override
  Future<bool> authenticate(String reason) async {
    authCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return approve;
  }
}

class FakeQrScanner implements QrScanner {
  final _controller = StreamController<String>.broadcast();
  @override
  Stream<String> get scans => _controller.stream;
  void emit(String payload) => _controller.add(payload);
  @override
  Widget buildPreview() => Container(
      color: const Color(0xFF222222),
      alignment: Alignment.center,
      child: const Text('camera preview (fake)',
          style: TextStyle(color: Color(0xFFFFFFFF))));
}

class InMemoryLedgerStore implements LedgerStore {
  // Keyed like the drift store (upsert semantics) — fake/adapter parity.
  final Map<String, Transaction> _txs = {};
  int _lamport = 0;
  @override
  Future<List<Transaction>> loadAll() async => _txs.values.toList();
  @override
  Future<void> save(Transaction tx) async => _txs[ledgerKeyOf(tx)] = tx;
  @override
  Future<int> loadLamport() async => _lamport;
  @override
  Future<void> saveLamport(int value) async => _lamport = value;
}

class InMemoryProfileStore implements ProfileStore {
  Profile? _profile;
  @override
  Future<Profile?> load() async => _profile;
  @override
  Future<void> save(Profile profile) async => _profile = profile;
}

class InMemoryPeerDirectory implements PeerDirectory {
  final _names = <String, String>{};
  @override
  Future<void> record(String addr, String name) async => _names[addr] = name;
  @override
  Future<String?> nameFor(String addr) async => _names[addr];
}
```

Run: `flutter test test/fakes/` — expected: PASS. Commit: `git add lib/ports lib/fakes test/fakes && git commit -m "feat: hardware ports and in-memory fakes"`.

- [ ] **Step 4: Failing tests — controllers**

`test/state/controllers_test.dart`:

```dart
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late InMemoryLedgerStore store;

  setUp(() {
    store = InMemoryLedgerStore();
    container = ProviderContainer(overrides: [
      ...fakeHardwareOverrides(),
      ledgerStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
  });

  test('createWallet mints 500 and persists profile + seed + tx', () async {
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'Jacques', avatar: '🦫');
    final keys = (await container.read(walletKeysProvider.future))!;
    final state = await container.read(ledgerControllerProvider.future);
    expect(state.balances[keys.address], 500);
    expect((await store.loadAll()).single.type, txTypeMint);
    final profile = container.read(profileControllerProvider).value!;
    expect(profile.onboarded, isFalse); // true only after biometric step
  });

  test('send signs, debits, persists, bumps lamport', () async {
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'J', avatar: '🦫');
    final other = await WalletKeys.fromSeed(List.filled(32, 5));
    final tx = await container
        .read(ledgerControllerProvider.notifier)
        .send(to: other.address, amount: 700, memo: 'pizza');
    final state = await container.read(ledgerControllerProvider.future);
    final keys = (await container.read(walletKeysProvider.future))!;
    expect(state.balances[keys.address], -200); // never blocked by balance
    expect(tx.lamportTs, greaterThan(1));
    expect(await store.loadLamport(), tx.lamportTs);
    expect((await store.loadAll()).length, 2);
  });

  test('ingestExternal validates and is idempotent', () async {
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'J', avatar: '🦫');
    final keys = (await container.read(walletKeysProvider.future))!;
    final other = await WalletKeys.fromSeed(List.filled(32, 5));
    final incoming = await buildSigned(keys: other, to: keys.address,
        amount: 40, type: txTypeTransfer, lamportTs: 9);
    final n = container.read(ledgerControllerProvider.notifier);
    expect((await n.ingestExternal(incoming)).status, IngestStatus.added);
    expect((await n.ingestExternal(incoming)).status, IngestStatus.duplicate);
    final state = await container.read(ledgerControllerProvider.future);
    expect(state.balances[keys.address], 540);
  });
}
```

Run: `flutter test test/state/` — expected: FAIL.

- [ ] **Step 5: Implement `lib/state/ledger_controller.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/canonical.dart';
import '../domain/ledger.dart';
import '../domain/transaction.dart';
import '../providers.dart';

class LedgerState {
  const LedgerState({required this.balances, required this.ordered});
  final Map<String, int> balances;
  final List<Transaction> ordered;
}

class LedgerController extends AsyncNotifier<LedgerState> {
  final _ledger = Ledger();
  late LamportClock _clock;

  @override
  Future<LedgerState> build() async {
    final store = ref.read(ledgerStoreProvider);
    for (final tx in await store.loadAll()) {
      await _ledger.ingest(tx); // re-validates persisted data (defense in depth)
    }
    _clock = LamportClock(await store.loadLamport());
    return _snapshot();
  }

  LedgerState _snapshot() =>
      LedgerState(balances: _ledger.balances(), ordered: _ledger.ordered);

  Future<IngestResult> ingestExternal(Transaction tx) async {
    final result = await _ledger.ingest(tx);
    if (result.status == IngestStatus.added) {
      final store = ref.read(ledgerStoreProvider);
      await store.save(tx);
      _clock.next(_ledger.highestLamport); // observe remote clocks
      await store.saveLamport(_clock.value);
      state = AsyncData(_snapshot());
    }
    return result;
  }

  Future<Transaction> send(
      {required String to, required int amount, String? memo}) async {
    final keys = (await ref.read(walletKeysProvider.future))!;
    final tx = await buildSigned(keys: keys, to: to, amount: amount,
        memo: memo, type: txTypeTransfer,
        lamportTs: _clock.next(_ledger.highestLamport));
    // Sender ingests at signing time (spec §4.3) — stranded delivery is
    // recovered by re-showing the tx QR from History.
    final result = await _ledger.ingest(tx);
    assert(result.status == IngestStatus.added, result.reason ?? '');
    final store = ref.read(ledgerStoreProvider);
    await store.save(tx);
    await store.saveLamport(_clock.value);
    state = AsyncData(_snapshot());
    return tx;
  }

  Future<void> mintSelf() async {
    final keys = (await ref.read(walletKeysProvider.future))!;
    final tx = await buildSigned(keys: keys, to: keys.address,
        amount: mintAmount, type: txTypeMint,
        lamportTs: _clock.next(_ledger.highestLamport));
    await _ledger.ingest(tx);
    final store = ref.read(ledgerStoreProvider);
    await store.save(tx);
    await store.saveLamport(_clock.value);
    state = AsyncData(_snapshot());
  }
}
```

- [ ] **Step 6: Implement `lib/state/profile_controller.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/keys.dart';
import '../ports/profile_store.dart';
import '../providers.dart';

class ProfileController extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() => ref.read(profileStoreProvider).load();

  Future<void> createWallet(
      {required String name, required String avatar}) async {
    final keys = await WalletKeys.generate();
    await ref.read(keyVaultProvider).storeSeed(await keys.seed());
    ref.invalidate(walletKeysProvider);
    final profile = Profile(name: name, avatar: avatar, onboarded: false);
    await ref.read(profileStoreProvider).save(profile);
    state = AsyncData(profile);
    await ref.read(ledgerControllerProvider.notifier).mintSelf();
  }

  Future<void> markOnboarded() async {
    final current = state.value!;
    final updated =
        Profile(name: current.name, avatar: current.avatar, onboarded: true);
    await ref.read(profileStoreProvider).save(updated);
    state = AsyncData(updated);
  }
}
```

- [ ] **Step 7: Implement `lib/providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/keys.dart';
import 'fakes/fakes.dart';
import 'ports/biometric_gate.dart';
import 'ports/key_vault.dart';
import 'ports/ledger_store.dart';
import 'ports/peer_directory.dart';
import 'ports/profile_store.dart';
import 'ports/qr_scanner.dart';
import 'state/ledger_controller.dart';
import 'state/profile_controller.dart';

export 'state/ledger_controller.dart' show LedgerController, LedgerState;
export 'state/profile_controller.dart' show ProfileController;
export 'ports/profile_store.dart' show Profile;

const presetAvatars = ['🦫','🦜','🐸','🦊','🐙','🦔','🐳','🦩','🐢','🦉','🦄','🐝'];

final keyVaultProvider = Provider<KeyVault>((_) => throw UnimplementedError());
final biometricGateProvider =
    Provider<BiometricGate>((_) => throw UnimplementedError());
final qrScannerProvider = Provider<QrScanner>((_) => throw UnimplementedError());
final ledgerStoreProvider =
    Provider<LedgerStore>((_) => throw UnimplementedError());
final profileStoreProvider =
    Provider<ProfileStore>((_) => throw UnimplementedError());
final peerDirectoryProvider =
    Provider<PeerDirectory>((_) => throw UnimplementedError());

/// null until a wallet exists (pre-onboarding).
final walletKeysProvider = FutureProvider<WalletKeys?>((ref) async {
  final seed = await ref.watch(keyVaultProvider).loadSeed();
  return seed == null ? null : WalletKeys.fromSeed(seed);
});

final ledgerControllerProvider =
    AsyncNotifierProvider<LedgerController, LedgerState>(LedgerController.new);
final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, Profile?>(ProfileController.new);

/// Full fake set for tests and FAKE_HARDWARE runs. Pass specific instances
/// when a test needs to drive them (emit scans, deny biometrics).
List<Override> fakeHardwareOverrides(
        {FakeQrScanner? scanner, FakeBiometricGate? gate}) =>
    [
      keyVaultProvider.overrideWithValue(InMemoryKeyVault()),
      biometricGateProvider.overrideWithValue(gate ?? FakeBiometricGate()),
      qrScannerProvider.overrideWithValue(scanner ?? FakeQrScanner()),
      ledgerStoreProvider.overrideWithValue(InMemoryLedgerStore()),
      profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
      peerDirectoryProvider.overrideWithValue(InMemoryPeerDirectory()),
    ];
```

- [ ] **Step 8: Full gate + commit**

Run: `bash tool/check.sh` — expected: PASS.

```bash
git add -A && git commit -m "feat: app-state controllers and provider wiring"
```

---

### Task 4: Plugin adapters

**Bureau:** T4, Wave 4 (parallel with T5, T6), depends on T3. Only this task (and T1) touches plugin APIs. Thin passthroughs: logic stays in domain/controllers.

**Files:**
- Create: `lib/adapters/drift_db.dart`, `lib/adapters/secure_key_vault.dart`, `lib/adapters/local_auth_gate.dart`, `lib/adapters/mobile_qr_scanner.dart`, `lib/adapters/prefs_profile_store.dart`
- Test: `test/adapters/drift_db_test.dart`, `test/adapters/prefs_profile_store_test.dart`

**Interfaces:**
- Consumes (from T3, exact signatures in T3's Interfaces block): `KeyVault`, `BiometricGate`, `QrScanner`, `LedgerStore`, `ProfileStore`, `PeerDirectory`, `Profile`; (from T2): `Transaction` (`toJson`/`fromJson`), `ledgerKeyOf`.
- Produces: `AppDatabase(QueryExecutor executor)` (drift, schema v1: tables `LedgerRows{key TEXT PK, json TEXT}`, `PeerRows{addr TEXT PK, name TEXT}`, `MetaRows{k TEXT PK, v TEXT}`); `DriftLedgerStore(AppDatabase db) implements LedgerStore`; `DriftPeerDirectory(AppDatabase db) implements PeerDirectory`; `SecureKeyVault() implements KeyVault`; `LocalAuthGate() implements BiometricGate`; `MobileQrScanner() implements QrScanner`; `PrefsProfileStore() implements ProfileStore`; `AppDatabase openAppDatabase()` (uses `driftDatabase(name: 'cmo')` from drift_flutter).

- [ ] **Step 1: Failing test — drift stores (headless, in-memory)**

`test/adapters/drift_db_test.dart`:

```dart
import 'package:cash_me_outside/adapters/drift_db.dart';
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DriftLedgerStore round trips transactions and lamport', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftLedgerStore(db);
    expect(await store.loadAll(), isEmpty);
    expect(await store.loadLamport(), 0);
    final k = await WalletKeys.fromSeed(List.filled(32, 4));
    final tx = await buildSigned(keys: k, to: k.address, amount: 500,
        type: txTypeMint, lamportTs: 1);
    await store.save(tx);
    await store.save(tx); // idempotent upsert, no throw
    await store.saveLamport(7);
    final loaded = await store.loadAll();
    expect(loaded.single.toJson(), tx.toJson());
    expect(await store.loadLamport(), 7);
  });

  test('DriftPeerDirectory round trips and upserts', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dir = DriftPeerDirectory(db);
    await dir.record('a1', 'Anna');
    await dir.record('a1', 'Anna B');
    expect(await dir.nameFor('a1'), 'Anna B');
    expect(await dir.nameFor('zz'), isNull);
  });
}
```

Run: `flutter test test/adapters/drift_db_test.dart` — expected: FAIL. (If `NativeDatabase.memory()` fails to load sqlite on this machine, STOP and report — this was probed in T1; do not work around it silently.)

- [ ] **Step 2: Implement `lib/adapters/drift_db.dart`**

```dart
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../domain/canonical.dart';
import '../domain/transaction.dart' as domain;
import '../ports/ledger_store.dart';
import '../ports/peer_directory.dart';

part 'drift_db.g.dart';

class LedgerRows extends Table {
  TextColumn get key => text()(); // sha256 hex of canonical bytes
  TextColumn get json => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class PeerRows extends Table {
  TextColumn get addr => text()();
  TextColumn get name => text()();
  @override
  Set<Column> get primaryKey => {addr};
}

class MetaRows extends Table {
  TextColumn get k => text()();
  TextColumn get v => text()();
  @override
  Set<Column> get primaryKey => {k};
}

@DriftDatabase(tables: [LedgerRows, PeerRows, MetaRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  @override
  int get schemaVersion => 1;
}

AppDatabase openAppDatabase() => AppDatabase(driftDatabase(name: 'cmo'));

class DriftLedgerStore implements LedgerStore {
  DriftLedgerStore(this._db);
  final AppDatabase _db;

  @override
  Future<List<domain.Transaction>> loadAll() async {
    final rows = await _db.select(_db.ledgerRows).get();
    return rows
        .map((r) => domain.Transaction.fromJson(
            jsonDecode(r.json) as Map<String, Object?>))
        .toList();
  }

  @override
  Future<void> save(domain.Transaction tx) =>
      _db.into(_db.ledgerRows).insertOnConflictUpdate(LedgerRowsCompanion
          .insert(key: ledgerKeyOf(tx), json: jsonEncode(tx.toJson())));

  @override
  Future<int> loadLamport() async {
    final row = await (_db.select(_db.metaRows)
          ..where((t) => t.k.equals('lamport')))
        .getSingleOrNull();
    return row == null ? 0 : int.parse(row.v);
  }

  @override
  Future<void> saveLamport(int value) => _db
      .into(_db.metaRows)
      .insertOnConflictUpdate(MetaRowsCompanion.insert(k: 'lamport', v: '$value'));
}

class DriftPeerDirectory implements PeerDirectory {
  DriftPeerDirectory(this._db);
  final AppDatabase _db;

  @override
  Future<void> record(String addr, String name) => _db
      .into(_db.peerRows)
      .insertOnConflictUpdate(PeerRowsCompanion.insert(addr: addr, name: name));

  @override
  Future<String?> nameFor(String addr) async =>
      (await (_db.select(_db.peerRows)..where((t) => t.addr.equals(addr)))
              .getSingleOrNull())
          ?.name;
}
```

Run: `dart run build_runner build --delete-conflicting-outputs`, then the drift test — expected: PASS. Commit: `git add -A && git commit -m "feat: drift-backed ledger store and peer directory"`.

- [ ] **Step 3: Failing test — prefs profile store**

`test/adapters/prefs_profile_store_test.dart`:

```dart
import 'package:cash_me_outside/adapters/prefs_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cash_me_outside/ports/profile_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('round trips profile', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PrefsProfileStore();
    expect(await store.load(), isNull);
    await store.save(const Profile(name: 'J', avatar: '🦫', onboarded: true));
    final loaded = await store.load();
    expect(loaded!.name, 'J');
    expect(loaded.avatar, '🦫');
    expect(loaded.onboarded, isTrue);
  });
}
```

Run — expected: FAIL.

- [ ] **Step 4: Implement `lib/adapters/prefs_profile_store.dart`**

```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../ports/profile_store.dart';

class PrefsProfileStore implements ProfileStore {
  @override
  Future<Profile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('profile.name');
    if (name == null) return null;
    return Profile(
        name: name,
        avatar: prefs.getString('profile.avatar') ?? '🦫',
        onboarded: prefs.getBool('profile.onboarded') ?? false);
  }

  @override
  Future<void> save(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile.name', profile.name);
    await prefs.setString('profile.avatar', profile.avatar);
    await prefs.setBool('profile.onboarded', profile.onboarded);
  }
}
```

Run test — expected: PASS. Commit.

- [ ] **Step 5: Implement the three channel-backed adapters (no headless test possible — verified on the human device pass; keep them thin)**

`lib/adapters/secure_key_vault.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/keys.dart';
import '../ports/key_vault.dart';

class SecureKeyVault implements KeyVault {
  static const _storage = FlutterSecureStorage();
  static const _key = 'wallet.seed';

  @override
  Future<Uint8List?> loadSeed() async {
    final v = await _storage.read(key: _key);
    return v == null ? null : b64uDecode(v);
  }

  @override
  Future<void> storeSeed(Uint8List seed32) =>
      _storage.write(key: _key, value: b64u(seed32));
}
```

`lib/adapters/local_auth_gate.dart`:

```dart
import 'package:local_auth/local_auth.dart';
import '../ports/biometric_gate.dart';

class LocalAuthGate implements BiometricGate {
  final _auth = LocalAuthentication();

  @override
  Future<bool> get isAvailable async =>
      await _auth.isDeviceSupported() || await _auth.canCheckBiometrics;

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // spec §4.1: device-credential fallback, never biometricOnly
        options: const AuthenticationOptions(biometricOnly: false),
      );
    } catch (_) {
      return false;
    }
  }
}
```

`lib/adapters/mobile_qr_scanner.dart`:

```dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../ports/qr_scanner.dart';

class MobileQrScanner implements QrScanner {
  final _controller = StreamController<String>.broadcast();

  @override
  Stream<String> get scans => _controller.stream;

  @override
  Widget buildPreview() => MobileScanner(onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue;
          if (raw != null) _controller.add(raw);
        }
      });
}
```

- [ ] **Step 6: Full gate + commit**

Run: `bash tool/check.sh` — expected: PASS.

```bash
git add -A && git commit -m "feat: plugin adapters (secure storage, local_auth, mobile_scanner)"
```

---

### Task 5: Onboarding + root gate + wallet home

**Bureau:** T5, Wave 4 (parallel with T4, T6), depends on T3. Uses fakes only; never imports `lib/adapters/`.

**Files:**
- Create: `lib/features/onboarding/onboarding_flow.dart`, `lib/features/wallet/wallet_screen.dart`, `lib/features/wallet/radial_send_menu.dart`
- Modify: `lib/features/root/root_gate.dart` (rewrite the T1 placeholder — this file belongs to T5)
- Test: `test/features/onboarding_test.dart`, `test/features/wallet_test.dart`

**Interfaces:**
- Consumes: everything in T3's `lib/providers.dart` (providers, controllers, `presetAvatars`, `fakeHardwareOverrides`), `PinnieCoin`/`cmoAmountStyle`/`CmoColors` (T1), `truncateAddr` (T2), `CashMeOutsideApp(overrides:)` (T1).
- Produces: `RootGate` routing: profile null/`onboarded == false` → `OnboardingFlow`; onboarded → `_UnlockScreen` (biometric `authenticate('Unlock your wallet')`, retry button on failure) → `WalletScreen`. `WalletScreen` shows balance (`ᵽ N`, `cmoAmountStyle`, negatives with minus sign), 5 most recent transactions (descending `id` — UUIDv7 ids sort chronologically), and a Send button opening `RadialSendMenu` where only "QR" is enabled → `Navigator.pushNamed('/send')`; the 7 other methods render greyed with a "soon" affordance.
- Key test-visible strings/keys (T7's end-to-end test relies on these): TextField `Key('onboard.name')`, avatar tiles `Key('onboard.avatar.<emoji>')`, continue buttons `Key('onboard.next')`, mint screen `Key('onboard.mint.next')`, biometric button `Key('onboard.biometric')`, skip `Key('onboard.skip')`; wallet balance `Key('wallet.balance')`, send button `Key('wallet.send')`, radial QR item `Key('send.method.qr')`; unlock retry `Key('unlock.retry')`.

- [ ] **Step 1: Failing widget test — onboarding**

`test/features/onboarding_test.dart`:

```dart
import 'package:cash_me_outside/app.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('happy path: name → avatar → mint → biometric → wallet ᵽ500',
      (tester) async {
    await tester.pumpWidget(
        CashMeOutsideApp(overrides: fakeHardwareOverrides()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('onboard.name')), 'Jacques');
    await tester.tap(find.byKey(const Key('onboard.avatar.🦫')));
    await tester.tap(find.byKey(const Key('onboard.next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboard.mint.next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboard.biometric')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet.balance')), findsOneWidget);
    expect(find.textContaining('500'), findsWidgets);
  });

  testWidgets('no biometrics available: skip-with-warning path lands in wallet',
      (tester) async {
    await tester.pumpWidget(CashMeOutsideApp(
        overrides:
            fakeHardwareOverrides(gate: FakeBiometricGate(available: false))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('onboard.name')), 'J');
    await tester.tap(find.byKey(const Key('onboard.avatar.🦔')));
    await tester.tap(find.byKey(const Key('onboard.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboard.mint.next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboard.skip')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboard.skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet.balance')), findsOneWidget);
  });
}
```

Run — expected: FAIL.

- [ ] **Step 2: Implement `lib/features/root/root_gate.dart` (rewrite)**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../onboarding/onboarding_flow.dart';
import '../wallet/wallet_screen.dart';

class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    return profile.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Storage error: $e'))),
      data: (p) => (p == null || !p.onboarded)
          ? const OnboardingFlow()
          : const _UnlockScreen(),
    );
  }
}

class _UnlockScreen extends ConsumerStatefulWidget {
  const _UnlockScreen();
  @override
  ConsumerState<_UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<_UnlockScreen> {
  bool _unlocked = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    final ok = await ref
        .read(biometricGateProvider)
        .authenticate('Unlock your wallet');
    if (mounted) setState(() { _unlocked = ok; _failed = !ok; });
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return const WalletScreen();
    return Scaffold(
      body: Center(
        child: _failed
            ? FilledButton(
                key: const Key('unlock.retry'),
                onPressed: _tryUnlock,
                child: const Text('Unlock'))
            : const CircularProgressIndicator(),
      ),
    );
  }
}
```

- [ ] **Step 3: Implement `lib/features/onboarding/onboarding_flow.dart`**

Three-step `PageView` (`NeverScrollableScrollPhysics`, advanced programmatically). Step widgets in the same file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../theme/coin.dart';
import '../wallet/wallet_screen.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});
  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _page = PageController();
  final _name = TextEditingController();
  String _avatar = presetAvatars.first;
  bool _minting = false;

  void _next() => _page.nextPage(
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  Future<void> _createWallet() async {
    setState(() => _minting = true);
    await ref
        .read(profileControllerProvider.notifier)
        .createWallet(name: _name.text.trim(), avatar: _avatar);
    if (mounted) setState(() => _minting = false);
  }

  Future<void> _finish() async {
    await ref.read(profileControllerProvider.notifier).markOnboarded();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WalletScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: PageView(
          controller: _page,
          physics: const NeverScrollableScrollPhysics(),
          children: [_identityStep(), _mintStep(), _biometricStep()],
        ),
      );

  Widget _identityStep() => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Who's getting paid?",
                  style: Theme.of(context).textTheme.headlineMedium),
              TextField(
                  key: const Key('onboard.name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Your name')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in presetAvatars)
                    ChoiceChip(
                      key: Key('onboard.avatar.$a'),
                      label: Text(a, style: const TextStyle(fontSize: 24)),
                      selected: _avatar == a,
                      onSelected: (_) => setState(() => _avatar = a),
                    ),
                ],
              ),
              const Spacer(),
              FilledButton(
                key: const Key('onboard.next'),
                onPressed: () async {
                  if (_name.text.trim().isEmpty) return;
                  await _createWallet();
                  _next();
                },
                child: const Text('Mint my wallet'),
              ),
            ],
          ),
        ),
      );

  Widget _mintStep() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const PinnieCoin(flipOnBuild: true, size: 140),
            const SizedBox(height: 16),
            Text('ᵽ500 minted', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('onboard.mint.next'),
              onPressed: _minting ? null : _next,
              child: const Text('Continue'),
            ),
          ],
        ),
      );

  Widget _biometricStep() => Center(
        child: FutureBuilder<bool>(
          future: ref.read(biometricGateProvider).isAvailable,
          builder: (context, snap) {
            final available = snap.data ?? false;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Lock it down',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(available
                    ? 'Your fingerprint signs every send.'
                    : 'No biometrics enrolled on this device.\n'
                      'Enroll in Settings for the full experience.'),
                const SizedBox(height: 24),
                if (available)
                  FilledButton(
                    key: const Key('onboard.biometric'),
                    onPressed: () async {
                      final ok = await ref
                          .read(biometricGateProvider)
                          .authenticate('Secure your wallet');
                      if (ok) await _finish();
                    },
                    child: const Text('Enable biometric lock'),
                  )
                else
                  TextButton(
                    key: const Key('onboard.skip'),
                    onPressed: _finish,
                    child: const Text('Skip for now (unsafe, but go off)'),
                  ),
              ],
            );
          },
        ),
      );
}
```

- [ ] **Step 4: Run onboarding tests**

Run: `flutter test test/features/onboarding_test.dart` — expected: PASS (wallet_screen.dart must exist first — write Step 5's minimal version if needed, then re-run).

- [ ] **Step 5: Failing test — wallet home**

`test/features/wallet_test.dart`:

```dart
import 'package:cash_me_outside/app.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> onboard(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('onboard.name')), 'J');
  await tester.tap(find.byKey(const Key('onboard.avatar.🦫')));
  await tester.tap(find.byKey(const Key('onboard.next')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('onboard.mint.next')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('onboard.biometric')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('balance hero shows ᵽ500; radial menu has only QR enabled',
      (tester) async {
    await tester.pumpWidget(
        CashMeOutsideApp(overrides: fakeHardwareOverrides()));
    await onboard(tester);
    expect(find.byKey(const Key('wallet.balance')), findsOneWidget);
    expect(find.textContaining('ᵽ'), findsWidgets);
    await tester.tap(find.byKey(const Key('wallet.send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('send.method.qr')), findsOneWidget);
    expect(find.textContaining('soon'), findsWidgets);
  });
}
```

Run — expected: FAIL.

- [ ] **Step 6: Implement `lib/features/wallet/wallet_screen.dart` + `radial_send_menu.dart`**

`wallet_screen.dart` — balance hero + recent activity + send button:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/keys.dart';
import '../../providers.dart';
import '../../theme/tokens.dart';
import 'radial_send_menu.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerControllerProvider);
    final keys = ref.watch(walletKeysProvider);
    final profile = ref.watch(profileControllerProvider).value;
    final addr = keys.value?.address;
    final balance =
        addr == null ? 0 : (ledger.value?.balances[addr] ?? 0);
    final recent = (ledger.value?.ordered ?? []).toList()
      ..sort((a, b) => b.id.compareTo(a.id)); // UUIDv7 desc = newest first

    return Scaffold(
      appBar: AppBar(
        title: Text('${profile?.avatar ?? ''} ${profile?.name ?? ''}'),
        actions: [
          IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: () => Navigator.pushNamed(context, '/receive')),
          IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.pushNamed(context, '/history')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('ᵽ$balance',
                key: const Key('wallet.balance'),
                style: cmoAmountStyle(size: 56)),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final tx in recent.take(5))
                  ListTile(
                    dense: true,
                    leading: Icon(
                        tx.to == addr ? Icons.south_west : Icons.north_east,
                        color: tx.to == addr
                            ? CmoColors.green
                            : CmoColors.orange),
                    title: Text(tx.to == addr
                        ? '+ᵽ${tx.amount}'
                        : '−ᵽ${tx.amount}'),
                    subtitle: Text(truncateAddr(tx.to == addr ? tx.from : tx.to)),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        key: const Key('wallet.send'),
        onPressed: () => showRadialSendMenu(context),
        child: const Icon(Icons.send),
      ),
    );
  }
}
```

`radial_send_menu.dart` — plain fan-out bottom sheet (spring-physics radial polish is a later graph; keep the 8 methods visible):

```dart
import 'package:flutter/material.dart';

const _methods = [
  ('QR', Icons.qr_code_scanner, true),
  ('NFC', Icons.nfc, false),
  ('Mesh', Icons.hub, false),
  ('Contact', Icons.person, false),
  ('Radar', Icons.radar, false),
  ('Pour', Icons.local_drink, false),
  ('Rain', Icons.grain, false),
  ('Voice', Icons.mic, false),
];

void showRadialSendMenu(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (name, icon, enabled) in _methods)
            SizedBox(
              width: 84,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filled(
                    key: Key('send.method.${name.toLowerCase()}'),
                    iconSize: 32,
                    onPressed: enabled
                        ? () {
                            Navigator.pop(sheetContext);
                            Navigator.pushNamed(context, '/send');
                          }
                        : null,
                    icon: Icon(icon),
                  ),
                  Text(enabled ? name : '$name (soon)',
                      style: const TextStyle(fontSize: 11),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 7: Full gate + commit**

Run: `bash tool/check.sh` — expected: PASS. (T1's `smoke_test.dart` will now fail since RootGate no longer shows the placeholder text — update it to expect `OnboardingFlow`:)

```dart
// test/smoke_test.dart replacement expectation:
// app boots to onboarding when no profile exists
import 'package:cash_me_outside/app.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to onboarding', (tester) async {
    await tester.pumpWidget(CashMeOutsideApp(overrides: fakeHardwareOverrides()));
    await tester.pumpAndSettle();
    expect(find.text("Who's getting paid?"), findsOneWidget);
  });
}
```

```bash
git add -A && git commit -m "feat: onboarding flow, root gate, wallet home"
```

---

### Task 6: Send, receive, history

**Bureau:** T6, Wave 4 (parallel with T4, T5), depends on T3. Uses fakes only; never imports `lib/adapters/`. May import `qr_flutter` (rendering exception).

**Files:**
- Create: `lib/features/send/send_flow.dart`, `lib/features/receive/receive_screen.dart`, `lib/features/history/history_screen.dart`
- Modify: `lib/app.dart` routes — **do NOT edit `lib/app.dart`** (T1 owns it). Instead T7 registers these routes; for tests, this task pumps its screens directly.
- Test: `test/features/send_test.dart`, `test/features/receive_test.dart`, `test/features/history_test.dart`

**Interfaces:**
- Consumes: T3 providers/controllers (exact signatures in T3), `decodeQr`/`encodeReceiveRequest`/`encodeTransaction`/`ReceiveRequest`/`SignedTransactionPayload`/`QrDecodeException` (T2), `truncateAddr` (T2), `PinnieCoin`, `cmoAmountStyle`, `CmoColors.orange` (T1), `qr_flutter`'s `QrImageView`.
- Produces (T7 wires these as routes): `class SendFlow extends ConsumerStatefulWidget` (`/send`), `class ReceiveScreen extends ConsumerStatefulWidget` (`/receive`), `class HistoryScreen extends ConsumerWidget` (`/history`).
- Behavior contract: **SendFlow** = scan phase (`qrScannerProvider.buildPreview()` + listen `scans`; on `ReceiveRequest`: `peerDirectory.record(addr, name)`, → confirm phase; on decode failure: SnackBar "Not a pinnie code"; on `SignedTransactionPayload`: SnackBar "That's a payment code — use Receive") → confirm phase (amount prefilled from rr, editable; memo field; recipient name **plus `truncateAddr(addr)`**; `PinnieCoin`; Confirm → `biometricGate.authenticate('Confirm sending ᵽ<amount>')`; denial keeps the screen with SnackBar; success → `ledgerController.send(...)`) → code phase (`QrImageView(data: encodeTransaction(tx))` + "They scanned it — Done" button pops to wallet; **success is manual dismissal**, spec §4.3). **ReceiveScreen** = shows `QrImageView(data: encodeReceiveRequest(...))` for own addr/name with optional amount field; "Scan sender's code" button (`Key('receive.scan')`) swaps QR view ↔ scanner preview; on tx payload: `ledgerController.ingestExternal`; added → green "+ᵽN" state with coin; rejected → SnackBar "Counterfeit pinnies rejected"; duplicate → SnackBar "Already got those". **HistoryScreen** = all transactions, newest first by `id` desc; each `ExpansionTile` (counterparty = `peerDirectory.nameFor(addr)` or `truncateAddr`; expanded: id, lamportTs, memo, full addresses); transfers include "Show code" (`Key('history.showcode.<id>')`) opening a dialog with the tx QR (stranded-delivery recovery, spec §4.5).
- Test-visible keys: `Key('send.amount')`, `Key('send.memo')`, `Key('send.confirm')`, `Key('send.done')`, `Key('receive.amount')`, `Key('receive.scan')`, `Key('receive.showqr')`.

- [ ] **Step 1: Failing widget tests — all three screens**

`test/features/send_test.dart`:

```dart
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/features/send/send_flow.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

late FakeQrScanner scanner;
late FakeBiometricGate gate;

Future<ProviderContainer> pumpSend(WidgetTester tester,
    {bool approve = true}) async {
  scanner = FakeQrScanner();
  gate = FakeBiometricGate(approve: approve);
  final overrides = fakeHardwareOverrides(scanner: scanner, gate: gate);
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await container
      .read(profileControllerProvider.notifier)
      .createWallet(name: 'Me', avatar: '🦫');
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SendFlow())));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('scan rr → confirm (name + truncated addr) → biometric → tx QR',
      (tester) async {
    final container = await pumpSend(tester);
    final peer = await WalletKeys.fromSeed(List.filled(32, 8));
    scanner.emit(encodeReceiveRequest(
        ReceiveRequest(addr: peer.address, name: 'Anna', amount: 120)));
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text(truncateAddr(peer.address)), findsOneWidget);
    await tester.tap(find.byKey(const Key('send.confirm')));
    await tester.pumpAndSettle();
    expect(gate.authCalls, 1);
    expect(find.byType(QrImageView), findsOneWidget);
    final state = await container.read(ledgerControllerProvider.future);
    expect(state.balances[peer.address], isNull); // recipient not credited here
    await tester.tap(find.byKey(const Key('send.done')));
    await tester.pumpAndSettle();
  });

  testWidgets('biometric denial: no send, stays on confirm', (tester) async {
    final container = await pumpSend(tester, approve: false);
    final peer = await WalletKeys.fromSeed(List.filled(32, 8));
    scanner.emit(encodeReceiveRequest(
        ReceiveRequest(addr: peer.address, name: 'Anna', amount: 120)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send.confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    final state = await container.read(ledgerControllerProvider.future);
    expect(state.ordered.length, 1); // only the mint
  });

  testWidgets('malformed QR: friendly error, still scanning', (tester) async {
    await pumpSend(tester);
    scanner.emit('definitely not a pinnie code');
    await tester.pumpAndSettle();
    expect(find.text('Not a pinnie code'), findsOneWidget);
  });
}
```

`test/features/receive_test.dart`:

```dart
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:cash_me_outside/features/receive/receive_screen.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('shows own rr QR; scan-back ingests a valid tx', (tester) async {
    final scanner = FakeQrScanner();
    final container = ProviderContainer(
        overrides: fakeHardwareOverrides(scanner: scanner));
    addTearDown(container.dispose);
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'Me', avatar: '🦫');
    final myAddr = (await container.read(walletKeysProvider.future))!.address;

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReceiveScreen())));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.byKey(const Key('receive.scan')));
    await tester.pumpAndSettle();
    final sender = await WalletKeys.fromSeed(List.filled(32, 6));
    final tx = await buildSigned(keys: sender, to: myAddr, amount: 75,
        type: txTypeTransfer, lamportTs: 3);
    scanner.emit(encodeTransaction(tx));
    await tester.pumpAndSettle();
    expect(find.textContaining('+ᵽ75'), findsOneWidget);
    final state = await container.read(ledgerControllerProvider.future);
    expect(state.balances[myAddr], 575);
  });

  testWidgets('forged tx → "Counterfeit pinnies rejected"', (tester) async {
    final scanner = FakeQrScanner();
    final container = ProviderContainer(
        overrides: fakeHardwareOverrides(scanner: scanner));
    addTearDown(container.dispose);
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'Me', avatar: '🦫');
    final myAddr = (await container.read(walletKeysProvider.future))!.address;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReceiveScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('receive.scan')));
    await tester.pumpAndSettle();
    final sender = await WalletKeys.fromSeed(List.filled(32, 6));
    final tx = await buildSigned(keys: sender, to: myAddr, amount: 75,
        type: txTypeTransfer, lamportTs: 3);
    final forged = Transaction(id: tx.id, type: tx.type, from: tx.from,
        to: tx.to, amount: 9999, memo: tx.memo, lamportTs: tx.lamportTs,
        signature: tx.signature);
    scanner.emit(encodeTransaction(forged));
    await tester.pumpAndSettle();
    expect(find.text('Counterfeit pinnies rejected'), findsOneWidget);
  });
}
```

`test/features/history_test.dart`:

```dart
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/features/history/history_screen.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('lists transactions; transfer rows re-show their tx QR',
      (tester) async {
    final container = ProviderContainer(overrides: fakeHardwareOverrides());
    addTearDown(container.dispose);
    await container
        .read(profileControllerProvider.notifier)
        .createWallet(name: 'Me', avatar: '🦫');
    final peer = await WalletKeys.fromSeed(List.filled(32, 8));
    await container.read(peerDirectoryProvider).record(peer.address, 'Anna');
    final tx = await container
        .read(ledgerControllerProvider.notifier)
        .send(to: peer.address, amount: 30, memo: 'coffee');

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HistoryScreen())));
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget); // peer name, not raw addr
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    expect(find.textContaining('coffee'), findsOneWidget);
    await tester.tap(find.byKey(Key('history.showcode.${tx.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget); // stranded-delivery recovery
  });
}
```

Run: `flutter test test/features/` — expected: FAIL for the three new files.

- [ ] **Step 2: Implement `lib/features/send/send_flow.dart`**

Three-phase `ConsumerStatefulWidget` (`enum _Phase { scan, confirm, code }`). Scan phase subscribes in `initState` via `ref.read(qrScannerProvider).scans.listen(_onScan)` (cancel in `dispose`); `_onScan` wraps `decodeQr` in try/catch: `QrDecodeException` → `ScaffoldMessenger...showSnackBar(SnackBar(content: Text('Not a pinnie code')))`; `SignedTransactionPayload` → SnackBar `"That's a payment code — use Receive"`; `ReceiveRequest rr` → `ref.read(peerDirectoryProvider).record(rr.addr, rr.name)`, prefill `_amount = rr.amount?.toString() ?? ''`, `setState(_Phase.confirm)`. Confirm phase: `TextField(key: Key('send.amount'))` (numeric), `TextField(key: Key('send.memo'))`, recipient row `Text(rr.name)` + `Text(truncateAddr(rr.addr))`, `PinnieCoin(size: 72)`, `FilledButton(key: Key('send.confirm'))` → parse amount (`int.tryParse`, must be ≥1 else SnackBar) → `authenticate('Confirm sending ᵽ$amount')` → false: SnackBar `'Biometric check failed'`, stay; true → `_tx = await ledgerController.send(...)`, `setState(_Phase.code)`. Code phase: `QrImageView(data: encodeTransaction(_tx!), size: 260)`, caption `'Have them scan this with Receive'`, `FilledButton(key: Key('send.done'), onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst))` labeled `'They scanned it — Done'`. Scan phase body: `Expanded(child: ref.read(qrScannerProvider).buildPreview())` with a hazard-orange `CmoColors.orange` scan-frame overlay.

- [ ] **Step 3: Implement `lib/features/receive/receive_screen.dart`**

`ConsumerStatefulWidget`, `bool _scanning = false`, result banner state. Default view: own rr QR — reads `walletKeysProvider` + `profileControllerProvider`, optional `TextField(key: Key('receive.amount'))`; QR data rebuilt on amount change: `encodeReceiveRequest(ReceiveRequest(addr: myAddr, name: profile.name, amount: int.tryParse(...)))`. `OutlinedButton(key: Key('receive.scan'), child: Text("Scan sender's code"))` → `_scanning = true` (subscribe to scans; swap body for preview; `TextButton(key: Key('receive.showqr'))` returns). On scan: decode; `SignedTransactionPayload` → `ingestExternal`; `IngestStatus.added` → `_scanning = false`, banner `'+ᵽ${tx.amount}'` in `CmoColors.green` with `PinnieCoin(flipOnBuild: true)`; `rejected` → SnackBar `'Counterfeit pinnies rejected'`; `duplicate` → SnackBar `'Already got those'`; `ReceiveRequest`/`QrDecodeException` → SnackBar `'Not a pinnie code'`.

- [ ] **Step 4: Implement `lib/features/history/history_screen.dart`**

`ConsumerWidget`. `ordered` from ledger state sorted `b.id.compareTo(a.id)` (UUIDv7 desc = newest first). Each row: `FutureBuilder(peerDirectory.nameFor(counterpartyAddr))` → `ExpansionTile(title: Text(name ?? truncateAddr(addr)), subtitle: Text(tx.to == myAddr ? '+ᵽ${tx.amount}' : '−ᵽ${tx.amount}'))`; children: memo (if any), `id`, `lamportTs`, full from/to addresses (`SelectableText`), and for `type == txTypeTransfer` where `from == myAddr`: `TextButton(key: Key('history.showcode.${tx.id}'), child: Text('Show code'))` → `showDialog` with `QrImageView(data: encodeTransaction(tx), size: 240)` (stranded-delivery recovery). Mint rows labeled `'Minted'`.

- [ ] **Step 5: Run the three feature tests**

Run: `flutter test test/features/send_test.dart test/features/receive_test.dart test/features/history_test.dart` — expected: PASS.

- [ ] **Step 6: Full gate + commit**

Run: `bash tool/check.sh` — expected: PASS.

```bash
git add -A && git commit -m "feat: send flow, receive screen, history with tx-QR recovery"
```

---

### Task 7: Integration — real wiring, routes, end-to-end test, APK

**Bureau:** T7, Wave 5, depends on T4 + T5 + T6. The only task after T1 allowed to edit `lib/main.dart`, `lib/app.dart`, `lib/providers.dart`.

**Files:**
- Modify: `lib/main.dart`, `lib/app.dart` (add `/send`, `/receive`, `/history` routes), `lib/providers.dart` (add `realHardwareOverrides()`)
- Test: `test/integration/two_party_flow_test.dart`

**Interfaces:**
- Consumes: everything produced by T1–T6 (exact names in their Interfaces blocks).
- Produces: `List<Override> realHardwareOverrides()` in `lib/providers.dart` (drift + secure storage + local_auth + mobile_scanner + prefs); `main()` that selects fake vs real via `const bool.fromEnvironment('FAKE_HARDWARE')`; the shipped debug APK.

- [ ] **Step 1: Wire routes in `lib/app.dart`**

Add to the `routes:` map (imports from the three feature files):

```dart
'/send': (_) => const SendFlow(),
'/receive': (_) => const ReceiveScreen(),
'/history': (_) => const HistoryScreen(),
```

- [ ] **Step 2: Add real wiring**

In `lib/providers.dart` append (imports: the five adapter files):

```dart
List<Override> realHardwareOverrides() {
  final db = openAppDatabase();
  return [
    keyVaultProvider.overrideWithValue(SecureKeyVault()),
    biometricGateProvider.overrideWithValue(LocalAuthGate()),
    qrScannerProvider.overrideWithValue(MobileQrScanner()),
    ledgerStoreProvider.overrideWithValue(DriftLedgerStore(db)),
    profileStoreProvider.overrideWithValue(PrefsProfileStore()),
    peerDirectoryProvider.overrideWithValue(DriftPeerDirectory(db)),
  ];
}
```

`lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'app.dart';
import 'providers.dart';

void main() {
  const useFakes = bool.fromEnvironment('FAKE_HARDWARE');
  runApp(CashMeOutsideApp(
      overrides:
          useFakes ? fakeHardwareOverrides() : realHardwareOverrides()));
}
```

- [ ] **Step 3: Failing end-to-end test — the test plays the counterparty**

`test/integration/two_party_flow_test.dart`:

```dart
import 'package:cash_me_outside/app.dart';
import 'package:cash_me_outside/domain/keys.dart';
import 'package:cash_me_outside/domain/ledger.dart';
import 'package:cash_me_outside/domain/qr_codec.dart';
import 'package:cash_me_outside/domain/transaction.dart';
import 'package:cash_me_outside/fakes/fakes.dart';
import 'package:cash_me_outside/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets(
      'full two-party flow: onboard → send to peer → receive from peer → history',
      (tester) async {
    final scanner = FakeQrScanner();
    final container = ProviderContainer(
        overrides: fakeHardwareOverrides(scanner: scanner));
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const CashMeOutsideApp()));
    await tester.pumpAndSettle();

    // Onboard.
    await tester.enterText(find.byKey(const Key('onboard.name')), 'Jacques');
    await tester.tap(find.byKey(const Key('onboard.avatar.🦫')));
    await tester.tap(find.byKey(const Key('onboard.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboard.mint.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboard.biometric')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ᵽ500'), findsWidgets);
    final myAddr = (await container.read(walletKeysProvider.future))!.address;

    // The test IS the counterparty: Anna's device exists only as keys + payloads.
    final anna = await WalletKeys.fromSeed(List.filled(32, 11));

    // SEND: navigate, "scan" Anna's rr, confirm, biometric, tx QR, done.
    await tester.tap(find.byKey(const Key('wallet.send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send.method.qr')));
    await tester.pumpAndSettle();
    scanner.emit(encodeReceiveRequest(
        ReceiveRequest(addr: anna.address, name: 'Anna', amount: 120)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send.confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.tap(find.byKey(const Key('send.done')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ᵽ380'), findsWidgets); // 500 - 120

    // RECEIVE: Anna pays 75 back; her tx arrives as a scanned QR.
    final annaTx = await buildSigned(keys: anna, to: myAddr, amount: 75,
        type: txTypeTransfer, lamportTs: 5);
    await tester.tap(find.byIcon(Icons.qr_code));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('receive.scan')));
    await tester.pumpAndSettle();
    scanner.emit(encodeTransaction(annaTx));
    await tester.pumpAndSettle();
    expect(find.textContaining('+ᵽ75'), findsOneWidget);

    // Ledger truth: both directions applied.
    final state = await container.read(ledgerControllerProvider.future);
    expect(state.balances[myAddr], 455); // 500 - 120 + 75
    expect(state.balances[anna.address], 45); // 120 - 75
    expect(state.ordered.length, 3);
  });

  testWidgets('onboarding persists: relaunch lands on unlock, not onboarding',
      (tester) async {
    final profileStore = InMemoryProfileStore();
    final vault = InMemoryKeyVault();
    final overrides = [
      ...fakeHardwareOverrides(),
      profileStoreProvider.overrideWithValue(profileStore),
      keyVaultProvider.overrideWithValue(vault),
    ];
    // First launch: onboard fully.
    var container = ProviderContainer(overrides: overrides);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const CashMeOutsideApp()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('onboard.name')), 'J');
    await tester.tap(find.byKey(const Key('onboard.avatar.🦫')));
    await tester.tap(find.byKey(const Key('onboard.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboard.mint.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboard.biometric')));
    await tester.pumpAndSettle();
    container.dispose();

    // "Relaunch": same stores, fresh container — must hit unlock then wallet.
    container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const CashMeOutsideApp()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet.balance')), findsOneWidget);
    expect(find.byKey(const Key('onboard.name')), findsNothing);
  });
}
```

Run — expected: FAIL until routes/wiring land, then PASS.

- [ ] **Step 4: Full gate**

Run: `bash tool/check.sh` — expected: PASS, all suites.

- [ ] **Step 5: APK (skip only if T1's `tool/PROBE.md` recorded APK_UNAVAILABLE)**

Run: `flutter build apk --debug` — expected: success. Record the artifact path in the task report. Also verify the fake-hardware web click-through still compiles: `flutter build web --dart-define=FAKE_HARDWARE=true`.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: real adapter wiring, routes, two-party e2e test"
```

---

### Task 8: Independent conformance review (gate)

**Bureau:** T8, Wave 5, depends on T7. Reviewer task — reads code, runs checks, produces a verdict. **Do not fix code; report findings.** Workers' green is not trusted without this gate.

**Files:** none created (a findings report is the deliverable, returned as the task result).

**Checklist (each item: state PASS/FAIL with file:line evidence):**

- [ ] Canonical bytes conform to spec §2.1: exact key order `amount,from,id,lamportTs,memo,to,type`, memo always present/null, jsonEncode, signature excluded; verifier re-canonicalizes from parsed fields (`verifyTransactionSignature` called with `canonicalBytesOf(tx)`, never with bytes from the wire).
- [ ] Ledger conforms to spec §2.2: set key = SHA-256 of canonical bytes; replay order `(lamportTs, id)`; mint requires `from==to && amount==500`, first-in-replay-order wins; amount range enforced; unknown types retained-but-ignored; negative balances flow through to UI unclamped.
- [ ] Signature verification is bound to the `from` field everywhere a transaction enters the system (grep for `verifyTransactionSignature` call sites; confirm no path ingests without it except the duplicate short-circuit).
- [ ] QR formats conform to spec §3: `cmo:rr1:`/`cmo:tx1:`, unpadded base64url, every malformed input path throws `QrDecodeException`, all UI decode sites catch it.
- [ ] Fake/adapter parity: every port has both a fake and an adapter with matching semantics (e.g. drift store upsert vs in-memory append — confirm `loadAll` after double-save yields one row in both).
- [ ] Android config per spec §2.4: `FlutterFragmentActivity`, AppCompat launch theme (both values/ and values-night/), `USE_BIOMETRIC`, `CAMERA`, `allowBackup="false"`, minSdk 24, compileSdk 36, applicationId `dev.jcqb.cashmeoutside`.
- [ ] No plugin imports outside `lib/adapters/` (allowed exception: `qr_flutter` in features); no feature imports of `lib/adapters/`.
- [ ] `tool/check.sh` passes from a clean checkout (`git stash -u` any local noise first); test names claimed in Tasks 2–7 all exist and run.
- [ ] rr `name` is never displayed without the truncated address beside it (spec §3).
- [ ] Sender-side stranded-delivery recovery exists: History exposes the tx QR for own outgoing transfers.
- [ ] `tool/PROBE.md` exists and records the toolchain verdict; if APK_OK, a debug APK build was reported by T7.

Return the completed checklist with evidence as the task result.

---

## Plan Self-Review (completed)

- **Spec coverage:** §1 flows → T5/T6/T7; §2.1 → T2; §2.2 → T2; §2.3 ports → T3; §2.4 adapters + Android → T4/T1; §2.5 fakes → T3; §2.6 theme → T1; §3 QR → T2; §4 screens → T5/T6; §5 error handling → T2 (codec/ledger) + T6 (UI paths); §6 gates → T1 check.sh + per-task steps + T8; §7 graph → task headers. Human device pass stays with the owner (spec §6) — not a plan task.
- **Known deviation from spec sketch:** spec §7 put T2∥T3 in one wave; this plan serializes them (T3 imports T2's `Transaction`/`WalletKeys`) and runs T4∥T5∥T6 in the wave after. Spec §7 explicitly delegates final graph shape to kickoff.
- **Type consistency:** provider names, controller methods, widget keys, and domain signatures are declared once in their producing task's Interfaces block and repeated verbatim where consumed.
