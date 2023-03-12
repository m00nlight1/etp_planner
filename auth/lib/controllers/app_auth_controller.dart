import 'dart:io';

import 'package:auth/models/response_app_model.dart';
import 'package:auth/models/user.dart';
import 'package:conduit/conduit.dart';

class AppAuthController extends ResourceController {
  final ManagedContext managedContext;

  AppAuthController(this.managedContext);

  @Operation.post()
  Future<Response> signIn(@Bind.body() User user) async {
    if (user.password == null || user.email == null) {
      return Response.badRequest(
          body: ResponseAppModel(message: "Поля Email и Password обязательны"));
    }

    final User fetchedUser = User();

    return Response.ok(
      ResponseAppModel(data: {
        "id": fetchedUser.id,
        "refreshToken": fetchedUser.refreshToken,
        "accessToken": fetchedUser.accessToken
      }, message: "Успешная авторизация")
          .toJson(),
    );
  }

  @Operation.put()
  Future<Response> signUp(@Bind.body() User user) async {
    if (user.password == null || user.email == null || user.username == null) {
      return Response.badRequest(
          body: ResponseAppModel(
              message: "Поля Username, Email и Password обязательны"));
    }

    final salt = generateRandomSalt();
    final hashPassword = generatePasswordHash(user.password!, salt);
    final User fetchedUser = User();

    try {
      late final int id;
      await managedContext.transaction((transaction) async {
        final qCreateUser = Query<User>(transaction)
          ..values.username = user.username
          ..values.email = user.email
          ..values.salt = salt
          ..values.hashPassword = hashPassword;

        final createdUser = await qCreateUser.insert();
        id = createdUser.id!;
        // _updateTokens(id, transaction);
      });
    } catch (e) {}
  }

  // void _updateTokens(int id, ManagedContext transaction) async {
  //   final Map<String, String> tokens = _getTokens(id);
  //   final qUpdateTokens = Query<User>(transaction)
  //     ..where((x) => x.id).equalTo(id)
  //     ..values.accessToken = tokens['access']
  //     ..values.refreshToken = tokens['refresh'];

  //   await qUpdateTokens.updateOne();
  // }

  // Map<String, String> _getTokens(int id) {
  //   final key = Platform.environment['SECRET_KEY'] ?? 'SECRET_KEY';
  //   final accessClaimSet =
  //       JwtClaim(maxAge: const Duration(hours: 1), otherClaims: {'id': id});
  //   final refreshClaimSet = JwtClaim(otherClaims: {'id': id});
  //   final tokens = <String, String>{};
  //   tokens['access'] = issueJwtHS256(accessClaimSet, key);
  //   tokens['refresh'] = issueJwtHS256(refreshClaimSet, key);

  //   return tokens;
  // }

  @Operation.post("refresh")
  Future<Response> refreshToken(
      @Bind.path("refresh") String refreshToken) async {
    final User fetchedUser = User();

    return Response.ok(
      ResponseAppModel(data: {
        "id": fetchedUser.id,
        "refreshToken": fetchedUser.refreshToken,
        "accessToken": fetchedUser.accessToken
      }, message: "Успешное обновление токенов")
          .toJson(),
    );
  }
}
