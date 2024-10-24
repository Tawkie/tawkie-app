import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:tawkie/config/app_config.dart';
import 'package:tawkie/pages/tickets/ticket_tile.dart';
import 'package:tawkie/pages/tickets/tickets.dart';

class TicketsPage extends StatelessWidget {
  final TicketsController controller;

  const TicketsPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final tickets = controller.filteredTickets;
    return Scaffold(
      body: Stack(
        children: [
          // Main content (Ticket List)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 180.0, 16.0, 16.0),
            // Adjusting for space with AppBar
            child: Column(
              children: [
                tickets.isNotEmpty
                    ? Expanded(
                        child: ListView.builder(
                          itemCount: tickets.length,
                          itemBuilder: (context, index) {
                            final ticket = tickets[index];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 5.0),
                              child: TicketTile(
                                title: ticket.content,
                                platForm: ticket.platform,
                                date: ticket.date,
                                status: ticket.status,
                                roomId: ticket.roomId!,
                              ),
                            );
                          },
                        ),
                      )
                    : Expanded(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height / 2,
                          child: Center(
                            child: Text(L10n.of(context)!.ticketsPageEmpty),
                          ),
                        ),
                      ),
              ],
            ),
          ),

          // Custom AppBar with Stack
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180, // Custom height for the AppBar
              decoration: const BoxDecoration(
                color: Color(0xFF464544),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 40,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            Text(
                              L10n.of(context)!.ticketsReports,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.insert_drive_file,
                                size: 30, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              tickets.length.toString(),
                              style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                  // Search bar inside AppBar
                  Positioned(
                    bottom: 40,
                    left: 16,
                    right: 16,
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: L10n.of(context)!.search,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: const TextStyle(color: Colors.black),
                      onChanged: (value) {
                        controller.filterTickets(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Open Tickets Button (placed to overlap the AppBar)
          Positioned(
            top: 155, // Centered horizontally
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    context.push(
                      '/rooms/settings/tickets/new',
                      extra: controller,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColorLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 32),
                  ),
                  child: Text(L10n.of(context)!.ticketsOpenReport,
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
