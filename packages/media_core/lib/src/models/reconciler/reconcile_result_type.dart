/// The outcome category of a reconciliation evaluation.
enum ReconcileResultType {
  /// Nothing to do: the plan was empty.
  noop,

  /// The plan still needs to be executed.
  pending,

  /// The plan finished successfully.
  completed,

  /// The plan finished with an error.
  failed,
}
