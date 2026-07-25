import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/route_names.dart';

class AdminBottomNavigation extends StatelessWidget {
  final int currentIndex;

  const AdminBottomNavigation({
    super.key,
    required this.currentIndex,
  });

  void _onItemTapped(int index, BuildContext context) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        context.goNamed(RouteNames.adminHome);
        break;
      case 1:
        context.goNamed(RouteNames.adminAppointments);
        break;
      case 2:
        context.goNamed(RouteNames.adminProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onItemTapped(index, context),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: Colors.white,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Randevular',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
