/// Returns the Monday that starts the ISO week containing [date].
DateTime isoWeekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + DateTime.monday);

/// Returns the exclusive Monday boundary after the ISO week starting [monday].
DateTime isoWeekEndExclusive(DateTime monday) =>
    DateTime(monday.year, monday.month, monday.day + DateTime.daysPerWeek);
