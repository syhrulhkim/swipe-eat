/// A fake Supabase server, one route table deep.
///
/// The repositories are the least-covered layer in the app, and the reason is
/// that every one of them ends in a real `SupabaseClient`. `SupabaseClient`
/// takes an `httpClient:`, and every sub-client it builds is handed that same
/// client — so replacing it replaces the whole wire. A test can then say what
/// the server answers and assert what actually went out: the path, the query
/// string PostgREST built, and the JSON body of an RPC.
///
/// This lives in `support/` rather than beside a test, which is the one
/// exception to D70: it is not a double of one of *our* interfaces (those are
/// hand-written `fake_*.dart` files next to their tests), it fakes a
/// *protocol*. Nothing about it changes when a repository changes.
///
/// Rules for the tests that use it:
///
/// * **`test()`, never `testWidgets()`.** A response body over 10 000 bytes is
///   decoded on a `YAJsonIsolate`, which a widget tester's fake async will not
///   pump. Keep fixtures under ~2 KB and the decode stays on this isolate.
/// * **Answer in the shape PostgREST would.** `.select()` and a list RPC get a
///   JSON array; `.maybeSingle()` is still a GET, so it gets an array of one
///   (two elements is a real 406, and a free test); `.single()` after an insert
///   gets an object; a scalar RPC gets a bare number.
/// * **Never 503 or 520 in an error fixture.** Those are the only retried
///   codes, GET/HEAD only, and the retry sleeps for real seconds. 400 / 403 /
///   409 / 500 go out exactly once.
/// * **`addTearDown(client.dispose)`** — the client owns a JSON isolate.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One request the repository made, as it left the client.
class RecordedCall {
  RecordedCall({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String body;

  /// `/rest/v1/restaurants`, `/rest/v1/rpc/get_nearby`.
  String get path => url.path;

  /// The query string PostgREST built — `select`, `order`, `limit`, and the
  /// `column=op.value` filters.
  Map<String, String> get query => url.queryParameters;

  /// The request body decoded, or null on a GET (which has none).
  dynamic get json => body.isEmpty ? null : jsonDecode(body);
}

/// The route table. Register what the server answers, run the repository, then
/// read [calls].
class FakeSupabaseHttp {
  FakeSupabaseHttp() {
    client = MockClient((request) async {
      calls.add(RecordedCall(
        method: request.method,
        url: request.url,
        headers: request.headers,
        body: request.body,
      ));

      final route = _routes['${request.method} ${request.url.path}'];
      if (route == null) {
        return _respond(
          request,
          404,
          {'message': 'no route for ${request.method} ${request.url.path}'},
        );
      }
      return _respond(request, route.status, route.body, route.headers);
    });
  }

  final List<RecordedCall> calls = [];
  final Map<String, _Route> _routes = {};

  /// Records every request and routes on `'METHOD /path'`; anything
  /// unregistered comes back 404 saying so, which is a far more readable
  /// failure than a decode error on an empty body.
  late final MockClient client;

  /// The one call the test expects. Throws when there were none or several,
  /// which is the assertion a single-request test wanted anyway.
  RecordedCall get single => calls.single;

  /// A successful answer. [body] is encoded as JSON, so pass a `List` for a
  /// select, a `Map` for a `.single()`, or a bare number for a scalar RPC.
  void on(String method, String path, Object? body, {int status = 200}) {
    _routes['$method $path'] = _Route(status, body);
  }

  /// A PostgREST failure: `{code, message, details, hint}`, which is what
  /// `PostgrestException` is built from.
  void onError(
    String method,
    String path, {
    int status = 400,
    String code = 'PGRST000',
    String message = 'fake failure',
    String? details,
    String? hint,
  }) {
    _routes['$method $path'] = _Route(status, {
      'code': code,
      'message': message,
      'details': details,
      'hint': hint,
    });
  }

  /// A GoTrue failure: `{code, message}`. The `x-supabase-api-version` header
  /// goes with it because without it gotrue reads the legacy `error_code` key
  /// instead and the code arrives null.
  void onAuthError(
    String method,
    String path, {
    int status = 400,
    required String code,
    String message = 'fake auth failure',
  }) {
    _routes['$method $path'] = _Route(
      status,
      {'code': code, 'message': message},
      const {'x-supabase-api-version': '2024-01-01'},
    );
  }

  /// Every response is JSON, and every response carries the request that
  /// produced it: `MockClient` copies `request` off the `Response` the handler
  /// returns, not off the one it was given, and `postgrest` dereferences
  /// `response.request!` on the way out.
  static http.Response _respond(
    http.Request request,
    int status,
    Object? body, [
    Map<String, String> extraHeaders = const {},
  ]) {
    return http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json', ...extraHeaders},
    );
  }
}

class _Route {
  const _Route(this.status, this.body, [this.headers = const {}]);

  final int status;
  final Object? body;
  final Map<String, String> headers;
}

/// A real `SupabaseClient` pointed at [fake]. The URL and key are never
/// reached — they only have to be well-formed.
SupabaseClient fakeSupabaseClient(FakeSupabaseHttp fake) => SupabaseClient(
      'https://stub.supabase.co',
      'stub-anon-key',
      httpClient: fake.client,
    );

/// Signs a user in without a network round trip, for the repositories that
/// read `auth.currentUser`.
///
/// The access token is deliberately not a JWT: `Session.expiresAt` is decoded
/// from the token's payload and falls back to null when that fails, and a null
/// `expiresAt` is never expired — so nothing ever tries to refresh it and no
/// request goes out that the route table did not ask for.
Future<void> seedSession(
  SupabaseClient client, {
  String userId = '00000000-0000-4000-8000-000000000001',
  String email = 'stub@example.com',
}) {
  return client.auth.setInitialSession(jsonEncode({
    'access_token': 'stub-token',
    'token_type': 'bearer',
    'refresh_token': 'stub-refresh-token',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': email,
      'created_at': '2026-01-01T00:00:00Z',
    },
  }));
}
