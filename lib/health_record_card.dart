import 'package:flutter/material.dart';

class HealthRecordCard extends StatelessWidget {
  final Map record;

  const HealthRecordCard({
    super.key,
    required this.record,
  });

  String formatDate(String? date) {
    if (date == null) return "";

    return date.replaceAll("-", "/");
  }

  String formatTime(String? time) {
    if (time == null) return "";

    if (time.contains("T")) {
      return time.split("T")[1].substring(0, 5);
    }

    return "";
  }

  @override
  Widget build(BuildContext context) {
    final bool hasBody = record["height"] != null || record["weight"] != null;

    final bool hasBlood = record["systolic"] != null;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 15,
      ),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "📅 ${formatDate(record["record_date"])}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "🕘 ${formatTime(record["created_at"])}",
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (hasBody) ...[
              if (record["height"] != null)
                Text(
                  "📏 身高 ${record["height"]} cm",
                  style: const TextStyle(fontSize: 16),
                ),
              if (record["weight"] != null)
                Text(
                  "⚖️ 體重 ${record["weight"]} kg",
                  style: const TextStyle(fontSize: 16),
                ),
            ],
            if (hasBlood) ...[
              Text(
                "❤️ 血壓 ${record["systolic"]}/${record["diastolic"]}",
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                "💓 心率 ${record["pulse"]}",
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
