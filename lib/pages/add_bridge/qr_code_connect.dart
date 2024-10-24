import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tawkie/pages/add_bridge/add_bridge.dart';
import 'package:tawkie/pages/add_bridge/model/social_network.dart';

class QRCodeConnectPage extends StatefulWidget {
  final String? qrCode;
  final String? code;
  final dynamic stepData;
  final BotController botConnection;
  final SocialNetwork socialNetwork;

  const QRCodeConnectPage({
    super.key,
    this.qrCode,
    this.code,
    this.stepData,
    required this.botConnection,
    required this.socialNetwork,
  });

  @override
  State<QRCodeConnectPage> createState() => _QRCodeConnectPageState();
}

class _QRCodeConnectPageState extends State<QRCodeConnectPage> {
  late Future<void> responseFuture;

  @override
  void initState() {
    super.initState();
    widget.botConnection.continueProcess = true;

    if (widget.socialNetwork.name == "WhatsApp") {
      responseFuture = Future(() async {
        await widget.botConnection.checkLoginStatus(widget.socialNetwork,  widget.stepData);
      });
    }
  }


  @override
  void dispose() {
    widget.botConnection.stopProcess();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${L10n.of(context)!.connectYourSocialAccount} ${widget.socialNetwork.name}",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QRExplanation(
                network: widget.socialNetwork,
                qrCode: widget.qrCode,
                code: widget.code,
              ),
              const SizedBox(height: 16),
              QRFutureBuilder(
                responseFuture: responseFuture,
                network: widget.socialNetwork,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Connection explanation section
class QRExplanation extends StatelessWidget {
  final SocialNetwork network;
  final String? qrCode;
  final String? code;

  const QRExplanation({
    super.key,
    required this.network,
    this.qrCode,
    this.code,
  });

  @override
  Widget build(BuildContext context) {
    List<String> qrExplains = [];
    Widget? qrWidget;
    Widget? codeWidget;

    if (network.name == "WhatsApp") {
      qrExplains = [
        L10n.of(context)!.whatsAppQrExplainOne,
        L10n.of(context)!.whatsAppQrExplainTwo,
        L10n.of(context)!.whatsAppQrExplainTree,
        L10n.of(context)!.whatsAppQrExplainFour,
        L10n.of(context)!.whatsAppQrExplainFive,
        L10n.of(context)!.whatsAppQrExplainSix,
        L10n.of(context)!.whatsAppQrExplainSeven,
        L10n.of(context)!.whatsAppQrExplainEight,
        L10n.of(context)!.whatsAppQrExplainNine,
      ];

      if (qrCode != null) {
        qrWidget = QrImageView(
          data: qrCode!,
          version: QrVersions.auto,
          size: 300,
          backgroundColor: Colors.white,
        );
      }

      if (code != null) {
        codeWidget = ElevatedButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code!));
            final SnackBar snackBar = SnackBar(content: Text(L10n.of(context)!.codeCopy));
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          },
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Text(
              code!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                decoration: null,
                color: Colors.blue,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        ...qrExplains.take(5).map((text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        )),
        const SizedBox(height: 8),
        if (codeWidget != null) codeWidget,
        if (qrWidget != null) qrWidget,
        const SizedBox(height: 8),
        const Divider(
          color: Colors.grey,
          height: 20,
        ),
        if(qrWidget != null)
          ...qrExplains.skip(5).map(
                (text) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(text,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}


// FutureBuilder part listening to responses in real time
class QRFutureBuilder extends StatelessWidget {
  final Future<void> responseFuture;
  final SocialNetwork network;

  const QRFutureBuilder({
    super.key,
    required this.responseFuture,
    required this.network,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: responseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container();
        } else if (snapshot.hasError) {
          return Text('${L10n.of(context)!.err_} ${snapshot.error}');
        } else {
          return Container();
        }
      },
    );
  }
}
