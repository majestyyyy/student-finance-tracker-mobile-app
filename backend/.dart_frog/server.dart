// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';


import '../routes/index.dart' as index;
import '../routes/v1/wallets/create.dart' as v1_wallets_create;
import '../routes/v1/users/sync.dart' as v1_users_sync;

import '../routes/_middleware.dart' as middleware;

void main() async {
  final address = InternetAddress.tryParse('') ?? InternetAddress.anyIPv6;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  hotReload(() => createServer(address, port));
}

Future<HttpServer> createServer(InternetAddress address, int port) {
  final handler = Cascade().add(buildRootHandler()).handler;
  return serve(handler, address, port);
}

Handler buildRootHandler() {
  final pipeline = const Pipeline().addMiddleware(middleware.middleware);
  final router = Router()
    ..mount('/', (context) => buildHandler()(context))
    ..mount('/v1/wallets', (context) => buildV1WalletsHandler()(context))
    ..mount('/v1/users', (context) => buildV1UsersHandler()(context));
  return pipeline.addHandler(router);
}

Handler buildHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildV1WalletsHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/create', (context) => v1_wallets_create.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildV1UsersHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/sync', (context) => v1_users_sync.onRequest(context,));
  return pipeline.addHandler(router);
}

