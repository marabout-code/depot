/// The depot the local database is currently scoped to.
///
/// The sync engine already only hands a device the rows it is allowed to read
/// (its own depot plus the shared legacy NULL-depot rows), but SQLite itself
/// keeps whatever was pulled under a previous login. Every list provider reads
/// straight from that database with no filter, so a shared device — or the same
/// device after signing in as another depot's admin — could show another
/// depot's orders. This value object closes that gap: reads are filtered to the
/// active scope, and the database is purged when the scope changes (logout, or
/// signing in as a different depot).
///
/// The rule mirrors the server's `sync_pull_rows`: a depot-scoped caller may
/// read its own depot's rows plus the shared legacy NULL-depot rows; an
/// unrestricted caller (superadmin or a legacy admin without a depot) reads
/// everything.
class DepotScope {
  const DepotScope._(this._kind, this.depotId);

  /// No filtering. The default before a scope is established and in tests, so
  /// pre-auth behaviour is unchanged.
  const DepotScope.all() : this._(DepotScopeKind.all, null);

  /// Signed out: nothing is readable (the offline-login user rows are read
  /// through LocalAuthService, which bypasses this scope).
  const DepotScope.none() : this._(DepotScopeKind.none, null);

  /// A single depot: only its rows plus the shared legacy NULL rows.
  const DepotScope.depot(String depotId) : this._(DepotScopeKind.depot, depotId);

  final DepotScopeKind _kind;
  final String? depotId;

  bool get isNone => _kind == DepotScopeKind.none;

  bool get isAll => _kind == DepotScopeKind.all;

  bool get isDepot => _kind == DepotScopeKind.depot;

  /// Whether a row carrying [rowDepotId] may be read under this scope. A null
  /// [rowDepotId] is a legacy pre-depot row, shared by every depot.
  bool allows(String? rowDepotId) {
    switch (_kind) {
      case DepotScopeKind.all:
        return true;
      case DepotScopeKind.none:
        return false;
      case DepotScopeKind.depot:
        return rowDepotId == null || rowDepotId == depotId;
    }
  }

  /// The depot a locally-created row should be stamped with, or null when it
  /// carries no depot (an unrestricted caller's new row, matching the server).
  String? get stampDepotId => isDepot ? depotId : null;

  @override
  bool operator ==(Object other) =>
      other is DepotScope &&
      other._kind == _kind &&
      other.depotId == depotId;

  @override
  int get hashCode => Object.hash(_kind, depotId);

  @override
  String toString() => 'DepotScope($_kind, $depotId)';
}

enum DepotScopeKind { all, none, depot }
