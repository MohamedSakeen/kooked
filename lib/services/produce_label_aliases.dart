/// Canonicalisation of raw produce-classifier output into names a user can act on.
///
/// The shipped model emits 36 mutually exclusive indices. Six of those indices
/// are not visually separable concepts:
///
/// * `bell pepper`, `capsicum`, `chilli pepper`, `jalepeno` and `paprika` are all
///   cultivars of *Capsicum annuum*. A photograph of a red pepper does not
///   contain the information needed to choose between them.
/// * `corn` and `sweetcorn` are the same species; the dataset has no field-corn
///   variety to contrast against.
///
/// Forcing a 1-of-5 choice among identical-looking classes produces an answer
/// that is arbitrary but reported with high confidence, which reads to a user as
/// an unreliable model. Collapsing each group to one canonical name removes the
/// arbitrary choice without touching the model, its weights, its indices or
/// `food_labels.txt`.
///
/// This maps only what is provably indistinguishable. Distinct produce that a
/// dataset happens to lack (`raddish` vs `turnip`, `potato` vs `sweetpotato`)
/// are deliberately left separate — absence of training data is not evidence
/// that two vegetables look the same.
class ProduceLabelAliases {
  const ProduceLabelAliases._();

  /// Groups of model labels that collapse to a single canonical name.
  ///
  /// Keys are canonical display names; values are the raw model labels in the
  /// group. Every entry in [collapsedGroups] must resolve to a real label.
  static const Map<String, List<String>> collapsedGroups = <String, List<String>>{
    'Capsicum': <String>[
      'bell pepper',
      'capsicum',
      'chilli pepper',
      'jalepeno',
      'paprika',
    ],
    'Corn': <String>['corn', 'sweetcorn'],
  };

  /// Model labels that keep their own canonical name.
  static const Set<String> _passThrough = <String>{
    'apple',
    'banana',
    'beetroot',
    'cabbage',
    'carrot',
    'cauliflower',
    'cucumber',
    'eggplant',
    'garlic',
    'ginger',
    'grapes',
    'kiwi',
    'lemon',
    'lettuce',
    'mango',
    'onion',
    'orange',
    'pear',
    'peas',
    'pineapple',
    'pomegranate',
    'potato',
    'raddish',
    'soy beans',
    'spinach',
    'sweetpotato',
    'tomato',
    'turnip',
    'watermelon',
  };

  /// Number of distinct names the 36 model indices resolve to.
  static const int canonicalCount = 31;

  static final Map<String, String> _labelToCanonical = <String, String>{
    for (final entry in collapsedGroups.entries)
      for (final label in entry.value) label: entry.key,
    for (final label in _passThrough) label: label,
  };

  static final Set<String> _knownLabels = _labelToCanonical.keys.toSet();

  /// Labels this module understands, for coverage assertions and tests.
  static Set<String> get knownLabels => Set<String>.unmodifiable(_knownLabels);

  /// Whether [label] belongs to a group that collapses to a single name.
  ///
  /// True for every member of a collapsed group, including the one whose text
  /// already equals the canonical name: all five *Capsicum* labels are
  /// interchangeable, so all five report true.
  static bool isCollapsed(String label) {
    final key = label.trim().toLowerCase();
    final canonical = _labelToCanonical[key];
    if (canonical == null) return false;
    return membersOf(canonical).length > 1;
  }

  /// The canonical name for a raw model label.
  ///
  /// Returns [label] unchanged when it is unknown, so an unexpected label is
  /// surfaced rather than silently dropped.
  static String canonicalize(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return trimmed;
    return _labelToCanonical[trimmed.toLowerCase()] ?? trimmed;
  }

  /// Canonical names for a whole label set, order preserved.
  static List<String> canonicalizeAll(List<String> labels) =>
      labels.map(canonicalize).toList();

  /// Raw model labels represented by [canonicalName].
  ///
  /// Returns a single-element list for names that are not collapsed.
  static List<String> membersOf(String canonicalName) {
    final key = canonicalName.trim().toLowerCase();
    for (final entry in collapsedGroups.entries) {
      if (entry.key.toLowerCase() == key) return List<String>.unmodifiable(entry.value);
    }
    return List<String>.unmodifiable(<String>[canonicalName]);
  }

  /// Every distinct canonical name implied by [labels].
  ///
  /// [labels] is expected to be the contents of `food_labels.txt`. The result is
  /// sorted so it is stable across runs and directly comparable in tests.
  static List<String> canonicalVocabulary(List<String> labels) {
    final canonical = labels.map(canonicalize).toSet().toList()..sort();
    return canonical;
  }

  /// Labels in [labels] that this module has no mapping for.
  ///
  /// A non-empty result means the label asset and this module have drifted apart
  /// and must be reconciled before shipping.
  static List<String> unmappedLabels(List<String> labels) {
    final missing = <String>[];
    for (final label in labels) {
      final key = label.trim().toLowerCase();
      if (key.isNotEmpty && !_knownLabels.contains(key)) missing.add(label);
    }
    return missing;
  }
}