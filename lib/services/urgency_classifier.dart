class UrgencyClassifier {
  static const List<_KeywordRule> _rules = [
    _KeywordRule('CRITICAL', [
      'imminent',
      'today',
      'tonight',
      'tomorrow',
      'happening now',
      'right now',
      'scheduled',
      'this morning',
      'bleeding',
      'help me',
      'hiding',
      'being cut',
      'knife',
      'blade',
      'in danger',
    ]),
    _KeywordRule('HIGH', [
      'cut',
      'cutting',
      'cutter',
      'this week',
      'next week',
      'planned',
      'fgm date',
      'next month',
      'soon',
      'will be cut',
      'going to cut',
      'next week cut',
    ]),
    _KeywordRule('MEDIUM', ['child', 'minor', 'girl', 'daughter']),
  ];

  static String classify(String content) {
    final normalized = content.toLowerCase();

    for (final rule in _rules) {
      if (rule.keywords.any(normalized.contains)) {
        return rule.level;
      }
    }

    return 'LOW';
  }
}

class _KeywordRule {
  const _KeywordRule(this.level, this.keywords);

  final String level;
  final List<String> keywords;
}
