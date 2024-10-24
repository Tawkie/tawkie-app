import 'package:flutter/material.dart';
import 'package:tawkie/utils/platform_infos.dart';

class PlatformAvatar extends StatelessWidget {
  final String platform;

  const PlatformAvatar({super.key, required this.platform});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: PlatformInfos.getPlatformBackgroundColor(platform),
          radius: 15,
          child: PlatformInfos.getPlatformIcon(platform),
        ),
      ],
    );
  }
}
