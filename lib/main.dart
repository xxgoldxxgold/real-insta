import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'constants.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  timeago.setLocaleMessages('ja', timeago.JaMessages());
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const RealInstaApp());
}
