class Product {
  final String id;
  String name;
  bool isAlcohol;

  Product({
    required this.id,
    required this.name,
    required this.isAlcohol,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      isAlcohol: json['isAlcohol'] as bool? ?? false,
    );
  }

  Product copy() {
    return Product(
      id: id,
      name: name,
      isAlcohol: isAlcohol,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isAlcohol': isAlcohol,
    };
  }
}
