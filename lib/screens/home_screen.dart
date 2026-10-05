import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/action_card.dart';
import '../widgets/recent_rooms_list.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'onboarding_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final displayName = userProvider.displayName ?? 'Creator';

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.palette_rounded, color: Colors.deepPurple, size: 28),
            SizedBox(width: 8),
            Text(
              'SyncCanvas',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Edit Profile Name',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OnboardingScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Section
              Text(
                'Hello, $displayName',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create or join a canvas to collaborate in real-time.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 28),

              // Main Actions Section
              ActionCard(
                title: 'Create Room',
                subtitle: 'Start a new collaborative canvas room',
                icon: Icons.add_rounded,
                iconBackgroundColor: Colors.deepPurple.shade50,
                iconColor: Colors.deepPurple,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CreateRoomScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              ActionCard(
                title: 'Join Room',
                subtitle: 'Enter a code to join an existing canvas',
                icon: Icons.group_add_outlined,
                iconBackgroundColor: Colors.indigo.shade50,
                iconColor: Colors.indigo,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const JoinRoomScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 36),

              // Recent Rooms Section
              Text(
                'Recent Rooms',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              const RecentRoomsList(),
            ],
          ),
        ),
      ),
    );
  }
}
