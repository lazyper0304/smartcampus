/// 学期教材订购记录（来自 frReport2 报表）
class TextbookOrder {
  final String semester;            // 学年学期
  final String grade;               // 年级
  final int quantity;               // 订购数量(册)
  final double totalPrice;          // 合计价格(元)
  final String department;          // 院系
  final String major;               // 专业
  final String className;           // 班级
  final List<TextbookBook> books;   // 订购教材明细

  TextbookOrder({
    required this.semester,
    required this.grade,
    required this.quantity,
    required this.totalPrice,
    required this.department,
    required this.major,
    required this.className,
    required this.books,
  });
}

/// 教材条目
class TextbookBook {
  final String isbn;
  final String name;
  final double price;

  TextbookBook({
    required this.isbn,
    required this.name,
    required this.price,
  });
}
