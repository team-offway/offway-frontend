import 'package:flutter_test/flutter_test.dart';
import 'package:offway/mock/mock_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mock 사용자 데이터를 로드한다', () async {
    final user = await MockDataSource.user();
    expect(user['remainingLeaveDays'], isA<int>());
  });

  test('mock 지역 데이터에 후보지역과 월간 추천이 있다', () async {
    final regions = await MockDataSource.regions();
    expect(regions['candidates'], isNotEmpty);
    expect(regions['monthlyPicks'], isNotEmpty);
  });

  test('mock 코스는 최대 2박3일(Day3)까지만 존재한다', () async {
    final data = await MockDataSource.courses();
    final courses = data['courses'] as List;
    expect(courses, isNotEmpty);
    for (final course in courses) {
      final days = course['days'] as List;
      expect(days.length, lessThanOrEqualTo(3));
      for (final day in days) {
        expect(day['places'], isNotEmpty);
      }
    }
  });
}
