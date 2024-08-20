import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tawkie/services/matomo/tracking_service.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:tawkie/config/app_config.dart';

class NPSWidget extends StatefulWidget {
  const NPSWidget({super.key});

  @override
  State<NPSWidget> createState() => _NPSWidgetState();
}

class _NPSWidgetState extends State<NPSWidget> {
  int _selectedScore = -1;

  void _submitScore() {
    if (_selectedScore >= 0) {
      final trackingService = Provider.of<TrackingService>(context, listen: false);
      trackingService.trackNPSScore(_selectedScore);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context)!.npsResponse)),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = AppConfig.primaryColor;
    final Color secondaryColor = AppConfig.secondaryColor;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            L10n.of(context)!.npsQuestion,
            textAlign: TextAlign.center,
            style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Center(
            child: Wrap(
              spacing: 8.0,
              alignment: WrapAlignment.center,
              children: List.generate(11, (index) {
                Color backgroundColor;
                if (index < 4) {
                  backgroundColor = Colors.red;
                } else if (index < 7) {
                  backgroundColor = Colors.orange;
                } else {
                  backgroundColor = Colors.green;
                }

                return ChoiceChip(
                  label: Text('$index'),
                  selected: _selectedScore == index,
                  onSelected: (bool selected) {
                    setState(() {
                      _selectedScore = index;
                    });
                  },
                  selectedColor: primaryColor.withOpacity(0.2),
                  backgroundColor: _selectedScore == index
                      ? primaryColor
                      : backgroundColor,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                  ),
                  side: BorderSide(
                    color: _selectedScore == index ? primaryColor : secondaryColor,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _submitScore,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: Text(L10n.of(context)!.submit),
          ),
        ],
      ),
    );
  }
}

void showNPSDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return const FractionallySizedBox(
        child: NPSWidget(),
      );
    },
  );
}
