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
                  Text(
                    enabled ? name : '$name (soon)',
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
