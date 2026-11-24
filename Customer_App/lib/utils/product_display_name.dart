/// Yunido: display name "Product (Variant)".
///
/// Variants are named like "500g", so a variant name alone is not a product
/// name. Mirrors CommonHelper::productDisplayName on the backend.
String productDisplayName(String? productName, String? variantName) {
  final product = (productName ?? '').trim();
  final variant = (variantName ?? '').trim();
  if (product.isEmpty) return variant;
  if (variant.isEmpty || variant.toLowerCase() == product.toLowerCase()) {
    return product;
  }
  if (variant.toLowerCase().contains(product.toLowerCase())) return variant;
  if (product.toLowerCase().contains(variant.toLowerCase())) return product;
  return '$product ($variant)';
}
