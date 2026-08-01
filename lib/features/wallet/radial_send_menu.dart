import 'package:flutter/material.dart';

const _methods = [
  ('QR', Icons.qr_code_scanner, '/send'),
  ('NFC', Icons.nfc, null),
  ('Mesh', Icons.hub, '/send-mesh'),
  ('Contact', Icons.person, null),
  ('Radar', Icons.radar, null),
  ('Pour', Icons.local_drink, null),
  ('Rain', Icons.grain, null),
  ('Voice', Icons.mic, null),
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
          for (final (name, icon, route) in _methods)
            SizedBox(
              width: 84,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filled(
                    key: Key('send.method.${name.toLowerCase()}'),
                    iconSize: 32,
                    onPressed: route == null
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            Navigator.pushNamed(context, route);
                          },
                    icon: Icon(icon),
                  ),
                  Text(
                    route == null ? '$name (soon)' : name,
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
