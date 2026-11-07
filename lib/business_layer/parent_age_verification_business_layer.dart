class ParentAgeController {
  // Update your limits here!
  static const int _minAge = 15;
  static const int _maxAge = 100;

  static bool ValidParentAge(int birthYear) {
    final age = DateTime.now().year - birthYear;
    return age >= _minAge && age <= _maxAge;
  }

  static int? parseYear(List<String> digits) {
    return int.tryParse(digits.join());
  }
}
