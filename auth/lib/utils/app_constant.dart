import 'dart:io';

abstract class AppConstant {
  AppConstant._();
  static final String secretKey = Platform.environment["SECRET_KEY"] ?? "SECRET_KEY";
}
