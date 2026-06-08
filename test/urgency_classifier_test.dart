import 'package:flutter_test/flutter_test.dart';
import 'package:safe_voice/services/urgency_classifier.dart';

void main() {
  test('classifies immediate danger as CRITICAL', () {
    expect(
      UrgencyClassifier.classify('She is bleeding and I need help now'),
      'CRITICAL',
    );
  });

  test('classifies planned FGM as HIGH', () {
    expect(
      UrgencyClassifier.classify('The cutting is planned for next week'),
      'HIGH',
    );
  });

  test('classifies child-related reports as MEDIUM', () {
    expect(
      UrgencyClassifier.classify('My daughter is being threatened'),
      'MEDIUM',
    );
  });

  test('classifies general reports as LOW', () {
    expect(UrgencyClassifier.classify('I feel unsafe at home'), 'LOW');
  });
}
