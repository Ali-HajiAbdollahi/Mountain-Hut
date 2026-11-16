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

  test('a requirement can carry the number of people it concerns; the number is optional', () async {
    final (:api, :requests) = apiWith((_) => jsonResponse({'booking': {}}, 201));
    await api.book(slotId: 3, people: 4, requirements: [
      {'n_people': 2, 'description': '2 vegetarians', 'allergy': false},
      {'n_people': null, 'description': 'gluten free', 'allergy': false},
    ]);

    final body = requests.single.json! as Map<String, dynamic>;
    expect(body['requirements'], [
      {'n_people': 2, 'description': '2 vegetarians', 'allergy': false},
      {'description': 'gluten free', 'allergy': false}, // not specified: key left out
    ]);
  });

  test('only the keys the API accepts are sent (anything else would be an "Unexpected field")', () async {
    final (:api, :requests) = apiWith((_) => jsonResponse({'booking': {}}));
    await api.updateBooking(7, requirements: [
      {'n_people': 1, 'description': 'nut allergy', 'allergy': true, 'rID': 9, 'bID': 7},
    ]);

    final body = requests.single.json! as Map<String, dynamic>;
    expect(body['requirements'], [
      {'n_people': 1, 'description': 'nut allergy', 'allergy': true},
    ]);
  });

  test('the staff booking sends the same requirement structure', () async {
    final (:api, :requests) = apiWith((_) => jsonResponse({'booking': {}}, 201));
    await api.createStaffBooking(
      hiker: {'mode': 'temporary', 'name': 'Rossi'},
      slotId: 3,
      people: 4,
      requirements: [{'n_people': 3, 'description': 'vegan', 'allergy': false}],
    );

    final body = requests.single.json! as Map<String, dynamic>;
    expect(body['requirements'], [
      {'n_people': 3, 'description': 'vegan', 'allergy': false},
    ]);
  });

  test('a new requirement draft starts empty and without the allergy flag', () {
    final draft = DietaryRequirementDraft();
    addTearDown(draft.dispose);
    expect(draft.controller.text, isEmpty);
    expect(draft.isAllergy, isFalse);
    expect(draft.people, isNull);
  });

  test('a draft becomes the API structure, with n_people only when specified', () {
    final draft = DietaryRequirementDraft()
      ..controller.text = '  nut allergy '
      ..isAllergy = true;
    addTearDown(draft.dispose);
    expect(draft.toJson(), {'description': 'nut allergy', 'allergy': true});

    draft.people = 2;
    expect(draft.toJson(), {'n_people': 2, 'description': 'nut allergy', 'allergy': true});
  });
}
