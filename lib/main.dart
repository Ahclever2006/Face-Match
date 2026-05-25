import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'features/face_match/data/services/tflite_model_service.dart';
import 'features/face_match/presentation/cubit/face_match_cubit.dart';
import 'features/face_match/presentation/screens/face_match_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await configureDependencies();

  // Initialize the TFLite model once at startup.
  // The logs printed here are how you verify the model specs.
  await getIt<TfliteModelService>().initialize();

  runApp(const FaceMatchPocApp());
}

class FaceMatchPocApp extends StatelessWidget {
  const FaceMatchPocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Match PoC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: BlocProvider<FaceMatchCubit>(
        create: (_) => getIt<FaceMatchCubit>(),
        child: const FaceMatchScreen(),
      ),
    );
  }
}
