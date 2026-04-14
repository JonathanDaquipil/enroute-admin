import 'package:admin_enroute/notices.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'users.dart';
import 'dashboard.dart';
import 'offices_management_page.dart';
import 'documents.dart';

class Layout extends StatefulWidget {
  const Layout({super.key});

  @override
  State<Layout> createState() => _LayoutState();
}

class _LayoutState extends State<Layout> {
  int selectedIndex = 0;

  final List<String> menuTitles = [
    'Dashboard',
    'Users',
    'Offices',
    'Documents',
    'Notices',
    'Settings',
  ];

  final List<IconData> menuIcons = [
    Icons.dashboard,
    Icons.people,
    Icons.apartment,
    Icons.description,
    Icons.notifications,
    Icons.settings,
  ];

  void onMenuTap(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Widget buildPageContent() {
    switch (selectedIndex) {
      case 0:
        return const DashboardPage();
      case 1:
        return const UsersPage();
      case 2:
        return const OfficesManagementPage();
      case 3:
        return const DocumentsPage();
      case 4:
        return const NoticesPage();
      case 5:
        return const PlaceholderPage(title: 'Settings');
      default:
        return const DashboardPage();
    }
  }

  String getHeaderTitle() {
    switch (selectedIndex) {
      case 0:
        return 'Admin Dashboard';
      case 1:
        return 'Users Management';
      case 2:
        return 'Office Management';
      case 3:
        return 'Documents Management';
      case 4:
        return 'Notices';
      case 5:
        return 'Settings';
      default:
        return 'Admin Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      drawer: isMobile
          ? Drawer(
              child: SidebarContent(
                selectedIndex: selectedIndex,
                menuTitles: menuTitles,
                menuIcons: menuIcons,
                onMenuTap: (index) {
                  Navigator.pop(context);
                  onMenuTap(index);
                },
                onLogout: logout,
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            SizedBox(
              width: 270,
              child: SidebarContent(
                selectedIndex: selectedIndex,
                menuTitles: menuTitles,
                menuIcons: menuIcons,
                onMenuTap: onMenuTap,
                onLogout: logout,
              ),
            ),
          Expanded(
            child: Column(
              children: [
                HeaderBar(isMobile: isMobile, title: getHeaderTitle()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: buildPageContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SidebarContent extends StatelessWidget {
  final int selectedIndex;
  final List<String> menuTitles;
  final List<IconData> menuIcons;
  final Function(int) onMenuTap;
  final VoidCallback onLogout;

  const SidebarContent({
    super.key,
    required this.selectedIndex,
    required this.menuTitles,
    required this.menuIcons,
    required this.onMenuTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF001F54),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Admin Enroute',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              itemCount: menuTitles.length,
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onMenuTap(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              menuIcons[index],
                              color: isSelected ? Colors.amber : Colors.white70,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                menuTitles[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.amber
                                      : Colors.white,
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderBar extends StatelessWidget {
  final bool isMobile;
  final String title;

  const HeaderBar({super.key, required this.isMobile, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Color(0xFFF8FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB(18, 0, 0, 0),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu, color: Color(0xFF001F54)),
              ),
            ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF001F54),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF001F54).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user, color: Color(0xFF001F54), size: 18),
                SizedBox(width: 8),
                Text(
                  'Administrator',
                  style: TextStyle(
                    color: Color(0xFF001F54),
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
}

class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
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
        children: [
          Icon(
            Icons.admin_panel_settings,
            size: 70,
            color: const Color(0xFF001F54).withOpacity(0.85),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF001F54),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'This page is ready. You can now connect your database and add your admin functions here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
          ),
        ],
      ),
    );
  }
}
