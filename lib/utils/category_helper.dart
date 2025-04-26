class CategoryHelper {
  static String categorizeItem(String itemName) {
    itemName = itemName.toLowerCase();

    if (_isVegetable(itemName)) {
      return 'Vegetables';
    } else if (_isDairy(itemName)) {
      return 'Dairy';
    } else if (_isMeat(itemName)) {
      return 'Meat';
    } else if (_isSeafood(itemName)) {
      return 'Seafood';
    } else if (_isGrain(itemName)) {
      return 'Grains';
    } else if (_isFruit(itemName)) {
      return 'Fruits';
    } else {
      return 'Other';
    }
  }

  static bool _isVegetable(String name) {
    final keywords = ['tomato', 'carrot', 'potato', 'lettuce', 'cucumber', 'onion', 'pepper', 'spinach', 'broccoli', 'zucchini'];
    return keywords.any((word) => name.contains(word));
  }

  static bool _isDairy(String name) {
    final keywords = ['milk', 'cheese', 'yogurt', 'butter', 'cream', 'egg'];
    return keywords.any((word) => name.contains(word));
  }

  static bool _isMeat(String name) {
    final keywords = ['chicken', 'beef', 'meat', 'pork', 'turkey', 'lamb'];
    return keywords.any((word) => name.contains(word));
  }

  static bool _isSeafood(String name) {
    final keywords = ['fish', 'salmon', 'shrimp', 'tuna', 'crab', 'lobster'];
    return keywords.any((word) => name.contains(word));
  }

  static bool _isGrain(String name) {
    final keywords = ['rice', 'pasta', 'bread', 'oats', 'cereal', 'flour'];
    return keywords.any((word) => name.contains(word));
  }

  static bool _isFruit(String name) {
    final keywords = ['apple', 'banana', 'orange', 'berries', 'melon', 'grape', 'peach', 'pear'];
    return keywords.any((word) => name.contains(word));
  }
}
