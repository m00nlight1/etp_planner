import 'dart:io';

import 'package:auth/models/response_app_model.dart';
import 'package:auth/models/user.dart';
import 'package:auth/utils/app_utils.dart';
import 'package:conduit/conduit.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class AppAuthController extends ResourceController {
  final ManagedContext managedContext;

  AppAuthController(this.managedContext);

  @Operation.post()
  Future<Response> signIn(@Bind.body() User user) async {
    if (user.password == null || user.email == null) {
      return Response.badRequest(
          body: ResponseAppModel(message: "Поля Email и Password обязательны"));
    }

    try {
      final qFindUser = Query<User>(managedContext)
        ..where((x) => x.email).equalTo(user.email)
        ..returningProperties((x) => [x.id, x.salt, x.hashPassword]);

      final findUser = await qFindUser.fetchOne();

      if (findUser == null) {
        throw QueryException.input('Пользователь не найден', []);
      }

      final requestHashPassword =
          generatePasswordHash(user.password ?? '', findUser.salt ?? '');

      if (requestHashPassword == findUser.hashPassword) {
        _updateTokens(findUser.id ?? -1, managedContext);

        final newUser =
            await managedContext.fetchObjectWithID<User>(findUser.id);

        return Response.ok(ResponseAppModel(
            data: newUser!.backing.contents, message: 'Успешная авторизация'));
      } else {
        throw QueryException.input('Неверный пароль', []);
      }
    } on QueryException catch (error) {
      return Response.serverError(
          body: ResponseAppModel(message: error.message));
    }
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
        _updateTokens(id, transaction);
      });

      final userData = await managedContext.fetchObjectWithID<User>(id);

      return Response.ok(ResponseAppModel(
          data: userData?.backing.contents, message: "Успешная регистрация"));
    } on QueryException catch (error) {
      return Response.serverError(
          body: ResponseAppModel(message: error.message));
    }
  }

  @Operation.post("refresh")
  Future<Response> refreshToken(
      @Bind.path("refresh") String refreshToken) async {
    try {
      final id = AppUtils.getIdFromToken(refreshToken);
      final user = await managedContext.fetchObjectWithID<User>(id);
      if (user!.refreshToken != refreshToken) {
        return Response.unauthorized(body: 'Токен не валидный');
      }

      _updateTokens(id, managedContext);

      return Response.ok(ResponseAppModel(
          data: user.backing.contents, message: 'Успешное обновление токенов'));
    } catch (error) {
      return Response.serverError(body: ResponseAppModel(message: error.toString()));
    }
  }

  void _updateTokens(int id, ManagedContext transaction) async {
    final Map<String, String> tokens = _getTokens(id);
    final qUpdateTokens = Query<User>(transaction)
      ..where((x) => x.id).equalTo(id)
      ..values.accessToken = tokens['access']
      ..values.refreshToken = tokens['refresh'];

    await qUpdateTokens.updateOne();
  }

  Map<String, String> _getTokens(int id) {
    final key = Platform.environment['SECRET_KEY'] ?? 'SECRET_KEY';
    final accessClaimSet =
        JwtClaim(maxAge: const Duration(hours: 1), otherClaims: {'id': id});
    final refreshClaimSet = JwtClaim(otherClaims: {'id': id});
    final tokens = <String, String>{};
    tokens['access'] = issueJwtHS256(accessClaimSet, key);
    tokens['refresh'] = issueJwtHS256(refreshClaimSet, key);

    return tokens;
  }
}
