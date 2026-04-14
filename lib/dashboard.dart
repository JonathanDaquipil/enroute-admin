import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DashboardCounts {
  final int totalUsers;
  final int totalOffices;
  final int totalDocuments;
  final int totalNotifications;
  final int totalSentEntries;
  final int totalReceivedEntries;

  const DashboardCounts({
    required this.totalUsers,
    required this.totalOffices,
    required this.totalDocuments,
    required this.totalNotifications,
    required this.totalSentEntries,
    required this.totalReceivedEntries,
  });
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<Map<String, String>> offices = const [
    {"id": "ocm", "name": "Office of the City Mayor (OCM)"},
    {
      "id": "misd",
      "name": "OCM - Management Information System Division (MISD)",
    },
    {
      "id": "socd",
      "name": "OCM - Special Operations and Concerns Division (SOCD)",
    },
    {"id": "cad", "name": "OCM - Community Affairs division (CAD)"},
    {
      "id": "cesd",
      "name":
          "OCM - Cooperative, Employment Services Division / Public Employment Service Office (CESD)",
    },
    {"id": "bh", "name": "OCM - Bahay Silangan (BH)"},
    {"id": "ad", "name": "OCM  - Administrative Division (AD)"},
    {"id": "sp", "name": "Sangguniang Panlungsod (SP)"},
    {"id": "cbo", "name": "City Budget Office (CBO)"},
    {"id": "cpdo", "name": "City Planning and Development Office (CPDO)"},
    {"id": "hrmo", "name": "Human Resource Management Office (HRMO)"},
    {"id": "oca", "name": "Office of the City Administrator (OCA)"},
    {"id": "lcr", "name": "Local Civil Registrar’s Office (LCR)"},
    {"id": "cao", "name": "City Accounting Office (CAO)"},
    {"id": "cto", "name": "City Treasurer’s Office (CTO)"},
    {"id": "caao", "name": "City Assessor’s Office (CAO)"},
    {"id": "cgso", "name": "City General Services Office (CGSO)"},
    {"id": "cho", "name": "City Health Office (CHO)"},
    {"id": "cswd", "name": "City Social Welfare & Development Office (CSWD)"},
    {
      "id": "cdrrmo",
      "name": "City Disaster Risk Reduction Management Office (CDRRMO)",
    },
    {
      "id": "ceedo",
      "name": "City Economic Enterprise & Development Office (CEEDO)",
    },
    {"id": "ceo", "name": "City Engineer’s Office (CEO)"},
    {"id": "ocps", "name": "Office of the City Public Service (OCPS)"},
    {"id": "cafo", "name": "City Agriculture & Fisheries Office (CAFO)"},
    {
      "id": "cenro",
      "name": "City Environment & Natural Resources Office (CENRO)",
    },
    {"id": "cvo", "name": "City Veterinary Office (CVO)"},
    {"id": "clo", "name": "City Legal Office (CLO)"},
    {"id": "cboo", "name": "City Building Official Office (CBOO)"},
    {
      "id": "dilg",
      "name":
          "Department of the Interior and Local Government - Oroquieta (DILG)",
    },
    {"id": "pnp", "name": "Philippine National Police - Oroquieta (PNP)"},
    {"id": "bfp", "name": "Bureau of Fire Protection - Oroquieta (BFP)"},
    {"id": "pcg", "name": "Philippine Coast Guard - Oroquieta (PCG)"},
    {"id": "10th ib", "name": "10th Infantry Battalion - Oroquieta (10th IB)"},
  ];

  Future<DashboardCounts> fetchDashboardCounts() async {
    final usersSnapshot = await _firestore.collection('users').get();
    final totalUsers = usersSnapshot.docs
        .where((doc) => doc.id.toLowerCase() != 'admin')
        .length;

    final totalOffices = offices.length;

    final sentSnapshot = await _firestore
        .collectionGroup('sentdocuments')
        .get();

    final receivedSnapshot = await _firestore
        .collectionGroup('receiveddocuments')
        .get();

    final Set<String> uniqueDocumentIds = {};

    for (final doc in sentSnapshot.docs) {
      final data = doc.data();
      final docId = (data['docid'] ?? doc.id).toString().trim();
      if (docId.isNotEmpty) {
        uniqueDocumentIds.add(docId);
      }
    }

    for (final doc in receivedSnapshot.docs) {
      final data = doc.data();
      final docId = (data['docid'] ?? doc.id).toString().trim();
      if (docId.isNotEmpty) {
        uniqueDocumentIds.add(docId);
      }
    }

    final totalDocuments = uniqueDocumentIds.length;

    final notificationsSnapshot = await _firestore
        .collectionGroup('notifications')
        .get();
    final totalNotifications = notificationsSnapshot.docs.length;

    return DashboardCounts(
      totalUsers: totalUsers,
      totalOffices: totalOffices,
      totalDocuments: totalDocuments,
      totalNotifications: totalNotifications,
      totalSentEntries: sentSnapshot.docs.length,
      totalReceivedEntries: receivedSnapshot.docs.length,
    );
  }

  Widget buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(20, 0, 0, 0),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF001F54),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    int cardColumns() {
      if (width < 700) return 1;
      if (width < 1100) return 2;
      return 4;
    }

    return FutureBuilder<DashboardCounts>(
      future: fetchDashboardCounts(),
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
                'Failed to load dashboard data:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          );
        }

        final data = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.count(
              crossAxisCount: cardColumns(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: width < 1100 ? 2.5 : 2.2,
              children: [
                buildStatCard(
                  title: 'Total Users',
                  value: data.totalUsers.toString(),
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                buildStatCard(
                  title: 'Total Offices',
                  value: data.totalOffices.toString(),
                  icon: Icons.apartment,
                  color: Colors.green,
                ),
                buildStatCard(
                  title: 'Total Documents',
                  value: data.totalDocuments.toString(),
                  icon: Icons.description,
                  color: Colors.deepPurple,
                ),
                buildStatCard(
                  title: 'Total Notifications',
                  value: data.totalNotifications.toString(),
                  icon: Icons.notifications_active,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 20),
            buildSectionCard(
              title: 'System Overview',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This dashboard shows the real-time admin summary of users, offices, unique documents, and notifications.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildMiniInfoCard(
                        label: 'Sent Entries',
                        value: data.totalSentEntries.toString(),
                        color: Colors.indigo,
                      ),
                      _buildMiniInfoCard(
                        label: 'Received Entries',
                        value: data.totalReceivedEntries.toString(),
                        color: Colors.teal,
                      ),
                      _buildMiniInfoCard(
                        label: 'Unique Documents',
                        value: data.totalDocuments.toString(),
                        color: Colors.purple,
                      ),
                      _buildMiniInfoCard(
                        label: 'Notifications',
                        value: data.totalNotifications.toString(),
                        color: Colors.deepOrange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            buildSectionCard(
              title: 'Analytics / Chart Area',
              child: AdminBarChart(
                items: [
                  ChartItem(
                    label: 'Users',
                    value: data.totalUsers.toDouble(),
                    color: Colors.blue,
                  ),
                  ChartItem(
                    label: 'Offices',
                    value: data.totalOffices.toDouble(),
                    color: Colors.green,
                  ),
                  ChartItem(
                    label: 'Docs',
                    value: data.totalDocuments.toDouble(),
                    color: Colors.deepPurple,
                  ),
                  ChartItem(
                    label: 'Notif',
                    value: data.totalNotifications.toDouble(),
                    color: Colors.orange,
                  ),
                  ChartItem(
                    label: 'Sent',
                    value: data.totalSentEntries.toDouble(),
                    color: Colors.indigo,
                  ),
                  ChartItem(
                    label: 'Received',
                    value: data.totalReceivedEntries.toDouble(),
                    color: Colors.teal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            buildSectionCard(
              title: 'Summary',
              child: Column(
                children: [
                  _buildSummaryTile(
                    icon: Icons.people,
                    color: Colors.blue,
                    title: 'Registered Users',
                    subtitle:
                        '${data.totalUsers} user documents found in Firestore, excluding admin.',
                  ),
                  const Divider(),
                  _buildSummaryTile(
                    icon: Icons.apartment,
                    color: Colors.green,
                    title: 'Available Offices',
                    subtitle:
                        '${data.totalOffices} offices are listed from your embedded office data.',
                  ),
                  const Divider(),
                  _buildSummaryTile(
                    icon: Icons.description,
                    color: Colors.deepPurple,
                    title: 'Unique Documents',
                    subtitle:
                        '${data.totalDocuments} unique document IDs found from sentdocuments and receiveddocuments.',
                  ),
                  const Divider(),
                  _buildSummaryTile(
                    icon: Icons.notifications,
                    color: Colors.orange,
                    title: 'Notification Records',
                    subtitle:
                        '${data.totalNotifications} notification documents found across all offices.',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiniInfoCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class ChartItem {
  final String label;
  final double value;
  final Color color;

  ChartItem({required this.label, required this.value, required this.color});
}

class AdminBarChart extends StatelessWidget {
  final List<ChartItem> items;

  const AdminBarChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    double maxValue = 1;
    for (final item in items) {
      if (item.value > maxValue) {
        maxValue = item.value;
      }
    }

    return SizedBox(
      height: 320,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: items.map((item) {
          final heightFactor = item.value <= 0 ? 0.03 : (item.value / maxValue);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    item.value.toInt().toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: heightFactor.clamp(0.03, 1.0),
                        widthFactor: 0.75,
                        child: Container(
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: item.color.withOpacity(0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
