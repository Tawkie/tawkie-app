import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:tawkie/widgets/matrix.dart';

Future<List<Room>> getFilteredRooms(
    BuildContext context, {
      String? key,
      bool Function(Room room)? additionalFilter,
    }) async {
  final client = Matrix.of(context).client;
  final allRooms = client.rooms;
  final filteredRooms = <Room>[];

  for (var room in allRooms) {
    // Filtrage de base par key
    if (key != null) {
      try {
        await client.getRoomStateWithKey(room.id, key, '');
      } catch (e) {
        if (kDebugMode) {
          print('No metadata found for room ${room.id} with key $key: $e');
        }
        continue;
      }
    }

    // Apply additional filter if present
    if (additionalFilter == null || additionalFilter(room)) {
      filteredRooms.add(room);
    }
  }

  return filteredRooms;
}
