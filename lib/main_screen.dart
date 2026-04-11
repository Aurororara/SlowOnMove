import 'package:flutter/material.dart';
import 'exercise_selection_screen.dart';
import 'profile.dart';
import 'bottom_nav_bar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 預設選中中間的「Start」(Index 2) 或是首頁 (Index 0)
  int _selectedIndex = 2; 

  final List<Widget> _pages = [
    const Center(child: Text('Home')),       // Index 0
    const Center(child: Text('Community')),  // Index 1
    const ExerciseSelectionScreen(),         // Index 2 (運動選擇頁)
    const Center(child: Text('Ranking')),    // Index 3
    const ProfileScreen(),                   // Index 4 (個人檔案)
  ];

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}