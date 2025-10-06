class SafetyChecklist {
  final String id;
  final DateTime date;
  final bool areaSafe;
  final String? safetyNotes;
  final bool threatsEncountered;
  final String? threatDetails;
  final bool cleanWaterAvailable;
  final bool foodAvailable;
  final List<String> hindrances;
  final String? additionalNotes;
  final String location;

  SafetyChecklist({
    required this.id,
    required this.date,
    required this.areaSafe,
    this.safetyNotes,
    required this.threatsEncountered,
    this.threatDetails,
    required this.cleanWaterAvailable,
    required this.foodAvailable,
    required this.hindrances,
    this.additionalNotes,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'areaSafe': areaSafe,
    'safetyNotes': safetyNotes,
    'threatsEncountered': threatsEncountered,
    'threatDetails': threatDetails,
    'cleanWaterAvailable': cleanWaterAvailable,
    'foodAvailable': foodAvailable,
    'hindrances': hindrances,
    'additionalNotes': additionalNotes,
    'location': location,
  };

  factory SafetyChecklist.fromJson(Map<String, dynamic> json) =>
      SafetyChecklist(
        id: json['id'],
        date: DateTime.parse(json['date']),
        areaSafe: json['areaSafe'],
        safetyNotes: json['safetyNotes'],
        threatsEncountered: json['threatsEncountered'],
        threatDetails: json['threatDetails'],
        cleanWaterAvailable: json['cleanWaterAvailable'],
        foodAvailable: json['foodAvailable'],
        hindrances: List<String>.from(json['hindrances']),
        additionalNotes: json['additionalNotes'],
        location: json['location'],
      );
}
