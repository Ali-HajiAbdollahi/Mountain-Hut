class TableDraft {
  const TableDraft({required this.tableNo, required this.seats});

  factory TableDraft.fromJson(Map<String, dynamic> json) => TableDraft(
        tableNo: json['table_no'] as int,
        seats: json['seats'] as int,
      );

  final int tableNo;
  final int seats;

  Map<String, dynamic> toJson() => {'table_no': tableNo, 'seats': seats};
}