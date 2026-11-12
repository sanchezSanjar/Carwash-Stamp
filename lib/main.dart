import 'package:material_ui/material_ui.dart';

void main() => runApp(const CarwashStampApp());

class CarwashStampApp extends StatelessWidget {
  const CarwashStampApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Carwash Stamp',
      home: Scaffold(body: Center(child: Text('Carwash Stamp'))),
    );
  }
}
