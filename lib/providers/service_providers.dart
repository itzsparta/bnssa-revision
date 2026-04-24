// lib/providers/service_providers.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/ad_service.dart';
import '../services/team_service.dart';

part 'service_providers.g.dart';

@riverpod
AdService adService(Ref ref) => AdService();

@riverpod
TeamService teamService(Ref ref) => TeamService();
