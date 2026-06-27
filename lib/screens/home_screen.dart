import 'package:flutter/material.dart';
import 'package:closr_app/models/user_model.dart';
import 'discussions_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppUser user;

  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          DiscussionsScreen(user: widget.user),
          ProfileScreen(user: widget.user),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (index) {
            setState(() => _selectedTab = index);
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_outlined),
              activeIcon: const Icon(Icons.chat),
              label: 'Discussions',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outlined),
              activeIcon: const Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
