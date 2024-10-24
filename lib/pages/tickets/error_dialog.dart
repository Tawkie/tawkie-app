import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

void showErrorDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(L10n.of(context)!.err_),
        content: Text(L10n.of(context)!.rateLimit),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(L10n.of(context)!.close),
          ),
        ],
      );
    },
  );
}
