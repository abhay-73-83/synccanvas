import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../screens/room_screen.dart';

class RecentRoomsList extends StatefulWidget {
  const RecentRoomsList({super.key});

  @override
  State<RecentRoomsList> createState() => _RecentRoomsListState();
}

class _RecentRoomsListState extends State<RecentRoomsList> {
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();
  String? _joiningRoomId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RoomProvider>(context, listen: false).loadRecentRooms();
    });
  }

  Future<void> _reconnectToRoom(String roomId) async {
    setState(() {
      _joiningRoomId = roomId;
    });

    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      final room = await _firestoreService.getRoomByCode(roomId);
      if (!mounted) return;

      setState(() {
        _joiningRoomId = null;
      });

      if (room == null) {
        // Room no longer exists in Firestore: remove stale room code & refresh list
        await roomProvider.removeRecentRoom(roomId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Room $roomId no longer exists. Removed from recent rooms.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (room.isExpired) {
        // Room has expired: remove from recent rooms, refresh list & show error message
        await roomProvider.removeRecentRoom(roomId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This room has expired.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final joinedRoom = await _firestoreService.joinRoom(roomId);
      if (joinedRoom == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not reconnect to room. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _storageService.saveLastOpenedRoom(roomId);
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RoomScreen(room: joinedRoom),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _joiningRoomId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reconnecting to room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    final rooms = roomProvider.recentRooms;

    if (rooms.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No recent rooms',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create or join a room to get started!',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rooms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final roomId = rooms[index];
        final isJoiningThis = _joiningRoomId == roomId;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: Colors.deepPurple,
              ),
            ),
            title: Text(
              'Room: $roomId',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Tap to reconnect'),
            trailing: isJoiningThis
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _joiningRoomId != null ? null : () => _reconnectToRoom(roomId),
          ),
        );
      },
    );
  }
}

