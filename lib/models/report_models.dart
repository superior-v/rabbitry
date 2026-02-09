class KPICard {
  final String label;
  final String value;
  final String? subtitle;
  final bool isTrending;
  final bool isPositive;

  KPICard({
    required this.label,
    required this.value,
    this.subtitle,
    this.isTrending = false,
    this.isPositive = true,
  });
}

class ChartData {
  final String label;
  final double value;
  final String? sublabel;

  ChartData({
    required this.label,
    required this.value,
    this.sublabel,
  });
}

class RankingItem {
  final int rank;
  final String name;
  final String id;
  final String subtitle;
  final double percentage;
  final bool isTop;

  RankingItem({
    required this.rank,
    required this.name,
    required this.id,
    required this.subtitle,
    required this.percentage,
    this.isTop = false,
  });
}