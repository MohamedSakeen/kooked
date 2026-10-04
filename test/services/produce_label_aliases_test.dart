import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/services/produce_label_aliases.dart';

import '../helpers/fake_scan_vision.dart';

void main() {
  group('ProduceLabelAliases coverage', () {
    test('maps every shipped label', () {
      expect(ProduceLabelAliases.unmappedLabels(produceLabels), isEmpty);
    });

    test('knows exactly the shipped vocabulary', () {
      expect(
        ProduceLabelAliases.knownLabels,
        unorderedEquals(produceLabels.map((e) => e.toLowerCase())),
      );
    });

    test('36 labels collapse to 31 canonical names', () {
      final canonical = ProduceLabelAliases.canonicalVocabulary(produceLabels);
      expect(canonical.length, ProduceLabelAliases.canonicalCount);
      expect(canonical.length, 31);
    });
  });

  group('ProduceLabelAliases capsicum family', () {
    const family = <String>[
      'bell pepper',
      'capsicum',
      'chilli pepper',
      'jalepeno',
      'paprika',
    ];

    test('every member canonicalises to Capsicum', () {
      for (final label in family) {
        expect(ProduceLabelAliases.canonicalize(label), 'Capsicum',
            reason: '$label should collapse to Capsicum');
      }
    });

    test('is order and case insensitive', () {
      expect(ProduceLabelAliases.canonicalize('BELL PEPPER'), 'Capsicum');
      expect(ProduceLabelAliases.canonicalize('  Paprika  '), 'Capsicum');
    });

    test('reports membersOf symmetrically', () {
      expect(
        ProduceLabelAliases.membersOf('Capsicum'),
        unorderedEquals(family),
      );
    });

    test('marks every member of a collapsed group', () {
      for (final label in family) {
        expect(ProduceLabelAliases.isCollapsed(label), isTrue, reason: label);
      }
      expect(ProduceLabelAliases.isCollapsed('corn'), isTrue);
      expect(ProduceLabelAliases.isCollapsed('sweetcorn'), isTrue);
    });

    test('does not mark distinct produce as collapsed', () {
      expect(ProduceLabelAliases.isCollapsed('apple'), isFalse);
      expect(ProduceLabelAliases.isCollapsed('lettuce'), isFalse);
      expect(ProduceLabelAliases.isCollapsed('sweetpotato'), isFalse);
    });
  });

  group('ProduceLabelAliases corn family', () {
    test('corn and sweetcorn collapse to Corn', () {
      expect(ProduceLabelAliases.canonicalize('corn'), 'Corn');
      expect(ProduceLabelAliases.canonicalize('sweetcorn'), 'Corn');
      expect(
        ProduceLabelAliases.membersOf('Corn'),
        <String>['corn', 'sweetcorn'],
      );
    });

    test('does not absorb sweetpotato', () {
      expect(ProduceLabelAliases.canonicalize('sweetpotato'), 'sweetpotato');
      expect(ProduceLabelAliases.isCollapsed('sweetpotato'), isFalse);
    });
  });

  group('ProduceLabelAliases leaves distinguishable produce alone', () {
    test('near-neighbours are never merged', () {
      for (final label in <String>[
        'raddish',
        'turnip',
        'potato',
        'sweetpotato',
        'peas',
        'soy beans',
        'cabbage',
        'cauliflower',
        'lettuce',
        'spinach',
        'cucumber',
        'garlic',
        'ginger',
      ]) {
        expect(ProduceLabelAliases.canonicalize(label), label,
            reason: '$label is visually distinct and must not be collapsed');
        expect(ProduceLabelAliases.isCollapsed(label), isFalse, reason: label);
      }
    });
  });

  group('ProduceLabelAliases passthrough behaviour', () {
    test('returns an unknown label unchanged rather than dropping it', () {
      expect(ProduceLabelAliases.canonicalize('dragonfruit'), 'dragonfruit');
      expect(ProduceLabelAliases.canonicalize('Starfruit'), 'Starfruit');
    });

    test('returns an empty string unchanged', () {
      expect(ProduceLabelAliases.canonicalize(''), '');
      expect(ProduceLabelAliases.canonicalize('   '), '');
    });

    test('membersOf a passthrough name is a singleton', () {
      expect(ProduceLabelAliases.membersOf('apple'), <String>['apple']);
    });

    test('canonicalizeAll preserves order and length', () {
      final result = ProduceLabelAliases.canonicalizeAll(<String>[
        'bell pepper',
        'corn',
        'apple',
        'sweetcorn',
      ]);
      expect(result, <String>['Capsicum', 'Corn', 'apple', 'Corn']);
    });

    test('reports drift when the label asset gains an unknown label', () {
      final drifted = <String>[...produceLabels, 'nashi pear'];
      expect(
        ProduceLabelAliases.unmappedLabels(drifted),
        <String>['nashi pear'],
      );
    });
  });
}