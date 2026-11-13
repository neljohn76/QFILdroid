/// Explicit connection states shown in the dashboard.
///
/// A state may only advance when the underlying condition has actually been
/// verified (permission granted, handshake answered, programmer validated).
enum ConnectionStage {
  disconnected('Disconnected'),
  usbConnected('USB Connected'),
  permissionRequired('Permission Required'),
  edlCandidateDetected('EDL Candidate Detected'),
  protocolConnected('Protocol Connected'),
  programmerValidated('Programmer Validated'),
  readyForAuthorizedOperation('Ready for Authorized Operation'),
  operationInProgress('Operation in Progress'),
  operationFailed('Operation Failed'),
  operationCompleted('Operation Completed');

  const ConnectionStage(this.label);

  final String label;

  bool get isOperational =>
      this == protocolConnected ||
      this == programmerValidated ||
      this == readyForAuthorizedOperation;
}
