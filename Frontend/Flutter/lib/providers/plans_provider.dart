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
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _plans = await _api.listPlans();
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
}
