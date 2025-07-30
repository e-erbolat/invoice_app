/// Утилиты для валидации данных
class ValidationUtils {
  /// Валидация цены
  static bool isValidPrice(double price) {
    return price >= 0 && price.isFinite;
  }
  
  /// Валидация количества
  static bool isValidQuantity(int quantity) {
    return quantity > 0 && quantity <= 999999;
  }
  
  /// Валидация ID продукта
  static bool isValidProductId(String productId) {
    return productId.isNotEmpty && productId.length <= 100;
  }
  
  /// Валидация названия продукта
  static bool isValidProductName(String productName) {
    return productName.isNotEmpty && productName.length <= 200;
  }
  
  /// Проверка корректности скидки
  static bool isValidDiscount(double originalPrice, double discountedPrice) {
    return discountedPrice >= 0 && discountedPrice <= originalPrice;
  }
  
  /// Получить сообщение об ошибке валидации
  static String? getValidationError({
    double? price,
    double? originalPrice,
    int? quantity,
    String? productId,
    String? productName,
  }) {
    if (price != null && !isValidPrice(price)) {
      return 'Цена должна быть положительным числом';
    }
    
    if (originalPrice != null && !isValidPrice(originalPrice)) {
      return 'Оригинальная цена должна быть положительным числом';
    }
    
    if (quantity != null && !isValidQuantity(quantity)) {
      return 'Количество должно быть от 1 до 999999';
    }
    
    if (productId != null && !isValidProductId(productId)) {
      return 'ID продукта не может быть пустым';
    }
    
    if (productName != null && !isValidProductName(productName)) {
      return 'Название продукта не может быть пустым';
    }
    
    if (price != null && originalPrice != null && !isValidDiscount(originalPrice, price)) {
      return 'Цена со скидкой не может быть больше оригинальной цены';
    }
    
    return null;
  }
} 