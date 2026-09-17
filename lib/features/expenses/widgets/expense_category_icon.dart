import 'package:flutter/material.dart';

import '../../../app/constants.dart';

/// Shared between [ExpenseSummary]'s category cards and [ExpenseCard] so
/// the two never drift apart on which icon represents which category.
IconData expenseCategoryIcon(String category) => switch (category) {
  ExpenseCategory.yiyecek => Icons.restaurant_outlined,
  ExpenseCategory.yakit => Icons.local_gas_station_outlined,
  ExpenseCategory.malzeme => Icons.handyman_outlined,
  ExpenseCategory.konaklama => Icons.hotel_outlined,
  ExpenseCategory.ulasim => Icons.directions_car_outlined,
  _ => Icons.more_horiz,
};
