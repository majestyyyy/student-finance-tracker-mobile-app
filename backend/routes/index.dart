import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  return Response.json(
    body: {
      'service': 'tracker-api',
      'version': '1.0.0',
      'phase': '1',
      'status': 'healthy',
    },
  );
}
