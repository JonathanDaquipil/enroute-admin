import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String searchText = '';
  String selectedFilter = 'all';

  final Map<String, String> officeNames = const {
    "ocm": "Office of the City Mayor (OCM)",
    "misd": "OCM - Management Information System Division (MISD)",
    "socd": "OCM - Special Operations and Concerns Division (SOCD)",
    "cad": "OCM - Community Affairs Division (CAD)",
    "bh": "OCM - Bahay Silangan (BH)",
    "cesd":
        "OCM - Cooperative, Employment Services Division / Public Employment Service Office (CESD)",
    "ad": "OCM - Administrative Division (AD)",
    "sp": "Sangguniang Panlungsod (SP)",
    "cbo": "City Budget Office (CBO)",
    "cpdo": "City Planning and Development Office (CPDO)",
    "hrmo": "Human Resource Management Office (HRMO)",
    "oca": "Office of the City Administrator (OCA)",
    "lcr": "Local Civil Registrar's Office (LCR)",
    "cao": "City Accounting Office (CAO)",
    "cto": "City Treasurer's Office (CTO)",
    "cgso": "City General Services Office (CGSO)",
    "cho": "City Health Office (CHO)",
    "cswd": "City Social Welfare & Development Office (CSWD)",
    "cdrrmo": "City Disaster Risk Reduction Management Office (CDRRMO)",
    "ceedo": "City Economic Enterprise & Development Office (CEEDO)",
    "ceo": "City Engineer's Office (CEO)",
    "ocps": "Office of the City Public Service (OCPS)",
    "cafo": "City Agriculture & Fisheries Office (CAFO)",
    "cenro": "City Environment & Natural Resources Office (CENRO)",
    "cvo": "City Veterinary Office (CVO)",
    "clo": "City Legal Office (CLO)",
    "cboo": "City Building Official Office (CBOO)",
    "dilg": "Department of Labor and Employment - Oroquieta (DILG)",
    "pnp": "Philippine National Police - Oroquieta (PNP)",
    "bfp": "Bureau of Fire Protection - Oroquieta (BFP)",
    "pcg": "Philippine Coast Guard - Oroquieta (PCG)",
    "10th ib": "10th Infantry Battalion - Oroquieta (10th IB)",
    "citizen": "Citizen",
    "cso": "Civil Society Organizations",
    "ngo": "Non-Governmental Organization",
    "citizen_cso_ngo": "Citizen / CSO / NGO",
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String officeLabel(String officeId) {
    return officeNames[officeId.toLowerCase()] ?? officeId.toUpperCase();
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'No date available';

    DateTime? dt;

    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is DateTime) {
      dt = value;
    }

    if (dt == null) return value.toString();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = months[dt.month - 1];
    final day = dt.day;
    final year = dt.year;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year • $hour:$minute $period';
  }

  Set<String> _extractStringSet(dynamic value) {
    if (value == null) return <String>{};

    if (value is List) {
      return value.map((e) => e.toString().trim().toLowerCase()).toSet();
    }

    if (value is Map) {
      return value.values.map((e) => e.toString().trim().toLowerCase()).toSet();
    }

    return {value.toString().trim().toLowerCase()};
  }

  DateTime _extractSortDate(DocumentRecord item) {
    final values = [
      item.completedAt,
      item.timeAndDateSent,
      item.receivedDate,
      item.dueAt,
    ];

    for (final v in values) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<DocumentsDashboardData> _loadDashboardData() async {
    final sentSnapshot = await _firestore
        .collectionGroup('sentdocuments')
        .get();
    final receivedSnapshot = await _firestore
        .collectionGroup('receiveddocuments')
        .get();

    final Map<String, DocumentRecord> merged = {};

    for (final doc in sentSnapshot.docs) {
      final data = doc.data();
      final officeId = doc.reference.parent.parent?.id ?? 'unknown';
      final docId = (data['docid'] ?? doc.id).toString().trim();

      if (docId.isEmpty) continue;

      final existing = merged[docId];

      if (existing == null) {
        merged[docId] = DocumentRecord(
          docId: docId,
          title: (data['doctitle'] ?? '').toString(),
          docType: (data['doctype'] ?? '').toString(),
          purpose: (data['purpose'] ?? '').toString(),
          qrCodeLink: (data['qrcodelink'] ?? '').toString(),
          status: (data['status'] ?? '').toString(),
          category: (data['category'] ?? '').toString(),
          transactionType: (data['transactiontype'] ?? '').toString(),
          dueAt: data['dueat'],
          timeAndDateSent: data['timeanddatesent'],
          remainingTime: (data['remainingtime'] ?? '').toString(),
          isOverdue: data['isoverdue'] == true,
          senderOffice: officeId,
          receivedOffices: <String>{},
          notifyOffices: _extractStringSet(data['notifyoffices']),
          sentRecordCount: 1,
          receivedRecordCount: 0,
          senderName: (data['sendername'] ?? '').toString(),
          senderContactNum: (data['sendercontactnum'] ?? '').toString(),
          actionTaken: (data['actiontaken'] ?? '').toString(),
          unreadOverdue: data['unread_overdue'] == true,
          isCompleted: false,
          completedAt: null,
          lastTrackingStatus: '',
        );
      } else {
        existing.sentRecordCount += 1;
        existing.senderOffice ??= officeId;
        existing.title = existing.title.isEmpty
            ? (data['doctitle'] ?? '').toString()
            : existing.title;
        existing.docType = existing.docType.isEmpty
            ? (data['doctype'] ?? '').toString()
            : existing.docType;
        existing.purpose = existing.purpose.isEmpty
            ? (data['purpose'] ?? '').toString()
            : existing.purpose;
        existing.qrCodeLink = existing.qrCodeLink.isEmpty
            ? (data['qrcodelink'] ?? '').toString()
            : existing.qrCodeLink;
        existing.status = existing.status.isEmpty
            ? (data['status'] ?? '').toString()
            : existing.status;
        existing.category = existing.category.isEmpty
            ? (data['category'] ?? '').toString()
            : existing.category;
        existing.transactionType = existing.transactionType.isEmpty
            ? (data['transactiontype'] ?? '').toString()
            : existing.transactionType;
        existing.remainingTime = existing.remainingTime.isEmpty
            ? (data['remainingtime'] ?? '').toString()
            : existing.remainingTime;
        existing.senderName = existing.senderName.isEmpty
            ? (data['sendername'] ?? '').toString()
            : existing.senderName;
        existing.senderContactNum = existing.senderContactNum.isEmpty
            ? (data['sendercontactnum'] ?? '').toString()
            : existing.senderContactNum;
        existing.actionTaken = existing.actionTaken.isEmpty
            ? (data['actiontaken'] ?? '').toString()
            : existing.actionTaken;
        existing.notifyOffices.addAll(_extractStringSet(data['notifyoffices']));
        existing.isOverdue = existing.isOverdue || data['isoverdue'] == true;
        existing.unreadOverdue =
            existing.unreadOverdue || data['unread_overdue'] == true;
        existing.dueAt ??= data['dueat'];
        existing.timeAndDateSent ??= data['timeanddatesent'];
      }
    }

    for (final doc in receivedSnapshot.docs) {
      final data = doc.data();
      final officeId = doc.reference.parent.parent?.id ?? 'unknown';
      final docId = (data['docid'] ?? doc.id).toString().trim();

      if (docId.isEmpty) continue;

      final existing = merged[docId];

      if (existing == null) {
        merged[docId] = DocumentRecord(
          docId: docId,
          title: (data['doctitle'] ?? '').toString(),
          docType: (data['doctype'] ?? '').toString(),
          purpose: (data['purpose'] ?? '').toString(),
          qrCodeLink: (data['qrcodelink'] ?? '').toString(),
          status: '',
          category: '',
          transactionType: '',
          dueAt: null,
          timeAndDateSent: null,
          remainingTime: '',
          isOverdue: false,
          senderOffice: null,
          receivedOffices: {officeId},
          notifyOffices: <String>{},
          sentRecordCount: 0,
          receivedRecordCount: 1,
          senderName: '',
          senderContactNum: '',
          actionTaken: '',
          unreadOverdue: false,
          receivedDate: data['receiveddat'],
          isCompleted: false,
          completedAt: null,
          lastTrackingStatus: '',
        );
      } else {
        existing.receivedRecordCount += 1;
        existing.receivedOffices.add(officeId);
        existing.receivedDate ??= data['receiveddat'];
        existing.title = existing.title.isEmpty
            ? (data['doctitle'] ?? '').toString()
            : existing.title;
        existing.docType = existing.docType.isEmpty
            ? (data['doctype'] ?? '').toString()
            : existing.docType;
        existing.purpose = existing.purpose.isEmpty
            ? (data['purpose'] ?? '').toString()
            : existing.purpose;
        existing.qrCodeLink = existing.qrCodeLink.isEmpty
            ? (data['qrcodelink'] ?? '').toString()
            : existing.qrCodeLink;
      }
    }

    for (final item in merged.values) {
      if (item.senderOffice == null || item.senderOffice!.trim().isEmpty) {
        continue;
      }

      try {
        final trackingSnapshot = await _firestore
            .collection('trackingstatus')
            .doc(item.senderOffice!)
            .collection(item.docId)
            .orderBy('sequence', descending: true)
            .limit(1)
            .get();

        if (trackingSnapshot.docs.isNotEmpty) {
          final latest = trackingSnapshot.docs.first.data();
          final latestStatus = (latest['status'] ?? '').toString().trim();

          item.lastTrackingStatus = latestStatus;

          if (latestStatus.toLowerCase() == 'completed' ||
              latestStatus.toLowerCase().contains('completed')) {
            item.isCompleted = true;
            item.completedAt = latest['time'];
          }

          if (item.status.isEmpty) {
            item.status = latestStatus;
          }
        }
      } catch (_) {}
    }

    final items = merged.values.toList()
      ..sort((a, b) => _extractSortDate(b).compareTo(_extractSortDate(a)));

    final overdueCount = items.where((e) => e.isOverdue).length;
    final officesInvolved = <String>{};

    for (final item in items) {
      if (item.senderOffice != null && item.senderOffice!.isNotEmpty) {
        officesInvolved.add(item.senderOffice!);
      }
      officesInvolved.addAll(item.receivedOffices);
    }

    return DocumentsDashboardData(
      totalSentRecords: sentSnapshot.docs.length,
      totalReceivedRecords: receivedSnapshot.docs.length,
      uniqueDocuments: items.length,
      overdueDocuments: overdueCount,
      officesInvolved: officesInvolved.length,
      completedDocuments: items.where((e) => e.isCompleted).length,
      items: items,
    );
  }

  bool _matchesSearch(DocumentRecord item) {
    if (searchText.trim().isEmpty) return true;

    final q = searchText.trim().toLowerCase();

    final values = [
      item.docId,
      item.title,
      item.docType,
      item.purpose,
      item.status,
      item.category,
      item.transactionType,
      item.senderOffice ?? '',
      item.senderName,
      item.senderContactNum,
      item.receivedOffices.join(' '),
      item.notifyOffices.join(' '),
      item.lastTrackingStatus,
    ].join(' ').toLowerCase();

    return values.contains(q);
  }

  bool _matchesFilter(DocumentRecord item) {
    if (selectedFilter == 'all') return true;
    if (selectedFilter == 'overdue') return item.isOverdue;
    if (selectedFilter == 'completed') return item.isCompleted;
    if (selectedFilter == 'with_qr') {
      return item.qrCodeLink.trim().isNotEmpty;
    }
    return true;
  }

  Future<List<TrackingStep>> _loadTrackingSteps(DocumentRecord item) async {
    if (item.senderOffice == null || item.senderOffice!.trim().isEmpty) {
      return [];
    }

    final snapshot = await _firestore
        .collection('trackingstatus')
        .doc(item.senderOffice!)
        .collection(item.docId)
        .orderBy('sequence')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return TrackingStep(
        sequence: int.tryParse((data['sequence'] ?? 0).toString()) ?? 0,
        senderOffice: (data['senderoffice'] ?? '').toString(),
        receiverOffices: _receiverOfficesFromValue(data['receiveroffice']),
        status: (data['status'] ?? '').toString(),
        time: data['time'],
        name: (data['name'] ?? '').toString(),
        contactNumber: (data['contactnumber'] ?? '').toString(),
        note: (data['note'] ?? '').toString(),
      );
    }).toList();
  }

  List<String> _receiverOfficesFromValue(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }

    if (value is Map) {
      return value.values.map((e) => e.toString()).toList();
    }

    return [value.toString()];
  }

  Uint8List? _tryDecodeBase64Image(String value) {
    try {
      String cleaned = value.trim();

      if (cleaned.contains(',')) {
        cleaned = cleaned.split(',').last;
      }

      final bytes = base64Decode(cleaned);
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Widget _buildQrPreview(String qrValue) {
    final value = qrValue.trim();

    if (value.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text('No QR code link available'),
        ),
      );
    }

    final imageBytes = _tryDecodeBase64Image(value);
    if (imageBytes != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              imageBytes,
              height: 220,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Failed to display QR image'),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Stored QR image',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      );
    }

    if (value.length > 23000) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withOpacity(0.20)),
            ),
            child: const Text(
              'QR data is too long to generate as a QR image. Showing stored content instead.',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        QrImageView(
          data: value,
          version: QrVersions.auto,
          size: 180,
          backgroundColor: Colors.white,
        ),
        const SizedBox(height: 12),
        SelectableText(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  void _showDetails(DocumentRecord item) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            width: 920,
            constraints: const BoxConstraints(maxHeight: 860),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF001F54), Color(0xFF0A3D91)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.description_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.docId,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.title.isEmpty ? 'No title' : item.title,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.88),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'COMPLETED',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _buildInfoBox(
                        label: 'Sender Office',
                        value:
                            item.senderOffice == null ||
                                item.senderOffice!.isEmpty
                            ? 'No sender office'
                            : '${item.senderOffice!.toUpperCase()} — ${officeLabel(item.senderOffice!)}',
                      ),
                      _buildInfoBox(
                        label: 'Receiver Office(s)',
                        value: item.receivedOffices.isEmpty
                            ? (item.notifyOffices.isEmpty
                                  ? 'No receiver office'
                                  : item.notifyOffices
                                        .map(
                                          (e) =>
                                              '${e.toUpperCase()} — ${officeLabel(e)}',
                                        )
                                        .join(', '))
                            : item.receivedOffices
                                  .map(
                                    (e) =>
                                        '${e.toUpperCase()} — ${officeLabel(e)}',
                                  )
                                  .join(', '),
                      ),
                      _buildInfoBox(
                        label: 'Document Type',
                        value: item.docType.isEmpty ? 'No type' : item.docType,
                      ),
                      _buildInfoBox(
                        label: 'Purpose',
                        value: item.purpose.isEmpty
                            ? 'No purpose'
                            : item.purpose,
                      ),
                      _buildInfoBox(
                        label: 'Status',
                        value: item.status.isEmpty ? 'No status' : item.status,
                      ),
                      _buildInfoBox(
                        label: 'Latest Tracking Status',
                        value: item.lastTrackingStatus.isEmpty
                            ? 'No tracking status'
                            : item.lastTrackingStatus,
                      ),
                      _buildInfoBox(
                        label: 'Completed',
                        value: item.isCompleted ? 'Yes' : 'No',
                      ),
                      _buildInfoBox(
                        label: 'Completed At',
                        value: _formatDate(item.completedAt),
                      ),
                      _buildInfoBox(
                        label: 'Category',
                        value: item.category.isEmpty
                            ? 'No category'
                            : item.category,
                      ),
                      _buildInfoBox(
                        label: 'Transaction Type',
                        value: item.transactionType.isEmpty
                            ? 'No transaction type'
                            : item.transactionType,
                      ),
                      _buildInfoBox(
                        label: 'Sender Name',
                        value: item.senderName.isEmpty
                            ? 'No sender name'
                            : item.senderName,
                      ),
                      _buildInfoBox(
                        label: 'Sender Contact',
                        value: item.senderContactNum.isEmpty
                            ? 'No contact number'
                            : item.senderContactNum,
                      ),
                      _buildInfoBox(
                        label: 'Sent Date',
                        value: _formatDate(item.timeAndDateSent),
                      ),
                      _buildInfoBox(
                        label: 'Received Date',
                        value: _formatDate(item.receivedDate),
                      ),
                      _buildInfoBox(
                        label: 'Due At',
                        value: _formatDate(item.dueAt),
                      ),
                      _buildInfoBox(
                        label: 'Remaining Time',
                        value: item.remainingTime.isEmpty
                            ? 'No remaining time'
                            : item.remainingTime,
                      ),
                      _buildInfoBox(
                        label: 'Action Taken',
                        value: item.actionTaken.isEmpty
                            ? 'No action taken'
                            : item.actionTaken,
                      ),
                      _buildInfoBox(
                        label: 'Overdue',
                        value: item.isOverdue ? 'Yes' : 'No',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'QR Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF001F54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _buildQrPreview(item.qrCodeLink),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Tracking Route Timeline',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF001F54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<TrackingStep>>(
                    future: _loadTrackingSteps(item),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.18),
                            ),
                          ),
                          child: Text(
                            'Failed to load tracking route: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final steps = snapshot.data ?? [];

                      if (steps.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'No tracking route found for this document.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        );
                      }

                      return Column(
                        children: steps.map((step) {
                          final stepCompleted =
                              step.status.toLowerCase() == 'completed' ||
                              step.status.toLowerCase().contains('completed');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: stepCompleted
                                        ? Colors.green.withOpacity(0.14)
                                        : const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      step.sequence.toString(),
                                      style: TextStyle(
                                        color: stepCompleted
                                            ? Colors.green
                                            : const Color(0xFF1D4ED8),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        step.status.isEmpty
                                            ? 'No status'
                                            : step.status,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Sender: ${step.senderOffice.isEmpty ? 'No sender' : '${step.senderOffice.toUpperCase()} — ${officeLabel(step.senderOffice)}'}',
                                        style: const TextStyle(
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Receiver: ${step.receiverOffices.isEmpty ? 'No receiver' : step.receiverOffices.map((e) => '${e.toUpperCase()} — ${officeLabel(e)}').join(', ')}',
                                        style: const TextStyle(
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                      if (step.name.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Processed by: ${step.name}',
                                          style: const TextStyle(
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                      if (step.contactNumber.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Contact: ${step.contactNumber}',
                                          style: const TextStyle(
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                      if (step.note.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Note: ${step.note}',
                                          style: const TextStyle(
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatDate(step.time),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoBox({required String label, required String value}) {
    return Container(
      width: 410,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            searchText = value;
          });
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: const Icon(Icons.search_rounded),
          hintText: 'Search doc ID, title, purpose, sender, receiver...',
          suffixIcon: searchText.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      searchText = '';
                    });
                  },
                  icon: const Icon(Icons.close),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String keyValue,
    required String label,
    required IconData icon,
  }) {
    final isSelected = selectedFilter == keyValue;

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () {
        setState(() {
          selectedFilter = keyValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF001F54) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF001F54)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(DocumentRecord item) {
    final docId = item.docId;
    final title = item.title.isEmpty ? 'No title' : item.title;
    final type = item.docType.isEmpty ? 'No type' : item.docType;
    final purpose = item.purpose.isEmpty ? 'No purpose' : item.purpose;

    final senderOfficeText =
        item.senderOffice == null || item.senderOffice!.isEmpty
        ? 'No sender office'
        : item.senderOffice!.toUpperCase();

    final receiverOfficeText = item.receivedOffices.isNotEmpty
        ? item.receivedOffices.map((e) => e.toUpperCase()).join(', ')
        : (item.notifyOffices.isNotEmpty
              ? item.notifyOffices.map((e) => e.toUpperCase()).join(', ')
              : 'No receiver office');

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _showDetails(item),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(18, 0, 0, 0),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: item.isCompleted
                    ? Colors.green.withOpacity(0.10)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                item.isCompleted
                    ? Icons.task_alt_rounded
                    : Icons.description_rounded,
                color: item.isCompleted
                    ? Colors.green
                    : const Color(0xFF1D4ED8),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          docId,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF001F54),
                          ),
                        ),
                      ),
                      if (item.isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'COMPLETED',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        )
                      else if (item.isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'OVERDUE',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _miniChip(Icons.category_outlined, type),
                      _miniChip(Icons.source_outlined, senderOfficeText),
                      _miniChip(
                        Icons.call_received_rounded,
                        receiverOfficeText,
                      ),
                      _miniChip(Icons.notes_rounded, purpose),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.isCompleted
                        ? 'Completed: ${_formatDate(item.completedAt)}'
                        : 'Sent: ${_formatDate(item.timeAndDateSent)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _showDetails(item),
              icon: const Icon(
                Icons.visibility_outlined,
                color: Color(0xFF001F54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FD),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE4EBF5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF001F54)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return FutureBuilder<DocumentsDashboardData>(
      future: _loadDashboardData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Text(
                'Failed to load documents: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final dashboard = snapshot.data!;
        final filteredItems = dashboard.items
            .where((item) => _matchesSearch(item) && _matchesFilter(item))
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Documents Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF001F54),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Track sender and receiver offices, completion status, route history, and QR data for documents across offices.',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: width < 900 ? 2 : 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: width < 900 ? 2.0 : 2.35,
                children: [
                  _buildTopCard(
                    title: 'Unique Documents',
                    value: dashboard.uniqueDocuments.toString(),
                    icon: Icons.description_rounded,
                    color: Colors.blue,
                  ),
                  _buildTopCard(
                    title: 'Sent Records',
                    value: dashboard.totalSentRecords.toString(),
                    icon: Icons.send_rounded,
                    color: Colors.green,
                  ),
                  _buildTopCard(
                    title: 'Received Records',
                    value: dashboard.totalReceivedRecords.toString(),
                    icon: Icons.inbox_rounded,
                    color: Colors.orange,
                  ),
                  _buildTopCard(
                    title: 'Completed',
                    value: dashboard.completedDocuments.toString(),
                    icon: Icons.task_alt_rounded,
                    color: Colors.teal,
                  ),
                  _buildTopCard(
                    title: 'Overdue Documents',
                    value: dashboard.overdueDocuments.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red,
                  ),
                  _buildTopCard(
                    title: 'Offices Involved',
                    value: dashboard.officesInvolved.toString(),
                    icon: Icons.apartment_rounded,
                    color: Colors.deepPurple,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSearchBar(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildFilterChip(
                    keyValue: 'all',
                    label: 'All',
                    icon: Icons.grid_view_rounded,
                  ),
                  _buildFilterChip(
                    keyValue: 'overdue',
                    label: 'Overdue',
                    icon: Icons.warning_amber_rounded,
                  ),
                  _buildFilterChip(
                    keyValue: 'completed',
                    label: 'Completed',
                    icon: Icons.task_alt_rounded,
                  ),
                  _buildFilterChip(
                    keyValue: 'with_qr',
                    label: 'With QR',
                    icon: Icons.qr_code_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (filteredItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 60,
                        color: Color(0xFF001F54),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No documents found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF001F54),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return _buildDocumentCard(filteredItems[index]);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class DocumentRecord {
  final String docId;

  String title;
  String docType;
  String purpose;
  String qrCodeLink;
  String status;
  String category;
  String transactionType;
  dynamic dueAt;
  dynamic timeAndDateSent;
  dynamic receivedDate;
  String remainingTime;
  bool isOverdue;
  String? senderOffice;
  Set<String> receivedOffices;
  Set<String> notifyOffices;
  int sentRecordCount;
  int receivedRecordCount;
  String senderName;
  String senderContactNum;
  String actionTaken;
  bool unreadOverdue;
  bool isCompleted;
  dynamic completedAt;
  String lastTrackingStatus;

  DocumentRecord({
    required this.docId,
    required this.title,
    required this.docType,
    required this.purpose,
    required this.qrCodeLink,
    required this.status,
    required this.category,
    required this.transactionType,
    required this.dueAt,
    required this.timeAndDateSent,
    this.receivedDate,
    required this.remainingTime,
    required this.isOverdue,
    required this.senderOffice,
    required this.receivedOffices,
    required this.notifyOffices,
    required this.sentRecordCount,
    required this.receivedRecordCount,
    required this.senderName,
    required this.senderContactNum,
    required this.actionTaken,
    required this.unreadOverdue,
    required this.isCompleted,
    required this.completedAt,
    required this.lastTrackingStatus,
  });
}

class DocumentsDashboardData {
  final int totalSentRecords;
  final int totalReceivedRecords;
  final int uniqueDocuments;
  final int overdueDocuments;
  final int officesInvolved;
  final int completedDocuments;
  final List<DocumentRecord> items;

  DocumentsDashboardData({
    required this.totalSentRecords,
    required this.totalReceivedRecords,
    required this.uniqueDocuments,
    required this.overdueDocuments,
    required this.officesInvolved,
    required this.completedDocuments,
    required this.items,
  });
}

class TrackingStep {
  final int sequence;
  final String senderOffice;
  final List<String> receiverOffices;
  final String status;
  final dynamic time;
  final String name;
  final String contactNumber;
  final String note;

  TrackingStep({
    required this.sequence,
    required this.senderOffice,
    required this.receiverOffices,
    required this.status,
    required this.time,
    required this.name,
    required this.contactNumber,
    required this.note,
  });
}
