import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'views/home_view.dart';
import 'controllers/wilayah_selection_controller.dart';
import 'controllers/indikator_controller.dart';
import 'controllers/paket_pekerjaan_controller.dart';
import 'controllers/pekerjaan_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => WilayahSelectionController(),
        ),
        ChangeNotifierProxyProvider<WilayahSelectionController, PaketPekerjaanController>(
          create: (_) => PaketPekerjaanController(),
          update: (context, wilayahSelection, paketPekerjaan) {
            paketPekerjaan!.updateWilayahSelection(wilayahSelection);
            return paketPekerjaan;
          },
        ),
        ChangeNotifierProxyProvider<PaketPekerjaanController, IndikatorController>(
          create: (context) => IndikatorController(),
          update: (context, pekerjaan, indikator) {
            indikator!.updatePekerjaanDependency(pekerjaan);
            return indikator;
          },
        ),
        ChangeNotifierProxyProvider<WilayahSelectionController, PekerjaanController>(
          create: (_) => PekerjaanController(),
          update: (context, wilayahSelection, pekerjaanController) {
            pekerjaanController!.updateWilayahSelection(wilayahSelection);
            return pekerjaanController;
          },
        ),
      ],
      child: const MyApp(), // wraps HomeView further down
    )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitor Bencana',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF22467a)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF22467a),
          foregroundColor: Colors.white,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeView(),
    );
  }
}