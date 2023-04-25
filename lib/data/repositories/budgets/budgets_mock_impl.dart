import 'package:clock/clock.dart';
import 'package:faker/faker.dart';
import 'package:ovavue/core.dart';
import 'package:ovavue/domain.dart';
import 'package:rxdart/subjects.dart';

import '../auth/auth_mock_impl.dart';
import '../extensions.dart';

class BudgetsMockImpl implements BudgetsRepository {
  static BudgetEntity generateBudget({
    String? id,
    int? index,
    String? userId,
    DateTime? startedAt,
  }) =>
      generateNormalizedBudget(id: id, index: index, userId: userId, startedAt: startedAt).denormalize;

  static NormalizedBudgetEntity generateNormalizedBudget({
    String? id,
    int? index,
    String? title,
    String? userId,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    id ??= faker.guid.guid();
    userId ??= AuthMockImpl.id;
    startedAt ??= faker.randomGenerator.dateTime;
    return NormalizedBudgetEntity(
      id: id,
      path: '/budgets/$userId/$id',
      index: index ?? faker.randomGenerator.integer(100, min: 1),
      title: title ?? faker.lorem.words(2).join(' '),
      description: faker.lorem.sentence(),
      amount: (faker.randomGenerator.decimal(min: 1) * 1e9).toInt(),
      startedAt: startedAt,
      endedAt: endedAt,
      createdAt: faker.randomGenerator.dateTime,
      updatedAt: clock.now(),
    );
  }

  static final Map<String, BudgetEntity> _budgets = <String, BudgetEntity>{};

  final BehaviorSubject<Map<String, BudgetEntity>> _budgets$ =
      BehaviorSubject<Map<String, BudgetEntity>>.seeded(_budgets);

  NormalizedBudgetEntityList seed(
    int count, {
    String? userId,
  }) {
    final NormalizedBudgetEntityList items = NormalizedBudgetEntityList.generate(
      count,
      (int index) {
        final DateTime startedAt = clock.monthsFromNow(index);
        return BudgetsMockImpl.generateNormalizedBudget(
          index: index,
          title: '${clock.now().year}.${index + 1}',
          userId: userId,
          startedAt: startedAt,
          endedAt: count == index + 1 ? null : startedAt.add(const Duration(minutes: 10000)),
        );
      },
    );
    _budgets$.add(
      _budgets
        ..addAll(
          items
              .map((NormalizedBudgetEntity element) => element.denormalize)
              .foldToMap((BudgetEntity element) => element.id),
        ),
    );
    return items;
  }

  @override
  Future<ReferenceEntity> create(String userId, CreateBudgetData budget) async {
    final String id = faker.guid.guid();
    final String path = '/budgets/$userId/$id';
    final BudgetEntity newItem = BudgetEntity(
      id: id,
      path: path,
      index: budget.index,
      title: budget.title,
      description: budget.description,
      amount: budget.amount,
      startedAt: budget.startedAt,
      endedAt: budget.endedAt,
      createdAt: clock.now(),
      updatedAt: null,
    );
    _budgets$.add(_budgets..putIfAbsent(id, () => newItem));
    return ReferenceEntity(id: id, path: path);
  }

  @override
  Future<bool> update(UpdateBudgetData budget) async {
    _budgets$.add(_budgets..update(budget.id, (BudgetEntity prev) => prev.update(budget)));
    return true;
  }

  @override
  Future<bool> delete(String path) async {
    final String id = _budgets.values.firstWhere((BudgetEntity element) => element.path == path).id;
    _budgets$.add(_budgets..remove(id));
    return true;
  }

  @override
  Stream<BudgetEntityList> fetch(String userId) =>
      _budgets$.stream.map((Map<String, BudgetEntity> event) => event.values.toList());

  @override
  Stream<BudgetEntity> fetchActiveBudget(String userId) => _budgets$.stream.map(
        (Map<String, BudgetEntity> event) => event.values.toList(growable: false).firstWhere((_) => _.endedAt == null),
      );

  @override
  Future<bool> deactivateBudget({required String budgetPath, required DateTime endedAt}) async {
    final String id = _budgets.values.firstWhere((BudgetEntity element) => element.path == budgetPath).id;
    _budgets$.add(_budgets..update(id, (BudgetEntity prev) => prev.copyWith(endedAt: endedAt)));
    return true;
  }

  @override
  Stream<BudgetEntity> fetchOne({required String userId, required String budgetId}) =>
      _budgets$.stream.map((Map<String, BudgetEntity> event) => event[budgetId]!);
}

extension on BudgetEntity {
  BudgetEntity copyWith({
    String? id,
    String? path,
    int? index,
    String? title,
    int? amount,
    String? description,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      BudgetEntity(
        id: id ?? this.id,
        path: path ?? this.path,
        index: index ?? this.index,
        title: title ?? this.title,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  BudgetEntity update(UpdateBudgetData update) => copyWith(
        title: update.title,
        description: update.description,
        amount: update.amount,
        endedAt: update.endedAt,
        updatedAt: clock.now(),
      );
}

extension on NormalizedBudgetEntity {
  BudgetEntity get denormalize => BudgetEntity(
        id: id,
        path: path,
        index: index,
        title: title,
        description: description,
        amount: amount,
        startedAt: startedAt,
        endedAt: endedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
