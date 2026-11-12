/// Describes a single USB endpoint reported by the Android USB Host API.
class UsbEndpointInfo {
  const UsbEndpointInfo({
    required this.endpointNumber,
    required this.direction,
    required this.type,
    required this.maxPacketSize,
  });

  factory UsbEndpointInfo.fromMap(Map<Object?, Object?> map) {
    return UsbEndpointInfo(
      endpointNumber: (map['endpointNumber'] as num?)?.toInt() ?? -1,
      direction: (map['direction'] as String?) ?? 'unknown',
      type: (map['type'] as String?) ?? 'unknown',
      maxPacketSize: (map['maxPacketSize'] as num?)?.toInt() ?? 0,
    );
  }

  final int endpointNumber;
  final String direction;
  final String type;
  final int maxPacketSize;

  bool get isBulk => type == 'bulk';
  bool get isIn => direction == 'in';
  bool get isOut => direction == 'out';

  Map<String, Object?> toMap() => {
        'endpointNumber': endpointNumber,
        'direction': direction,
        'type': type,
        'maxPacketSize': maxPacketSize,
      };
}

/// Describes a USB interface and its endpoints.
class UsbInterfaceInfo {
  const UsbInterfaceInfo({
    required this.id,
    required this.interfaceClass,
    required this.interfaceSubclass,
    required this.interfaceProtocol,
    required this.endpoints,
  });

  factory UsbInterfaceInfo.fromMap(Map<Object?, Object?> map) {
    final rawEndpoints = (map['endpoints'] as List<Object?>?) ?? const [];
    return UsbInterfaceInfo(
      id: (map['id'] as num?)?.toInt() ?? -1,
      interfaceClass: (map['class'] as num?)?.toInt() ?? 0,
      interfaceSubclass: (map['subclass'] as num?)?.toInt() ?? 0,
      interfaceProtocol: (map['protocol'] as num?)?.toInt() ?? 0,
      endpoints: rawEndpoints
          .whereType<Map<Object?, Object?>>()
          .map(UsbEndpointInfo.fromMap)
          .toList(growable: false),
    );
  }

  final int id;
  final int interfaceClass;
  final int interfaceSubclass;
  final int interfaceProtocol;
  final List<UsbEndpointInfo> endpoints;

  bool get hasBulkPair =>
      endpoints.any((e) => e.isBulk && e.isIn) &&
      endpoints.any((e) => e.isBulk && e.isOut);

  Map<String, Object?> toMap() => {
        'id': id,
        'class': interfaceClass,
        'subclass': interfaceSubclass,
        'protocol': interfaceProtocol,
        'endpoints': endpoints.map((e) => e.toMap()).toList(),
      };
}

/// A USB device as enumerated by the Android USB Host API.
class UsbDeviceInfo {
  const UsbDeviceInfo({
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    required this.hasPermission,
    required this.interfaces,
    this.deviceId = -1,
    this.deviceClass = 0,
    this.deviceSubclass = 0,
    this.deviceProtocol = 0,
    this.manufacturerName,
    this.productName,
    this.serialNumber,
  });

  factory UsbDeviceInfo.fromMap(Map<Object?, Object?> map) {
    final rawInterfaces = (map['interfaces'] as List<Object?>?) ?? const [];
    return UsbDeviceInfo(
      deviceName: (map['deviceName'] as String?) ?? '',
      vendorId: (map['vendorId'] as num?)?.toInt() ?? 0,
      productId: (map['productId'] as num?)?.toInt() ?? 0,
      hasPermission: (map['hasPermission'] as bool?) ?? false,
      deviceId: (map['deviceId'] as num?)?.toInt() ?? -1,
      deviceClass: (map['deviceClass'] as num?)?.toInt() ?? 0,
      deviceSubclass: (map['deviceSubclass'] as num?)?.toInt() ?? 0,
      deviceProtocol: (map['deviceProtocol'] as num?)?.toInt() ?? 0,
      manufacturerName: map['manufacturerName'] as String?,
      productName: map['productName'] as String?,
      serialNumber: map['serialNumber'] as String?,
      interfaces: rawInterfaces
          .whereType<Map<Object?, Object?>>()
          .map(UsbInterfaceInfo.fromMap)
          .toList(growable: false),
    );
  }

  final String deviceName;
  final int vendorId;
  final int productId;
  final int deviceId;
  final int deviceClass;
  final int deviceSubclass;
  final int deviceProtocol;
  final String? manufacturerName;
  final String? productName;
  final String? serialNumber;
  final bool hasPermission;
  final List<UsbInterfaceInfo> interfaces;

  String get vendorIdHex =>
      vendorId.toRadixString(16).padLeft(4, '0').toUpperCase();

  String get productIdHex =>
      productId.toRadixString(16).padLeft(4, '0').toUpperCase();

  String get idString => '$vendorIdHex:$productIdHex';

  String get displayName =>
      productName ?? manufacturerName ?? 'USB device $idString';

  bool get hasBulkPair => interfaces.any((i) => i.hasBulkPair);

  @override
  bool operator ==(Object other) =>
      other is UsbDeviceInfo && other.deviceName == deviceName;

  @override
  int get hashCode => deviceName.hashCode;
}
