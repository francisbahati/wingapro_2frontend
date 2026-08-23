// lib/widgets/role_navigation.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class NavItem {
  final String label;
  final IconData icon;
  final Widget screen;
  NavItem({required this.label, required this.icon, required this.screen});
}

class MoreItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  MoreItem({required this.label, required this.icon, required this.onTap});
}

class RoleNavigation extends StatefulWidget {
  final List<NavItem> items;
  final List<MoreItem> moreItems;
  final int initialIndex;
  final Widget? floatingActionButton;

  const RoleNavigation({
    super.key,
    required this.items,
    this.moreItems = const [],
    this.initialIndex = 0,
    this.floatingActionButton,
  });

  @override
  State<RoleNavigation> createState() => _RoleNavigationState();
}

class _RoleNavigationState extends State<RoleNavigation> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
  }

  void _onItemTapped(int index) {
    if (index == 4) {
      _showMoreMenu();
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _showMoreMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1A2E).withOpacity(0.95)
                : Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade300.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // ✅ Wrap each ListTile in a Material widget with transparent color
                ...widget.moreItems.map((item) => Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(item.icon, color: Theme.of(context).primaryColor),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      item.onTap();
                    },
                  ),
                )),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      body: widget.items[_selectedIndex].screen,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1A2E).withOpacity(0.95)
              : Colors.white.withOpacity(0.95),
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: isDark ? Colors.white60 : Colors.grey.shade600,
            showUnselectedLabels: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            items: [
              ...widget.items.take(4).map((item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              )),
              const BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}