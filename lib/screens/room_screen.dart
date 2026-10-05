import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../models/canvas_item.dart';
import '../providers/room_provider.dart';
import '../providers/canvas_provider.dart';
import '../providers/user_provider.dart';
import '../services/export_service.dart';
import '../services/storage_upload_service.dart';
import '../widgets/sticky_note.dart';
import '../widgets/text_card.dart';
import '../widgets/image_card.dart';
import '../widgets/link_card.dart';

class RoomScreen extends StatefulWidget {
  final Room room;

  const RoomScreen({
    super.key,
    required this.room,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final GlobalKey _canvasExportKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();
  final StorageUploadService _storageUploadService = StorageUploadService();
  final ExportService _exportService = ExportService();

  bool _isUploadingImage = false;
  bool _isExporting = false;
  Timer? _expirationTimer;

  @override
  void initState() {
    super.initState();
    _expirationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      final canvasProvider = Provider.of<CanvasProvider>(context, listen: false);

      roomProvider.watchRoom(widget.room.roomCode);
      canvasProvider.startListeningToCanvas(widget.room.roomCode);
    });
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }

  Future<void> _leaveRoom() async {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final canvasProvider = Provider.of<CanvasProvider>(context, listen: false);

    canvasProvider.stopListening();
    await roomProvider.leaveRoom();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Exports the RepaintBoundary canvas area as a PNG file and launches the Share sheet.
  Future<void> _exportCanvas() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      final roomName = roomProvider.currentRoom?.roomName ?? widget.room.roomName;

      final success = await _exportService.exportAndShareCanvas(
        boundaryKey: _canvasExportKey,
        roomName: roomName,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to export canvas PNG. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting canvas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  /// Handles picking an image from gallery, uploading to Firebase Storage,
  /// and creating a canvas item with the resulting download URL.
  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Selected image file is empty or invalid.');
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final downloadUrl = await _storageUploadService.uploadRoomImageBytes(
        roomCode: widget.room.roomCode,
        bytes: bytes,
        fileName: fileName,
      );

      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw Exception('Image upload failed. Please check internet connection.');
      }

      if (!mounted) return;

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final canvasProvider = Provider.of<CanvasProvider>(context, listen: false);

      final itemCount = canvasProvider.items.length;
      final newItem = CanvasItem(
        id: '',
        type: CanvasItemType.image,
        content: downloadUrl,
        x: 100.0 + (itemCount * 20 % 300),
        y: 100.0 + (itemCount * 20 % 300),
        width: 220.0,
        height: 180.0,
        color: '#FFFFFF',
        createdBy: userProvider.userId ?? 'anonymous',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await canvasProvider.addItem(
        roomCode: widget.room.roomCode,
        item: newItem,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  /// Displays item action menu on tap/long-press (Edit, Delete).
  void _showItemContextMenu(CanvasItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (item.type == CanvasItemType.note || item.type == CanvasItemType.text)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Colors.deepPurple),
                    title: const Text('Edit Item', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.of(bottomSheetContext).pop();
                      if (item.type == CanvasItemType.note) {
                        _showEditNoteDialog(item);
                      } else if (item.type == CanvasItemType.text) {
                        _showEditTextDialog(item);
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete Item', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _showDeleteConfirmDialog(item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Confirmation dialog before deleting an item.
  void _showDeleteConfirmDialog(CanvasItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Canvas Item'),
          content: const Text(
            'Are you sure you want to delete this item from the canvas? This will remove it for all users.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final canvasProvider =
                    Provider.of<CanvasProvider>(context, listen: false);
                await canvasProvider.deleteItem(
                  roomCode: widget.room.roomCode,
                  itemId: item.id,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Displays the option picker bottom sheet (Note, Text, Image, Link).
  void _showAddOptionsModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add to Canvas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.note_alt_outlined, color: Colors.amber),
                  ),
                  title: const Text('Note', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Add a colorful sticky note'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showAddNoteDialog();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.text_fields_rounded, color: Colors.deepPurple),
                  ),
                  title: const Text('Text', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Add a plain text block'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showAddTextDialog();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.image_outlined, color: Colors.teal),
                  ),
                  title: const Text('Image', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Upload an image from gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadImage();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.link_rounded, color: Colors.blue),
                  ),
                  title: const Text('Link', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Add a web link card'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showAddLinkDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Displays the Add Link dialog.
  void _showAddLinkDialog() {
    final urlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Paste URL'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: urlController,
              keyboardType: TextInputType.url,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
                prefixIcon: Icon(Icons.link_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final clean = value?.trim() ?? '';
                if (clean.isEmpty) {
                  return 'Please enter a URL.';
                }
                final formatted = clean.startsWith('http') ? clean : 'https://$clean';
                final uri = Uri.tryParse(formatted);
                if (uri == null || !uri.hasAuthority) {
                  return 'Please enter a valid URL.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final rawUrl = urlController.text.trim();
                final formattedUrl =
                    rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';

                final userProvider =
                    Provider.of<UserProvider>(context, listen: false);
                final canvasProvider =
                    Provider.of<CanvasProvider>(context, listen: false);

                final itemCount = canvasProvider.items.length;
                final newItem = CanvasItem(
                  id: '',
                  type: CanvasItemType.link,
                  content: formattedUrl,
                  x: 100.0 + (itemCount * 20 % 300),
                  y: 100.0 + (itemCount * 20 % 300),
                  width: 220.0,
                  height: 150.0,
                  color: '#E3F2FD',
                  createdBy: userProvider.userId ?? 'anonymous',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await canvasProvider.addItem(
                  roomCode: widget.room.roomCode,
                  item: newItem,
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  /// Displays the Add Note dialog.
  void _showAddNoteDialog() {
    final textController = TextEditingController();
    String selectedColor = '#FFEB3B';

    final colors = [
      {'name': 'yellow', 'hex': '#FFEB3B', 'displayColor': const Color(0xFFFFEB3B)},
      {'name': 'green', 'hex': '#B9F6CA', 'displayColor': const Color(0xFFB9F6CA)},
      {'name': 'blue', 'hex': '#80D8FF', 'displayColor': const Color(0xFF80D8FF)},
      {'name': 'pink', 'hex': '#FF80AB', 'displayColor': const Color(0xFFFF80AB)},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Note'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Type your note here...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Color:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: colors.map((c) {
                      final hex = c['hex'] as String;
                      final displayColor = c['displayColor'] as Color;
                      final isSelected = selectedColor == hex;

                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = hex;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: displayColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.deepPurple : Colors.black12,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 18, color: Colors.deepPurple)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final content = textController.text.trim();
                    if (content.isEmpty) return;

                    final userProvider =
                        Provider.of<UserProvider>(context, listen: false);
                    final canvasProvider =
                        Provider.of<CanvasProvider>(context, listen: false);

                    final itemCount = canvasProvider.items.length;
                    final newItem = CanvasItem(
                      id: '',
                      type: CanvasItemType.note,
                      content: content,
                      x: 100.0 + (itemCount * 20 % 300),
                      y: 100.0 + (itemCount * 20 % 300),
                      width: 200.0,
                      height: 180.0,
                      color: selectedColor,
                      createdBy: userProvider.userId ?? 'anonymous',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    await canvasProvider.addItem(
                      roomCode: widget.room.roomCode,
                      item: newItem,
                    );

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Displays the Edit Note dialog for existing notes.
  void _showEditNoteDialog(CanvasItem item) {
    final textController = TextEditingController(text: item.content);
    String selectedColor = item.color;

    final colors = [
      {'name': 'yellow', 'hex': '#FFEB3B', 'displayColor': const Color(0xFFFFEB3B)},
      {'name': 'green', 'hex': '#B9F6CA', 'displayColor': const Color(0xFFB9F6CA)},
      {'name': 'blue', 'hex': '#80D8FF', 'displayColor': const Color(0xFF80D8FF)},
      {'name': 'pink', 'hex': '#FF80AB', 'displayColor': const Color(0xFFFF80AB)},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Note'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Edit note content...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Color:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: colors.map((c) {
                      final hex = c['hex'] as String;
                      final displayColor = c['displayColor'] as Color;
                      final isSelected = selectedColor == hex;

                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = hex;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: displayColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.deepPurple : Colors.black12,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 18, color: Colors.deepPurple)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newContent = textController.text.trim();
                    if (newContent.isEmpty) return;

                    final canvasProvider =
                        Provider.of<CanvasProvider>(context, listen: false);

                    final updatedItem = item.copyWith(
                      content: newContent,
                      color: selectedColor,
                      updatedAt: DateTime.now(),
                    );

                    await canvasProvider.updateItem(
                      roomCode: widget.room.roomCode,
                      item: updatedItem,
                    );

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Displays the Add Text dialog.
  void _showAddTextDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Text Card'),
          content: TextField(
            controller: textController,
            maxLines: 2,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter text...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final content = textController.text.trim();
                if (content.isEmpty) return;

                final userProvider =
                    Provider.of<UserProvider>(context, listen: false);
                final canvasProvider =
                    Provider.of<CanvasProvider>(context, listen: false);

                final itemCount = canvasProvider.items.length;
                final newItem = CanvasItem(
                  id: '',
                  type: CanvasItemType.text,
                  content: content,
                  x: 120.0 + (itemCount * 20 % 300),
                  y: 120.0 + (itemCount * 20 % 300),
                  width: 220.0,
                  height: 110.0,
                  color: '#FFFFFF',
                  createdBy: userProvider.userId ?? 'anonymous',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await canvasProvider.addItem(
                  roomCode: widget.room.roomCode,
                  item: newItem,
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  /// Displays the Edit Text dialog.
  void _showEditTextDialog(CanvasItem item) {
    final textController = TextEditingController(text: item.content);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Text Card'),
          content: TextField(
            controller: textController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Edit text...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newContent = textController.text.trim();
                if (newContent.isEmpty) return;

                final canvasProvider =
                    Provider.of<CanvasProvider>(context, listen: false);

                final updatedItem = item.copyWith(
                  content: newContent,
                  updatedAt: DateTime.now(),
                );

                await canvasProvider.updateItem(
                  roomCode: widget.room.roomCode,
                  item: updatedItem,
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _formatRemainingTime(DateTime expireAt) {
    final now = DateTime.now();
    final difference = expireAt.difference(now);

    if (difference.isNegative || difference.inSeconds <= 0) {
      return 'Expired';
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);

    if (hours > 0) {
      return 'Expires in ${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return 'Expires in ${minutes}m';
    } else {
      final seconds = difference.inSeconds;
      return 'Expires in ${seconds}s';
    }
  }

  /// Displays confirmation dialog to delete the entire room.
  void _showDeleteRoomConfirmDialog(Room activeRoom) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Room'),
          content: Text(
            'Are you sure you want to delete "${activeRoom.roomName}" (${activeRoom.roomCode})? This action cannot be undone and will delete the room for all participants.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final roomProvider =
                    Provider.of<RoomProvider>(context, listen: false);
                final canvasProvider =
                    Provider.of<CanvasProvider>(context, listen: false);

                canvasProvider.stopListening();
                final success =
                    await roomProvider.deleteRoom(activeRoom.roomCode);

                if (mounted) {
                  if (success) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Room deleted successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to delete room. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    final canvasProvider = Provider.of<CanvasProvider>(context);
    final activeRoom = roomProvider.currentRoom ?? widget.room;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _leaveRoom,
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeRoom.roomName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Code: ${activeRoom.roomCode}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: activeRoom.isExpired
                        ? Colors.red.shade50
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: activeRoom.isExpired
                          ? Colors.red.shade200
                          : Colors.amber.shade300,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 11,
                        color: activeRoom.isExpired
                            ? Colors.red.shade700
                            : Colors.amber.shade900,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatRemainingTime(activeRoom.expireAt),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: activeRoom.isExpired
                              ? Colors.red.shade700
                              : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export Canvas PNG',
            onPressed: _isExporting ? null : _exportCanvas,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Room',
            onPressed: () => _showDeleteRoomConfirmDialog(activeRoom),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline, size: 15, color: Colors.deepPurple),
                const SizedBox(width: 3),
                Text(
                  '${activeRoom.participantCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background canvas grid container
          Positioned.fill(
            child: Container(
              color: const Color(0xFFF8F9FA),
            ),
          ),

          // Real-time Canvas Items Stack wrapped in RepaintBoundary for PNG export
          Positioned.fill(
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(1000),
              minScale: 0.5,
              maxScale: 2.5,
              child: RepaintBoundary(
                key: _canvasExportKey,
                child: Container(
                  width: 3000,
                  height: 3000,
                  color: const Color(0xFFF8F9FA),
                  child: Stack(
                    children: canvasProvider.items.map((item) {
                      return DraggableCanvasItemWidget(
                        key: ValueKey(item.id),
                        item: item,
                        roomCode: activeRoom.roomCode,
                        onEdit: () {
                          if (item.type == CanvasItemType.note) {
                            _showEditNoteDialog(item);
                          } else if (item.type == CanvasItemType.text) {
                            _showEditTextDialog(item);
                          }
                        },
                        onDelete: () => _showDeleteConfirmDialog(item),
                        onOptions: () => _showItemContextMenu(item),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          // Sync / Exporting / Image Uploading indicator overlay
          if (canvasProvider.isLoading || _isUploadingImage || _isExporting)
            Positioned(
              top: 16,
              right: 16,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isExporting
                            ? 'Exporting canvas PNG...'
                            : _isUploadingImage
                                ? 'Uploading image...'
                                : 'Syncing canvas...',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Floating "+" action button
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptionsModal,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        tooltip: 'Add item to canvas',
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

/// Draggable wrapper widget for individual canvas elements.
class DraggableCanvasItemWidget extends StatefulWidget {
  final CanvasItem item;
  final String roomCode;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onOptions;

  const DraggableCanvasItemWidget({
    super.key,
    required this.item,
    required this.roomCode,
    this.onEdit,
    this.onDelete,
    this.onOptions,
  });

  @override
  State<DraggableCanvasItemWidget> createState() =>
      _DraggableCanvasItemWidgetState();
}

class _DraggableCanvasItemWidgetState extends State<DraggableCanvasItemWidget> {
  late double _x;
  late double _y;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _x = widget.item.x;
    _y = widget.item.y;
  }

  @override
  void didUpdateWidget(covariant DraggableCanvasItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _x = widget.item.x;
      _y = widget.item.y;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onTap: widget.onOptions,
        onLongPress: widget.onOptions,
        onPanStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _x += details.delta.dx;
            _y += details.delta.dy;
          });
        },
        onPanEnd: (_) async {
          setState(() {
            _isDragging = false;
          });

          final canvasProvider =
              Provider.of<CanvasProvider>(context, listen: false);
          await canvasProvider.updateItemPosition(
            roomCode: widget.roomCode,
            itemId: widget.item.id,
            x: _x,
            y: _y,
          );
        },
        child: _buildItemContent(),
      ),
    );
  }

  Widget _buildItemContent() {
    switch (widget.item.type) {
      case CanvasItemType.note:
        return StickyNoteWidget(
          item: widget.item,
          onDelete: widget.onDelete,
          onEdit: widget.onEdit,
        );
      case CanvasItemType.text:
        return TextCardWidget(
          item: widget.item,
          onDelete: widget.onDelete,
          onEdit: widget.onEdit,
          onOptions: widget.onOptions,
        );
      case CanvasItemType.image:
        return ImageCardWidget(
          item: widget.item,
          onDelete: widget.onDelete,
        );
      case CanvasItemType.link:
        return LinkCardWidget(
          item: widget.item,
          onDelete: widget.onDelete,
        );
    }
  }
}
