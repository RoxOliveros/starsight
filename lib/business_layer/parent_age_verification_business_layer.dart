class ParentAgeController {
  static const int _minAge = 18;

  static bool isAdult(int birthYear) {
    final age = DateTime.now().year - birthYear;
    return age >= _minAge;
  }

  static int? parseYear(List<String> digits) {
    return int.tryParse(digits.join());
  }
}