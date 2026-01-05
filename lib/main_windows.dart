import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ekosatsss/theme_provider.dart';
import 'package:ekosatsss/login_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'EKOSATSSS - Windows',
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.system,
          home: const LoginScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}