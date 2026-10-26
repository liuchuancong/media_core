// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cast_device.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CastDevice extends CastDevice {
  @override
  final String id;
  @override
  final String name;
  @override
  final String backendId;
  @override
  final String? typeName;
  @override
  final String? manufacturer;
  @override
  final String? modelName;
  @override
  final Map<String, String> serviceEndpoints;
  @override
  final Map<String, Object?> attributes;

  factory _$CastDevice([void Function(CastDeviceBuilder)? updates]) =>
      (CastDeviceBuilder()..update(updates))._build();

  _$CastDevice._({
    required this.id,
    required this.name,
    required this.backendId,
    this.typeName,
    this.manufacturer,
    this.modelName,
    required this.serviceEndpoints,
    required this.attributes,
  }) : super._();
  @override
  CastDevice rebuild(void Function(CastDeviceBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  CastDeviceBuilder toBuilder() => CastDeviceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CastDevice &&
        id == other.id &&
        name == other.name &&
        backendId == other.backendId &&
        typeName == other.typeName &&
        manufacturer == other.manufacturer &&
        modelName == other.modelName &&
        serviceEndpoints == other.serviceEndpoints &&
        attributes == other.attributes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, backendId.hashCode);
    _$hash = $jc(_$hash, typeName.hashCode);
    _$hash = $jc(_$hash, manufacturer.hashCode);
    _$hash = $jc(_$hash, modelName.hashCode);
    _$hash = $jc(_$hash, serviceEndpoints.hashCode);
    _$hash = $jc(_$hash, attributes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CastDevice')
          ..add('id', id)
          ..add('name', name)
          ..add('backendId', backendId)
          ..add('typeName', typeName)
          ..add('manufacturer', manufacturer)
          ..add('modelName', modelName)
          ..add('serviceEndpoints', serviceEndpoints)
          ..add('attributes', attributes))
        .toString();
  }
}

class CastDeviceBuilder implements Builder<CastDevice, CastDeviceBuilder> {
  _$CastDevice? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _backendId;
  String? get backendId => _$this._backendId;
  set backendId(String? backendId) => _$this._backendId = backendId;

  String? _typeName;
  String? get typeName => _$this._typeName;
  set typeName(String? typeName) => _$this._typeName = typeName;

  String? _manufacturer;
  String? get manufacturer => _$this._manufacturer;
  set manufacturer(String? manufacturer) => _$this._manufacturer = manufacturer;

  String? _modelName;
  String? get modelName => _$this._modelName;
  set modelName(String? modelName) => _$this._modelName = modelName;

  Map<String, String>? _serviceEndpoints;
  Map<String, String>? get serviceEndpoints => _$this._serviceEndpoints;
  set serviceEndpoints(Map<String, String>? serviceEndpoints) =>
      _$this._serviceEndpoints = serviceEndpoints;

  Map<String, Object?>? _attributes;
  Map<String, Object?>? get attributes => _$this._attributes;
  set attributes(Map<String, Object?>? attributes) =>
      _$this._attributes = attributes;

  CastDeviceBuilder() {
    CastDevice._initialize(this);
  }

  CastDeviceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _backendId = $v.backendId;
      _typeName = $v.typeName;
      _manufacturer = $v.manufacturer;
      _modelName = $v.modelName;
      _serviceEndpoints = $v.serviceEndpoints;
      _attributes = $v.attributes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CastDevice other) {
    _$v = other as _$CastDevice;
  }

  @override
  void update(void Function(CastDeviceBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CastDevice build() => _build();

  _$CastDevice _build() {
    final _$result =
        _$v ??
        _$CastDevice._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'CastDevice', 'id'),
          name: BuiltValueNullFieldError.checkNotNull(
            name,
            r'CastDevice',
            'name',
          ),
          backendId: BuiltValueNullFieldError.checkNotNull(
            backendId,
            r'CastDevice',
            'backendId',
          ),
          typeName: typeName,
          manufacturer: manufacturer,
          modelName: modelName,
          serviceEndpoints: BuiltValueNullFieldError.checkNotNull(
            serviceEndpoints,
            r'CastDevice',
            'serviceEndpoints',
          ),
          attributes: BuiltValueNullFieldError.checkNotNull(
            attributes,
            r'CastDevice',
            'attributes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
