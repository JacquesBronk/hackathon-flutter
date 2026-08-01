# Cash Me Outside — Design Spec

**Hackathon build · Fake money transfer app · Currency: Pinnies (ᵽ)**

---

## 1. Concept

Cash Me Outside is a playful peer-to-peer wallet for a fake currency called pinnies. The core hook: pinnies can travel across a **BLE gossip mesh**, hopping phone-to-phone until they reach the recipient — even with no internet, no server, no cell signal. Around that core, every transfer method is a native-integration showcase: tap it, scan it, pour it, shake it, point at it, or shout it.

**Tagline:** *"Cash me outside — how 'bout dat(a transfer)."*

---

## 2. Framework decision

**Choice: Flutter.**

| Criterion | Flutter | React Native |
|---|---|---|
| BLE central + peripheral | `flutter_blue_plus` + `bluetooth_low_energy` (peripheral mode) | `react-native-ble-plx` (central-focused; peripheral needs extra native work) |
| NFC | `nfc_manager` (read/write, Android HCE via `nfc_host_card_emulation`) | `react-native-nfc-manager` (solid, similar limits) |
| Biometrics | `local_auth` | `react-native-biometrics` |
| Sensors (shake/tilt/compass) | `sensors_plus`, `flutter_compass` | `react-native-sensors` |
| Animation polish | First-class (implicit animations, Hero, CustomPainter, Rive) | Reanimated 3 (good, more setup) |
| Phone/tablet/desktop/web from one codebase | Yes, genuinely | Web is a separate story |
| Team familiarity | Neither team is native to either — tie | Tie |

Flutter gets us the polish, responsiveness, and sensor bonuses with the least native-module plumbing. Verify current plugin versions at build time — the ecosystem moves fast.

---

## 3. Architecture

### 3.1 Identity & security
- On first launch: generate an **Ed25519 keypair** on-device (`cryptography` package). Public key = wallet address. Display name + avatar attached.
- Private key stored in secure storage (`flutter_secure_storage`), gated behind **biometric auth** (`local_auth`) — required at app unlock and to sign any outgoing transaction. *(This satisfies the mandatory biometrics requirement in a way that's structural, not bolted on.)*

### 3.2 Ledger (local-first, offline-first)
- Every device holds a full copy of the ledger: an append-only set of **signed transactions**.
- Transaction = `{ id (UUIDv7), from, to, amount, memo, lamportTs, signature }`.
- Merging two ledgers = set union + signature verification (a grow-only CRDT set). No conflicts possible; balances are derived by replaying the set.
- Fake money means double-spend is a feature, not a bug — but signatures still prevent forgery, which makes the mesh relay story credible to judges.
- Persisted in `drift` (SQLite). App is fully functional with airplane mode on. **← Offline bonus.**

### 3.3 BLE gossip mesh ("The Pinnie Net")
- Every phone runs as **both central and peripheral** simultaneously:
  - **Peripheral:** advertises service UUID `0xCA5E` with a truncated wallet ID in manufacturer data.
  - **Central:** scans for the same UUID, connects to nearby nodes, exchanges data over a GATT characteristic (chunked JSON or CBOR; MTU-negotiate to 512).
- **Gossip protocol (flooding, not routing):**
  1. Node receives a message (chat or transaction envelope).
  2. If `msgId` already in seen-cache → drop.
  3. Else: store, apply locally if addressed to self, decrement `ttl` (start at 8), re-broadcast to all connected peers if `ttl > 0`.
- **Store-and-forward:** undelivered messages persist and retransmit when new peers appear — a pinnie can literally wait in your pocket and hop onward an hour later.
- **Chat rides the same pipe:** messages are just unsigned-amount envelopes. One protocol, two features.
- iOS backgrounding constraint: iOS throttles BLE advertising in background. Demo with apps foregrounded; mention background limits honestly if asked.

### 3.4 Sync tiers
1. **NFC tap** — instant, intimate, two devices touching.
2. **BLE direct** — same room.
3. **BLE mesh** — across the venue, hopping through strangers' phones.
4. **QR** — works across any distance you can photograph, fully offline.

No server exists. That's the flex.

---

## 4. Transfer methods (requirement coverage matrix)

| # | Method | Native integration ticked | How it works |
|---|---|---|---|
| 1 | **Scan-to-pay** | QR generation + scanning, camera | Recipient shows QR (`wallet address + optional amount + signature`); sender scans with `mobile_scanner`, confirms with biometrics. WeChat-style. QR can also encode a full signed transaction for sneakernet transfer between offline devices. |
| 2 | **Tap-to-pay (NFC)** | NFC read/write | Android↔Android: receiver runs HCE (host card emulation), sender reads and pushes a payment intent. **iOS cannot do HCE** — so cross-platform we use **NTAG payment stickers**: write a payment request (or a claimable pinnie voucher) to a physical tag; anyone taps to claim. Stick a ᵽ50 tag under a chair. Chaos. |
| 3 | **Mesh send** | Bluetooth / local discovery | Pick any user ever seen on the mesh; transaction gossips hop-by-hop until it lands. UI shows hop count on delivery receipt: *"arrived via 3 phones."* |
| 4 | **Send to contact** | Contacts access | Pick from device contacts (`flutter_contacts`); match by phone-number hash against known wallet directory (exchanged during pairing); unmatched contacts get a QR/link invite. |
| 5 | **Radar pay** | Compass + BLE RSSI | Full-screen radar: nearby mesh nodes plotted by RSSI (distance) and, where two phones share heading data, compass bearing. Physically **point your phone at someone** and their blip highlights; tap to pay. |
| 6 | **Pour-to-pay** 🏆 | Gyroscope + accelerometer + BLE | The signature gimmick. Open a pending transfer, then **tilt your phone like a jug**. Tilt angle streams over BLE; pinnies visibly drain out of your screen (particle animation) and splash into the recipient's wallet in real time. Tilt back to stop mid-pour. Judges will remember this one. |
| 7 | **Make it rain** | BLE broadcast + accelerometer | Set an amount, **shake vigorously**: the amount splits randomly across every node currently on the mesh. Confetti + push notification storm on every recipient device. |
| 8 | **Voice send** | Speech recognition (`speech_to_text`) | "Send fifty pinnies to Jacques." Parses intent locally, prefills the confirm screen — biometric confirm still required (no accidental voice payments). |

### Cross-cutting native features
- **Shake-to-cancel:** during the 5-second "sending…" window on any transfer, shake the phone to abort (accelerometer threshold + haptic feedback + rewind animation). Doubles as undo.
- **Push notifications:** local notifications (`flutter_local_notifications`) for incoming pinnies, mesh relay events ("your phone just relayed ᵽ20 for a stranger 🕵️"), and rain events. No server, so no FCM needed — everything fires off BLE events.
- **Photo capture:** attach a photo memo to any payment ("here's the pizza you owe me for"), stored locally, thumbnail in history.
- **Calendar (stretch):** "Split this event" — pick a calendar event, auto-split a bill among attendees who are on the mesh.

---

## 5. Screens

1. **Onboarding** — name + avatar, keypair generation (show a fun "minting your wallet" animation), biometric enrollment. Three screens, under 30 seconds.
2. **Wallet (home)** — balance hero, recent activity, one thumb-reachable **Send** button that fans out into the 8 transfer methods as a radial menu (gesture bonus: drag from the button to a method in one motion).
3. **Radar** — the mesh visualized. Nodes as animated blips, connection lines pulsing when gossip traffic flows, hop animations when a relayed message passes through *your* phone.
4. **Chat** — per-peer thread over the mesh; inline pinnie sends inside chat (`+ᵽ` chip); delivery states: sent → hopping (animated) → delivered (with hop count).
5. **Receive** — your QR, NFC-active indicator, "expecting a pour" catch mode (cup animation fills as pinnies arrive).
6. **History** — ledger view, filterable, each entry expandable to show route taken (which is genuinely cool forensics: "via Thabo's phone → via Anna's phone → you").
7. **Settings** — biometric toggle-off blocked with a joke ("nice try"), mesh relay opt-out, accessibility options.

---

## 6. Visual direction

The temptation is neon-fintech (dark background, acid green). Skip it — every hackathon wallet looks like that. Instead lean into the **street-cash absurdity of the name**: 

- **Palette:** warm counterfeit-bill green (`#3E6B4F`) and aged-paper cream (`#F2EBD9`) as the base, with a loud **hazard orange** (`#FF5A1F`) reserved exclusively for money-in-motion moments (pours, rains, hops). Ink navy (`#1E2733`) for text, brass (`#C9A54A`) for the pinnie coin itself.
- **Type:** a chunky slab or stencil display face for amounts and headers (money-printing energy), a clean grotesque for body, tabular figures everywhere numbers appear.
- **Signature element:** the **pinnie coin** — a single, lovingly animated brass coin that is the through-line of every interaction: it flips on send, pours in streams, rains as confetti, and hops across the radar. One asset, reused everywhere, is cheaper than ten animations and reads as a design system.
- **Micro-interactions:** haptics on every money event (light tick per pinnie during a pour — this feels *incredible*), spring physics on the radial send menu, hero transition of the coin from wallet to confirm screen.
- **Accessibility (bonus):** semantic labels on all custom-painted widgets, `MediaQuery.textScaler` respected (test at 200%), contrast-checked palette (the cream/navy pair clears WCAG AA), reduced-motion mode swaps particle pours for a progress bar. Screen-reader announcement on received pinnies.
- **Responsive (bonus):** wallet is single-column on phones; tablet/desktop/web splits into wallet + persistent radar side-by-side. Radar scales to any canvas since it's a CustomPainter.

---

## 7. Build plan & team split (assuming ~3 devs, 2 days)

**Day 1 AM — walking skeleton:** keypair + biometric gate + local ledger + QR send/receive end-to-end. *This alone meets the entry requirement (biometrics) plus QR + camera.* Everything after is upside.

**Day 1 PM:**
- Dev A: BLE peripheral+central plumbing, direct 1-hop send.
- Dev B: NFC (Android HCE + NTAG sticker write/read).
- Dev C: UI system — wallet, radial send menu, coin asset + animations.

**Day 2 AM:**
- Dev A: gossip layer (seen-cache, TTL, store-and-forward) + radar screen.
- Dev B: sensors — pour-to-pay, shake-to-cancel, make-it-rain.
- Dev C: chat, notifications, history with hop routes, accessibility pass.

**Day 2 PM:** contacts integration, voice (if time), demo rehearsal ×3, and cut anything not demo-ready. **Cut order (first to go):** calendar split → voice → contacts → rain. **Never cut:** biometrics, QR, one BLE hop, pour.

### Risk register
| Risk | Mitigation |
|---|---|
| iOS NFC can't do phone-to-phone | NTAG stickers as the cross-platform NFC story; Android↔Android HCE as the tap demo |
| BLE peripheral mode flaky on some Androids | Test on all team hardware Day 1; fall back to advertising-packet-only discovery + central-to-central alternating roles |
| iOS background BLE throttling | Demo foregrounded; frame store-and-forward as the honest answer |
| Mesh needs ≥3 devices to look like a mesh | Borrow phones; the demo script assumes 4 devices |
| Emulators can't do BLE/NFC/biometrics | All development on real hardware from hour one |

---

## 8. Judge demo script (5 minutes)

1. **Cold open (30s):** airplane mode ON, all four phones. "No internet, no server, no SIM. Watch."
2. **Biometric unlock** on stage — fingerprint, wallet appears. *(Entry requirement, shown first and unmissably.)*
3. **QR pay** phone A→B. Instant. Boring on purpose — "that's table stakes."
4. **Pour-to-pay** A→B: tilt the phone, pinnies stream with haptics audible-ish in a quiet room. This is the applause moment.
5. **The mesh:** phones B and C placed across the room as relays. A sends to D. Radar shows the hops live; D's notification fires; open history: *"arrived via 2 phones."*
6. **Shake-to-cancel** a mistaken send, then **make it rain** on all four devices as the closer — confetti + notification storm.
7. **One-liner exit:** "Every feature you saw used a different device capability, and none of it touched a network."

---

## 9. Requirement scorecard

| Requirement | Covered by |
|---|---|
| QR scan/generate | Scan-to-pay, offline voucher QRs |
| NFC read/write | HCE tap-to-pay, NTAG payment stickers |
| Camera/photo | QR scanner, photo memos |
| Contacts/calendar/files | Send-to-contact; calendar split (stretch); ledger export to file (trivial add) |
| Push notifications | Local notifications on receive/relay/rain |
| **Biometrics (required)** | App unlock + transaction signing gate |
| Bluetooth/local discovery | BLE gossip mesh, radar |
| *Bonus:* sensors | Pour (gyro), shake (accel), radar (compass) |
| *Bonus:* responsive | Phone/tablet/desktop/web layouts |
| *Bonus:* polish | Coin design system, haptics, spring physics |
| *Bonus:* offline | Entire architecture is offline-first |
| *Bonus:* performance | Local SQLite, no network waits, isolate for ledger replay |
| *Bonus:* accessibility | Semantics, text scaling, contrast, reduced motion |
