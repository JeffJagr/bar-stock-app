class Product {
  final String id;
  String name;
  bool isAlcohol;
  final String? companyId;

  Product({
    required this.id,
    required this.name,
    required this.isAlcohol,
    this.companyId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      isAlcohol: json['isAlcohol'] as bool? ?? false,
      companyId: json['companyId'] as String?,
    );
  }

  Product copy() {
    return Product(
      id: id,
      name: name,
      isAlcohol: isAlcohol,
      companyId: companyId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isAlcohol': isAlcohol,
      if (companyId != null) 'companyId': companyId,
    };
  }
}
