import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:tawkie/pages/tickets/tickets.dart';

class TicketCreationPage extends StatefulWidget {
  final TicketsController controller;

  const TicketCreationPage({super.key, required this.controller});

  @override
  State<TicketCreationPage> createState() => _TicketCreationPageState();
}

class _TicketCreationPageState extends State<TicketCreationPage> {
  final TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context)!.ticketsOpenReport),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.of(context)!.ticketsDescribe,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: L10n.of(context)!.ticketsDescribeHint,
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await showFutureLoadingDialog(
                      context: context,
                      future: () =>
                          widget.controller.openNewTicket(
                            userMessage: _descriptionController.text,
                          ));

                  context.pop();
                },
                child: Text(L10n.of(context)!.send),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
