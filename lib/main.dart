import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:speedometer/di/injection_container.dart';
import 'package:speedometer/presentation/app.dart';

void main() async {
  await initializeApp();
  runApp(const PlaneSpeedometerApp());
}

Future<void> initializeApp()async{
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await initializeDependencies();
}