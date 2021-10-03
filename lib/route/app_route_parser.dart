import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yunshu_music/route/app_route_path.dart';

class AppRouteParser extends RouteInformationParser<AppRoutePath> {
  @override
  Future<AppRoutePath> parseRouteInformation(
      RouteInformation routeInformation) {
    return SynchronousFuture(
        AppRoutePath.createPage(routeInformation.location));
  }

  @override
  RouteInformation? restoreRouteInformation(AppRoutePath configuration) {
    return RouteInformation(location: configuration.path);
  }
}
