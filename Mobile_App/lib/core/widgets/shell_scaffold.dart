import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/profile/presentation/bloc/profile_bloc.dart';
import '../../features/profile/presentation/bloc/profile_event.dart';
import '../../injection/injection_container.dart' as di;
import 'curved_bottom_nav.dart';
import 'global_top_bar.dart';

class ShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScaffold({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProfileBloc>(
          create: (_) => di.sl<ProfileBloc>()..add(LoadProfileEvent()),
        ),
      ],
      child: Scaffold(
          appBar: const GlobalTopBar(),
          body: navigationShell,
          bottomNavigationBar: CurvedBottomNav(
            currentIndex: navigationShell.currentIndex,
            onTap: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            items: const [
              CurvedBottomNavItem(icon: Icons.dashboard, label: 'Dashboard'),
              CurvedBottomNavItem(icon: Icons.people, label: 'Patients'),
              CurvedBottomNavItem(icon: Icons.work, label: 'Cases'),
              CurvedBottomNavItem(icon: Icons.person, label: 'Profile'),
            ],
          ),
        ),
    );
  }
}

