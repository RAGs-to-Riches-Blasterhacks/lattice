import 'package:flutter/foundation.dart';
import 'package:lattice/models/plan_node.dart';
import 'package:lattice/services/api_service.dart';

class PlansProvider extends ChangeNotifier {
  final ApiService _api;

  List<PlanSummary> _plans = [];
  bool _loading = false;
  String? _error;

  PlansProvider(this._api);

  List<PlanSummary> get plans => _plans;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchPlans() async {
    final isRefresh = _plans.isNotEmpty;
    if (!isRefresh) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      _plans = await _api.listPlans();
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<Plan> getPlan(String planId) async {
    return _api.getPlan(planId);
  }

  Future<Plan> switchBranch(String planId, String branchId) async {
    return _api.switchBranch(planId, branchId);
  }

  /// Log progress on a node (change status, optionally add a note).
  ///
  /// Refreshes the plan list after a successful call so home screen
  /// summaries stay current.
  Future<Map<String, dynamic>> logProgress(
    String planId,
    String nodeId, {
    required String status,
    String? note,
  }) async {
    final result = await _api.logProgress(
      planId,
      nodeId,
      status: status,
      note: note,
    );
    await fetchPlans();
    return result;
  }

  /// Convenience wrapper that marks a node as completed.
  Future<Map<String, dynamic>> markNodeComplete(
    String planId,
    String nodeId,
  ) async {
    return logProgress(
      planId,
      nodeId,
      status: 'completed',
    );
  }

  /// Delete one or more plans by ID and refresh the plan list.
  Future<void> deletePlans(List<String> planIds) async {
    await Future.wait(planIds.map((id) => _api.deletePlan(id)));
    await fetchPlans();
  }

  /// Add a note to a node and refresh the plan list.
  Future<Plan> addNote(
    String planId,
    String nodeId,
    String content,
  ) async {
    final plan = await _api.addNote(planId, nodeId, content);
    await fetchPlans();
    return plan;
  }
}
