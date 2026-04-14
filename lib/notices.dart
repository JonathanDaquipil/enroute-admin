import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://enroute-29399-default-rtdb.firebaseio.com',
  );

  final ImagePicker _picker = ImagePicker();

  Uint8List? selectedFileBytes;
  String? selectedFileName;

  final Map<String, String> officeMap = const {
    "ocm": "Office of the City Mayor (OCM)",
    "misd": "MISD",
    "hrmo": "HRMO",
    "socd": "SOCD",
  };

  /// =========================
  /// PICK IMAGE
  /// =========================
  Future pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final bytes = await picked.readAsBytes();

      if (bytes.length > 700 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image too large (max 700KB)')),
        );
        return;
      }

      setState(() {
        selectedFileBytes = bytes;
        selectedFileName = picked.name;
      });
    }
  }

  /// =========================
  /// SAVE ATTACHMENT
  /// =========================
  Future<List<Map<String, dynamic>>> saveAttachment(String noticeId) async {
    List<Map<String, dynamic>> metadata = [];

    if (selectedFileBytes == null || selectedFileName == null) {
      return metadata;
    }

    final id = 'att_${DateTime.now().millisecondsSinceEpoch}';
    final base64Data = base64Encode(selectedFileBytes!);

    await _database.ref('notice_files/$noticeId/$id').set({
      'name': selectedFileName,
      'base64Data': base64Data,
      'size': selectedFileBytes!.length,
      'type': 'image', // you can change to dynamic later
      'uploadedAt': ServerValue.timestamp,
    });

    metadata.add({
      'id': id,
      'name': selectedFileName,
      'type': 'image',
      'size': selectedFileBytes!.length,
    });

    return metadata;
  }

  /// =========================
  /// CREATE NOTICE
  /// =========================
  void showCreateNoticeDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    String? selectedSender;
    List<String> selectedRecipients = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Create Notice"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Title"),
                    ),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: "Message"),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      hint: const Text("Select Sender"),
                      items: officeMap.entries.map((e) {
                        return DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setStateDialog(() => selectedSender = val);
                      },
                    ),

                    const SizedBox(height: 10),

                    Column(
                      children: officeMap.entries.map((e) {
                        final selected = selectedRecipients.contains(e.key);

                        return CheckboxListTile(
                          value: selected,
                          title: Text(e.value),
                          onChanged: (val) {
                            setStateDialog(() {
                              if (val == true) {
                                selectedRecipients.add(e.key);
                              } else {
                                selectedRecipients.remove(e.key);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    ElevatedButton(
                      onPressed: pickImage,
                      child: const Text("Upload Image"),
                    ),

                    if (selectedFileBytes != null)
                      Image.memory(selectedFileBytes!, height: 100),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty ||
                        messageController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Fill all fields")),
                      );
                      return;
                    }

                    final noticeRef = _firestore.collection('notices').doc();

                    final attachments = await saveAttachment(noticeRef.id);

                    await noticeRef.set({
                      "title": titleController.text,
                      "message": messageController.text,
                      "senderOfficeId": selectedSender,
                      "senderOfficeName": officeMap[selectedSender],
                      "recipientOfficeIds": selectedRecipients,
                      "attachments": attachments,
                      "createdAt": FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(context);
                  },
                  child: const Text("Send"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// =========================
  /// NOTICE CARD (FIXED)
  /// =========================
  Widget buildNoticeCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final attachments = data['attachments'] ?? [];

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['title'] ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              "From: ${data['senderOfficeName'] ?? ''}",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(data['message'] ?? ''),

            /// 🔥 FIXED ATTACHMENT DISPLAY
            if (attachments is List && attachments.isNotEmpty)
              FutureBuilder(
                future: _database
                    .ref('notice_files/${doc.id}/${attachments[0]['id']}')
                    .get(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox();

                  final val = snap.data!.value as Map?;
                  if (val == null) return const SizedBox();

                  try {
                    final bytes = base64Decode(val['base64Data']);
                    final type = val['type'] ?? 'image';

                    if (type == 'image') {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Image.memory(bytes, height: 120),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file),
                            const SizedBox(width: 8),
                            Expanded(child: Text(val['name'] ?? 'File')),
                          ],
                        ),
                      );
                    }
                  } catch (_) {
                    return const SizedBox();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  /// =========================
  /// STREAM
  /// =========================
  Stream<QuerySnapshot> getNotices() {
    return _firestore.collection('notices').snapshots();
  }

  /// =========================
  /// UI
  /// =========================
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Notices",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: showCreateNoticeDialog,
              icon: const Icon(Icons.add),
              label: const Text("Create Notice"),
            ),
          ],
        ),
        const SizedBox(height: 20),

        StreamBuilder<QuerySnapshot>(
          stream: getNotices(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(child: Text("No notices found"));
            }

            return ListView.builder(
              itemCount: docs.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                return buildNoticeCard(docs[index]);
              },
            );
          },
        ),
      ],
    );
  }
}
