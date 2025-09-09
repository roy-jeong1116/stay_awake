import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/drowsiness_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DrowsinessProvider()),
      ],
      child: MaterialApp(
        title: 'Stay AWAKE',
        theme: ThemeData(
          primarySwatch: Colors.red,
          fontFamily: 'Pretendard',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF6B6B),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
