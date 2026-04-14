import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String searchText = '';
  String selectedCategory = 'all';

  Uint8List? decodeBase64Image(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) return null;

    try {
      String cleaned = base64String.trim();

      if (cleaned.contains(',')) {
        cleaned = cleaned.split(',').last;
      }

      return base64Decode(cleaned);
    } catch (e) {
      debugPrint('Failed to decode base64 image: $e');
      return null;
    }
  }

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
    {"id": "bs", "name": "OCM - Bahay Silangan (BH)"},
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
    {"id": "citizen", "name": "Citizen"},
    {"id": "cso", "name": "Civil Society Organizations"},
    {"id": "ngo", "name": "Non-Governmental Organization"},
    {"id": "citizen_cso_ngo", "name": "Citizen / CSO / NGO"},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String getOfficeName(String? officeId) {
    if (officeId == null || officeId.trim().isEmpty) {
      return 'No Office';
    }

    final office = offices.firstWhere(
      (o) => o['id'] == officeId,
      orElse: () => {"id": officeId, "name": officeId},
    );

    return office['name'] ?? officeId;
  }

  String formatTimestamp(dynamic value) {
    if (value == null) return 'No data';

    if (value is Timestamp) {
      final dt = value.toDate();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.month}/${dt.day}/${dt.year}  $hour:$minute $ampm';
    }

    return value.toString();
  }

  bool _isOfficeEmployee(Map<String, dynamic> user) {
    final userType = (user['user_type'] ?? '').toString().trim().toLowerCase();
    return userType == 'office employee' ||
        userType == 'employee' ||
        userType.contains('office employee') ||
        userType.contains('employee');
  }

  bool _isCitizenGroup(Map<String, dynamic> user) {
    final userType = (user['user_type'] ?? '').toString().trim().toLowerCase();

    return userType == 'citizen' ||
        userType == 'cso' ||
        userType == 'ngo' ||
        userType == 'citizen/cso/ngo' ||
        userType == 'citizen / cso / ngo' ||
        userType == 'citizen_cso_ngo' ||
        userType.contains('citizen') ||
        userType.contains('cso') ||
        userType.contains('ngo');
  }

  bool _matchesSearch(Map<String, dynamic> user) {
    if (searchText.isEmpty) return true;

    final firstName = (user['first_name'] ?? '').toString().toLowerCase();
    final lastName = (user['last_name'] ?? '').toString().toLowerCase();
    final email = (user['email'] ?? '').toString().toLowerCase();
    final phone = (user['phone_number'] ?? '').toString().toLowerCase();
    final userType = (user['user_type'] ?? '').toString().toLowerCase();
    final officeName = getOfficeName(user['office']?.toString()).toLowerCase();

    final fullName = '$firstName $lastName'.trim();

    return fullName.contains(searchText) ||
        email.contains(searchText) ||
        phone.contains(searchText) ||
        userType.contains(searchText) ||
        officeName.contains(searchText);
  }

  bool _matchesSelectedCategory(Map<String, dynamic> user) {
    if (selectedCategory == 'all') return true;
    if (selectedCategory == 'office') return _isOfficeEmployee(user);
    if (selectedCategory == 'citizen') return _isCitizenGroup(user);
    return true;
  }

  Future<void> deleteUser(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text('Are you sure you want to delete $name?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('users').doc(docId).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete user: $e')));
    }
  }

  void showUserDetails(String docId, Map<String, dynamic> user) {
    final firstName = (user['first_name'] ?? '').toString();
    final lastName = (user['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim().isEmpty
        ? 'Unnamed User'
        : '$firstName $lastName'.trim();
    final email = (user['email'] ?? 'No email').toString();
    final phoneNumber = (user['phone_number'] ?? 'No phone number').toString();
    final userType = (user['user_type'] ?? 'No user type').toString();
    final profileImage = (user['profile_image'] ?? '').toString();
    final officeId = (user['office'] ?? '').toString();
    final officeName = getOfficeName(officeId);
    final lastAttemptedLogin = formatTimestamp(user['last_attempted_login']);

    showDialog(
      context: context,
      builder: (context) {
        final imageBytes = decodeBase64Image(profileImage);

        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            width: 780,
            constraints: const BoxConstraints(maxWidth: 780, maxHeight: 850),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF001F54), Color(0xFF0A3D91)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: Colors.white.withOpacity(0.18),
                            child: ClipOval(
                              child: imageBytes != null
                                  ? Image.memory(
                                      imageBytes,
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) {
                                        return const Icon(
                                          Icons.person,
                                          size: 36,
                                          color: Colors.white,
                                        );
                                      },
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 36,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _profileChip(userType),
                                  _profileChip(officeName),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _buildInfoBox(
                        label: 'First Name',
                        value: firstName.isEmpty ? 'No data' : firstName,
                        icon: Icons.badge_outlined,
                      ),
                      _buildInfoBox(
                        label: 'Last Name',
                        value: lastName.isEmpty ? 'No data' : lastName,
                        icon: Icons.person_outline,
                      ),
                      _buildInfoBox(
                        label: 'Phone Number',
                        value: phoneNumber,
                        icon: Icons.phone_outlined,
                      ),
                      _buildInfoBox(
                        label: 'User Type',
                        value: userType,
                        icon: Icons.verified_user_outlined,
                      ),
                      _buildInfoBox(
                        label: 'Office ID',
                        value: officeId.isEmpty ? 'No data' : officeId,
                        icon: Icons.code,
                      ),
                      _buildInfoBox(
                        label: 'Office Name',
                        value: officeName,
                        icon: Icons.apartment_outlined,
                      ),
                      _buildInfoBox(
                        label: 'Email',
                        value: email,
                        icon: Icons.email_outlined,
                      ),
                      _buildInfoBox(
                        label: 'Last Attempted Login',
                        value: lastAttemptedLogin,
                        icon: Icons.history,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Profile Image Preview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF001F54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(
                      minHeight: 260,
                      maxHeight: 420,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F8FC),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.blueGrey.shade100),
                    ),
                    child: imageBytes == null
                        ? const Center(
                            child: Text('No profile image available'),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 4,
                                child: Image.memory(
                                  imageBytes,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  errorBuilder: (_, __, ___) {
                                    return const Center(
                                      child: Text(
                                        'Failed to load profile image',
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tip: You can zoom the image using scroll or touch gestures.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await deleteUser(docId, fullName);
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete User'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _profileChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoBox({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 345,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF001F54).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF001F54)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(18, 0, 0, 0),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            searchText = value.trim().toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search by name, email, office, or user type',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF001F54)),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String keyValue,
    required String label,
    required IconData icon,
  }) {
    final bool isSelected = selectedCategory == keyValue;

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () {
        setState(() {
          selectedCategory = keyValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF001F54) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF001F54)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF001F54).withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
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

  Widget _buildTopStatCard({
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

  Widget _buildUserCard(String docId, Map<String, dynamic> user) {
    final firstName = (user['first_name'] ?? '').toString();
    final lastName = (user['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim().isEmpty
        ? 'Unnamed User'
        : '$firstName $lastName'.trim();
    final email = (user['email'] ?? 'No email').toString();
    final phoneNumber = (user['phone_number'] ?? 'No phone number').toString();
    final userType = (user['user_type'] ?? 'No type').toString();
    final officeName = getOfficeName(user['office']?.toString());
    final profileImage = (user['profile_image'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => showUserDetails(docId, user),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE8EEF8)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(18, 0, 0, 0),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Builder(
              builder: (context) {
                final imageBytes = decodeBase64Image(profileImage);

                return CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFEAF1FF),
                  child: ClipOval(
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return const Icon(
                                Icons.person,
                                color: Color(0xFF001F54),
                                size: 30,
                              );
                            },
                          )
                        : const Icon(
                            Icons.person,
                            color: Color(0xFF001F54),
                            size: 30,
                          ),
                  ),
                );
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF001F54),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _miniChip(Icons.phone, phoneNumber),
                      _miniChip(Icons.apartment, officeName),
                      _miniChip(Icons.verified_user, userType),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                IconButton(
                  tooltip: 'View Details',
                  onPressed: () => showUserDetails(docId, user),
                  icon: const Icon(
                    Icons.visibility_outlined,
                    color: Color(0xFF001F54),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete User',
                  onPressed: () => deleteUser(docId, fullName),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
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
            constraints: const BoxConstraints(maxWidth: 180),
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

  Widget _buildUserSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<QueryDocumentSnapshot> docs,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${docs.length}',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (docs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'No users found in this category.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final user = doc.data() as Map<String, dynamic>;
                return _buildUserCard(doc.id, user);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Users Management',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF001F54),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage registered users, separate office employees and Citizen / CSO / NGO accounts, view profile details, and delete users.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 20),
        _buildSearchBox(),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildCategoryChip(
              keyValue: 'all',
              label: 'All Users',
              icon: Icons.groups_rounded,
            ),
            _buildCategoryChip(
              keyValue: 'office',
              label: 'Office Employees',
              icon: Icons.badge_rounded,
            ),
            _buildCategoryChip(
              keyValue: 'citizen',
              label: 'Citizen / CSO / NGO',
              icon: Icons.public_rounded,
            ),
          ],
        ),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('users').snapshots(),
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
                  padding: EdgeInsets.all(30),
                  child: Text(
                    'Failed to load users: ${snapshot.error}',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            final allDocs = snapshot.data?.docs ?? [];

            final filteredDocs = allDocs.where((doc) {
              if (doc.id.toLowerCase() == 'admin') return false;
              final data = doc.data() as Map<String, dynamic>;
              return _matchesSearch(data) && _matchesSelectedCategory(data);
            }).toList();

            final officeEmployeeDocs = filteredDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _isOfficeEmployee(data);
            }).toList();

            final citizenGroupDocs = filteredDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _isCitizenGroup(data);
            }).toList();

            final totalUsers = allDocs
                .where((doc) => doc.id.toLowerCase() != 'admin')
                .length;
            final officeCount = allDocs.where((doc) {
              if (doc.id.toLowerCase() == 'admin') return false;
              final data = doc.data() as Map<String, dynamic>;
              return _isOfficeEmployee(data);
            }).length;
            final citizenCount = allDocs.where((doc) {
              if (doc.id.toLowerCase() == 'admin') return false;
              final data = doc.data() as Map<String, dynamic>;
              return _isCitizenGroup(data);
            }).length;

            return Column(
              children: [
                GridView.count(
                  crossAxisCount: width < 900 ? 2 : 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: width < 900 ? 2.0 : 2.35,
                  children: [
                    _buildTopStatCard(
                      title: 'Total Users',
                      value: totalUsers.toString(),
                      icon: Icons.groups_rounded,
                      color: Colors.blue,
                    ),
                    _buildTopStatCard(
                      title: 'Office Employees',
                      value: officeCount.toString(),
                      icon: Icons.badge_rounded,
                      color: Colors.green,
                    ),
                    _buildTopStatCard(
                      title: 'Citizen / CSO / NGO',
                      value: citizenCount.toString(),
                      icon: Icons.public_rounded,
                      color: Colors.orange,
                    ),
                    _buildTopStatCard(
                      title: 'Search Results',
                      value: filteredDocs.length.toString(),
                      icon: Icons.manage_search_rounded,
                      color: Colors.deepPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (selectedCategory == 'all' || selectedCategory == 'office')
                  _buildUserSection(
                    title: 'Office Employees',
                    subtitle:
                        'Registered office-based users and staff accounts.',
                    icon: Icons.badge_rounded,
                    accentColor: Colors.green,
                    docs: officeEmployeeDocs,
                  ),

                if (selectedCategory == 'all' || selectedCategory == 'office')
                  const SizedBox(height: 20),

                if (selectedCategory == 'all' || selectedCategory == 'citizen')
                  _buildUserSection(
                    title: 'Citizen / CSO / NGO',
                    subtitle:
                        'Citizen-facing, CSO, NGO, and mixed public accounts.',
                    icon: Icons.public_rounded,
                    accentColor: Colors.orange,
                    docs: citizenGroupDocs,
                  ),

                if (filteredDocs.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromARGB(18, 0, 0, 0),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 60,
                          color: Color(0xFF001F54),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF001F54),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
