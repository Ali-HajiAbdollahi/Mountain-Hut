// MH-05 Provide party requirements — unit tests (API client, requirement draft)
import 'package:client/features/booking/presentation/widgets/dietary_requirements_section.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_http.dart';

void main() {
  test('book sends the list of requirements, each with its own allergy flag', () async {
    final (:api, :requests) = apiWith((_) => jsonResponse({'booking': {}}, 201));
    await api.book(slotId: 3, people: 4, requirements: [
      {'description': '1 vegan, peanut allergy', 'allergy': true},
      {'description': '1 shellfish allergy', 'allergy': true},
      {'description': '2 vegetarians', 'allergy': false},
    ]);

    final body = requests.single.json! as Map<String, dynamic>;
    expect(body['requirements'], [
      {'description': '1 vegan, peanut allergy', 'allergy': true},
      {'description': '1 shellfish allergy', 'allergy': true},
      {'description': '2 vegetarians', 'allergy': false},
    ]);
  });

  test('a new requirement draft starts empty and without the allergy flag', () {
    final draft = DietaryRequirementDraft();
    addTearDown(draft.dispose);
    expect(draft.controller.text, isEmpty);
    expect(draft.isAllergy, isFalse);
  });
}
