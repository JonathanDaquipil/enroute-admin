import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'offices.dart';

class OfficesManagementPage extends StatefulWidget {
  const OfficesManagementPage({super.key});

  @override
  State<OfficesManagementPage> createState() => _OfficesManagementPageState();
}

class _OfficesManagementPageState extends State<OfficesManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String searchText = '';

  bool _isOfficeEmployee(Map<String, dynamic> data) {
    final userType = (data['user_type'] ?? '').toString().trim().toLowerCase();

    return userType == 'office employee' ||
        userType == 'employee' ||
        userType.contains('office employee');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Uint8List? decodeBase64Image(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) return null;

    try {
      String cleaned = base64String.trim();
      if (cleaned.contains(',')) {
        cleaned = cleaned.split(',').last;
      }
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  List<OfficeModel> _filterOffices() {
    if (searchText.trim().isEmpty) return offices;

    final query = searchText.trim().toLowerCase();
    return offices.where((office) {
      return office.name.toLowerCase().contains(query) ||
          office.id.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _showOfficeEmployees(
    BuildContext context,
    OfficeModel office,
  ) async {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: 820,
          height: 620,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    _buildOfficeLogo(office.id, size: 60),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            office.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Office ID: ${office.id.toUpperCase()}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.82),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .where('office', isEqualTo: office.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load employees:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final docs =
                        snapshot.data?.docs.where((doc) {
                          if (doc.id.toLowerCase() == 'admin') return false;
                          final data = doc.data() as Map<String, dynamic>;
                          return _isOfficeEmployee(data);
                        }).toList() ??
                        [];

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No employees found for this office.',
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;

                        final firstName = (data['first_name'] ?? '')
                            .toString()
                            .trim();
                        final lastName = (data['last_name'] ?? '')
                            .toString()
                            .trim();
                        final fullName = '$firstName $lastName'.trim().isEmpty
                            ? 'Unnamed User'
                            : '$firstName $lastName'.trim();

                        final email = (data['email'] ?? 'No email').toString();
                        final phone =
                            (data['phone_number'] ?? 'No phone number')
                                .toString();
                        final profileImage = (data['profile_image'] ?? '')
                            .toString();
                        final imageBytes = decodeBase64Image(profileImage);

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFFE0E7FF),
                                child: ClipOval(
                                  child: imageBytes != null
                                      ? Image.memory(
                                          imageBytes,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) {
                                            return const Icon(
                                              Icons.person,
                                              color: Color(0xFF1D4ED8),
                                            );
                                          },
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      phone,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  office.id.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeLogo(String officeId, {double size = 60}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Image.asset(
        'assets/$officeId.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Image.asset('assets/ocm.png', fit: BoxFit.contain);
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
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
        decoration: const InputDecoration(
          border: InputBorder.none,
          icon: Icon(Icons.search_rounded),
          hintText: 'Search office by name or id...',
        ),
      ),
    );
  }

  Widget _buildMiniTopCard({
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

  Widget _buildOfficeCard({
    required OfficeModel office,
    required int staffCount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOfficeLogo(office.id, size: 64),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$staffCount Staff',
                      style: const TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Text(
                  office.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      office.id.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Text(
                    'View Employees',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOffices = _filterOffices();
    final width = MediaQuery.of(context).size.width;

    int cardColumns() {
      if (width < 760) return 1;
      if (width < 1180) return 2;
      if (width < 1500) return 3;
      return 4;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, usersSnapshot) {
        if (usersSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (usersSnapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load users:\n${usersSnapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final userDocs = usersSnapshot.data?.docs ?? [];

        final Map<String, int> officeStaffCounts = {
          for (final office in offices) office.id: 0,
        };

        for (final doc in userDocs) {
          if (doc.id.toLowerCase() == 'admin') continue;

          final data = doc.data() as Map<String, dynamic>;

          if (!_isOfficeEmployee(data)) continue;

          final officeId = (data['office'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          if (officeStaffCounts.containsKey(officeId)) {
            officeStaffCounts[officeId] = officeStaffCounts[officeId]! + 1;
          }
        }

        final totalStaff = userDocs.where((doc) {
          if (doc.id.toLowerCase() == 'admin') return false;
          final data = doc.data() as Map<String, dynamic>;
          return _isOfficeEmployee(data);
        }).length;

        final activeOffices = officeStaffCounts.values
            .where((count) => count > 0)
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Office Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage offices and view the users assigned under each office.',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: width < 900 ? 2 : 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: width < 900 ? 2.0 : 2.35,
                children: [
                  _buildMiniTopCard(
                    title: 'Total Offices',
                    value: offices.length.toString(),
                    icon: Icons.apartment_rounded,
                    color: Colors.blue,
                  ),
                  _buildMiniTopCard(
                    title: 'Total Staff',
                    value: totalStaff.toString(),
                    icon: Icons.people_alt_rounded,
                    color: Colors.green,
                  ),
                  _buildMiniTopCard(
                    title: 'Active Offices',
                    value: activeOffices.toString(),
                    icon: Icons.domain_verification_rounded,
                    color: Colors.orange,
                  ),
                  _buildMiniTopCard(
                    title: 'Search Results',
                    value: filteredOffices.length.toString(),
                    icon: Icons.manage_search_rounded,
                    color: Colors.deepPurple,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSearchBar(),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredOffices.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cardColumns(),
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  mainAxisExtent: 255,
                ),
                itemBuilder: (context, index) {
                  final office = filteredOffices[index];
                  final staffCount = officeStaffCounts[office.id] ?? 0;

                  return _buildOfficeCard(
                    office: office,
                    staffCount: staffCount,
                    onTap: () => _showOfficeEmployees(context, office),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
