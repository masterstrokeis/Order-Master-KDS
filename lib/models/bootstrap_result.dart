import 'product_category_model.dart';
import 'product_model.dart';
import 'restaurant_model.dart';
import 'station_model.dart';
import 'websocket_config.dart';

class BootstrapResult {
  const BootstrapResult({
    required this.serverTime,
    required this.restaurant,
    required this.outlet,
    required this.stations,
    required this.categories,
    required this.products,
    required this.websocket,
  });

  factory BootstrapResult.fromJson(
    Map<String, dynamic> json, {
    String? httpBaseUrl,
  }) {
    return BootstrapResult(
      serverTime: DateTime.parse(json['serverTime'] as String),
      restaurant: Restaurant.fromJson(
        json['restaurant'] as Map<String, dynamic>,
      ),
      outlet: Outlet.fromJson(json['outlet'] as Map<String, dynamic>),
      stations: (json['stations'] as List<dynamic>)
          .map((dynamic e) => Station.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List<dynamic>)
          .map(
            (dynamic e) => ProductCategory.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      products: (json['products'] as List<dynamic>)
          .map((dynamic e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
      websocket: WebsocketConfig.fromJson(
        json['websocket'] as Map<String, dynamic>,
        httpBaseUrl: httpBaseUrl,
      ),
    );
  }

  final DateTime serverTime;
  final Restaurant restaurant;
  final Outlet outlet;
  final List<Station> stations;
  final List<ProductCategory> categories;
  final List<Product> products;
  final WebsocketConfig websocket;
}
