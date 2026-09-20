import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/astronomy.dart';
import '../core/theme.dart';
import '../models/mount_device.dart';
import '../models/stars.dart';
import '../painters/projection3d.dart';
import '../widgets/dialogs.dart';
import 'mount_link.dart';
import 'remote_service.dart';
import 'settings_service.dart';

/// Estado global de la app: puerto de `main.service.ts` de OrionGo_Mobile.
class AppState extends ChangeNotifier {
  AppState(this._settings);

  final SettingsService _settings;
  final RemoteService remote = RemoteService();

  static const String appVersion = '1.0.0';

  MountLink? _link;

  // ---------------------------------------------------------------- identidad
  String username = 'Invitado';
  String userId = '';
  bool isNew = true;

  // ---------------------------------------------------------- sesión remota
  bool isAdmin = false;
  bool isRemote = false;
  bool isOnline = false;
  bool isInitServer = false;
  bool isServerConnected = false;
  bool isAdminConnected = false;
  bool isRouteApp = false;
  Color color = Colors.white;

  /// Estado del dispositivo del administrador (lo reciben los usuarios).
  bool deviceConnectedAdmin = false;
  String nameDeviceConnectedAdmin = 'OrionDevice1v1';

  String idDevice = '';
  String codeDevice = '';
  String idDeviceC = '';
  String codeDeviceC = '';

  // ------------------------------------------------------------- dispositivos
  MountDevice? deviceConnected;
  List<MountDevice> devicesRegistered = [];
  final Map<String, MountStatus> statusByDevice = {};

  // ---------------------------------------------------------------- montura
  double position1 = 0;
  double position2 = 0;
  double angleC1 = 0;
  double angleC2 = 0;
  int microsteps1 = 16;
  int microsteps2 = 16;
  double drv1r = 14.4;
  double drv2r = 28.8;
  bool isEnableDEC = false;
  bool isEnableRA = false;
  int uart1 = 0;
  int uart2 = 0;
  double speed1 = 1600;
  double speed2 = 1600;
  double accel1 = 480;
  double accel2 = 480;
  bool isTracking = false;
  bool isGoTo = false;
  double earthSpeed = 0;
  int microstepForFollow = 0;

  // -------------------------------------------------------------- ubicación
  double latitude = 21.094412;
  double longitude = -89.572705;

  // ------------------------------------------------------------------ cielo
  Star starSelected = Star.coordinates(
    0, 42, 44.33, 41, 16, 7.5,
    'Andrómeda', 3, -1.5,
  );
  double touchedRA = 0;
  double touchedDEC = 90;
  bool isAzimuthalGrid = true;
  bool isEquatorialGrid = true;
  bool showBelowHorizon = false;
  double magMax = 6.0;
  double zoom3D = 4;
  double zoomFactor = 4;
  double rAdjust = 0;

  /// Orientación de la cámara del cielo (grados).
  double rotationAz = 90;
  double rotationAlt = 249;
  double rotationRoll = 0;

  DateTime dtNow = DateTime.now();
  DateTime? _customBaseTime;
  int stopwatchStart = DateTime.now().millisecondsSinceEpoch;

  /// Equivale a `cbHourEdit`: cuando está activo la hora no corre sola.
  bool isHourEditing = false;
  bool isCustomTime = false;

  /// Cronómetros mostrados en la vista del cielo.
  int trackingSeconds = 0;
  String trackingTimeStr = '00:00:00';
  double goToTime = 0;
  String goToTimeStr = '00:00';
  bool noticed = false;
  int deviceDateCT = DateTime.now().millisecondsSinceEpoch;

  // ------------------------------------------------------------------ remoto
  List<RemoteUser> usersData = [];

  // ------------------------------------------------------------------- logs
  final List<String> logServerList = [
    '--------- Consola del servidor Orion ---------',
  ];
  final List<String> logDeviceList = [
    '--------- Consola de la montura Orion ---------',
  ];

  // ------------------------------------------------------------------- fps
  int fps = 0;

  // --------------------------------------------------------------- arranque
  bool ready = false;

  /// Barra lateral colapsada en escritorio (solo iconos).
  bool sidebarCollapsed = false;

  MountLink? get link => _link;
  bool get hasLink => _link != null && _link!.isSupported;

  Future<void> init() async {
    await _settings.initDefaults();

    userId = await _settings.get<String>('userId');
    if (userId == 'NA' || userId.isEmpty) {
      userId = generateUserId();
      await _settings.set('userId', userId);
    }

    username = await _settings.get<String>('username');
    isNew = await _settings.get<bool>('isNew');
    isAzimuthalGrid = await _settings.get<bool>('isAzimuthalGrid');
    isEquatorialGrid = await _settings.get<bool>('isEquatorialGrid');
    sidebarCollapsed = await _settings.get<bool>('sidebarCollapsed');
    devicesRegistered = MountDevice.listFromJson(
      jsonEncode(await _settings.get<dynamic>('devicesRegistered')),
    );

    verifyDefault();
    ready = true;
    notifyListeners();
  }

  void attachLink(MountLink? link) {
    _link = link;
    link?.incoming.listen((line) {
      sendLogDevice('RX: $line');
      handleDeviceLine(line);
    });
  }

  /// Procesa una línea del protocolo ORIONV1 (equivale a processCommand()).
  void handleDeviceLine(String raw) {
    final command = raw.trim();
    if (command.isEmpty) return;

    if (command.startsWith('SNDD:')) {
      applyMotorInfo(command.substring(5));
    } else if (command.startsWith('SPD:')) {
      applyDriverPosition(command.substring(4));
    } else if (command.startsWith('OK:')) {
      Dialogs.message(
        '¡Emparejado correctamente!',
        'El dispositivo ${deviceConnected?.name ?? ''} ha sido emparejado correctamente.',
      );
      Future<void>.delayed(const Duration(seconds: 1), () => sendToDevice('ADC:'));
      sendToDevice('GETD:');
    } else if (command.startsWith('ADCG:')) {
      _handleDeviceCard(command.substring(5));
    }
  }

  Future<void> _handleDeviceCard(String json) async {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final idDevice = data['idDevice']?.toString() ?? '';
      final model = data['model']?.toString() ?? '';

      final exists = devicesRegistered.any((d) => d.idDevice == idDevice);
      if (exists) return;

      final accept = await Dialogs.confirm(
        '¿Desea agregar este nuevo dispositivo?',
        'El dispositivo $idDevice con el modelo $model aún no se encuentra en '
            'el catálogo. Se recomienda agregarlo para acceder a funciones adicionales.',
      );
      if (!accept) return;

      final device = deviceConnected;
      if (device == null) return;

      await addDevice(
        MountDevice(
          id: device.id,
          name: device.name,
          address: device.address,
          model: model,
          idDevice: idDevice,
          isDefault: devicesRegistered.isEmpty,
        ),
      );
    } catch (_) {
      sendLogDevice('No se pudo procesar el dispositivo detectado.');
    }
  }

  /// SNDD: información de los drivers.
  void applyMotorInfo(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      sendLogDevice('La información se ha actualizado: $json');

      microsteps1 = _i(data['microsteps1']);
      position1 = _d(data['position1']);
      isEnableDEC = data['isEnableDEC'] == true;
      uart1 = _i(data['UART1']);
      speed1 = _d(data['speed1']);
      accel1 = _d(data['accel1']);

      microsteps2 = _i(data['microsteps2']);
      position2 = _d(data['position2']);
      isEnableRA = data['isEnableRA'] == true;
      uart2 = _i(data['UART2']);
      speed2 = _d(data['speed2']);
      accel2 = _d(data['accel2']);

      isTracking = data['isTracking'] == true;
      isGoTo = data['isGoTo'] == true;
      deviceDateCT = DateTime.now().millisecondsSinceEpoch;

      earthSpeed = _d(data['earthSpeed']);
      microstepForFollow = _i(data['microstepForFollow']);
      // El driver 1 mueve DEC, el 2 mueve RA (igual que en la app móvil).
      drv1r = _d(data['DRV1R'], fallback: drv1r);
      drv2r = _d(data['DRV2R'], fallback: drv2r);

      recomputeAngles();
      notifyListeners();
    } catch (_) {
      sendLogDevice('Error al procesar la información de la montura.');
    }
  }

  /// SPD: posición instantánea de los drivers.
  void applyDriverPosition(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      position1 = _d(data['position1'], fallback: position1);
      position2 = _d(data['position2'], fallback: position2);
      recomputeAngles();
      notifyListeners();
    } catch (_) {
      sendLogDevice('Error al procesar la posición del driver.');
    }
  }

  void recomputeAngles() {
    if (microsteps1 > 0 && drv1r > 0) {
      angleC1 = ((position1 / (200 * microsteps1)) * 360) / drv1r;
    }
    if (microsteps2 > 0 && drv2r > 0) {
      angleC2 = ((position2 / (200 * microsteps2)) * 360) / drv2r;
    }
  }

  static double _d(Object? value, {double fallback = 0}) => value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? fallback;

  static int _i(Object? value, {int fallback = 0}) => value is num
      ? value.toInt()
      : int.tryParse('$value') ?? fallback;

  // ------------------------------------------------------------------ comunes
  String generateUserId() =>
      '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
      '${math.Random().nextInt(1 << 32).toRadixString(36)}';

  void sendLogServer(String text) {
    logServerList.add(text);
  }

  void sendLogDevice(String text) {
    logDeviceList.add(text);
  }

  void setUserColor() {
    color = isAdmin ? AppColors.admin : AppColors.user;
    notifyListeners();
  }

  // ------------------------------------------------------------ dispositivos
  void verifyDefault() {
    final defaults = devicesRegistered.where((d) => d.isDefault).toList();

    if (defaults.isEmpty) {
      idDeviceC = 'NoDevice';
      if (isAdmin && remote.connected) {
        remote.disconnect();
      }
      notifyListeners();
      return;
    }

    for (final device in defaults) {
      final parts = (device.idDevice ?? '').split('#');
      if (parts.length > 1) idDeviceC = parts[1];
    }
    notifyListeners();
  }

  Future<void> addDevice(MountDevice device) async {
    devicesRegistered = [...devicesRegistered, device];
    await _settings.set(
      'devicesRegistered',
      devicesRegistered.map((d) => d.toJson()).toList(),
    );
    verifyDefault();
  }

  Future<void> deleteDevice(MountDevice device) async {
    devicesRegistered = devicesRegistered
        .where((d) => d.idDevice != device.idDevice)
        .toList();
    await _settings.set(
      'devicesRegistered',
      devicesRegistered.map((d) => d.toJson()).toList(),
    );
    verifyDefault();
  }

  Future<void> setDefaultDevice(MountDevice device) async {
    for (final d in devicesRegistered) {
      d.isDefault = d.idDevice == device.idDevice;
    }
    await _settings.set(
      'devicesRegistered',
      devicesRegistered.map((d) => d.toJson()).toList(),
    );
    verifyDefault();
  }

  void setStatusDevice(String address, MountStatus status) {
    for (final key in statusByDevice.keys.toList()) {
      statusByDevice[key] = MountStatus.available;
    }
    statusByDevice[address] = status;
    notifyListeners();
  }

  /// Conecta con una montura (Bluetooth en Android, puerto serie en PC).
  Future<void> connectDevice(MountDevice device) async {
    final link = _link;
    if (link == null || !link.isSupported) {
      await Dialogs.error('Esta plataforma no admite conexión directa.');
      return;
    }

    setStatusDevice(device.address, MountStatus.connecting);
    Dialogs.toast('Conectando con ${device.name}...');

    try {
      await link.requestPermissions();
      await link.connect(device);

      deviceConnected = device;
      setStatusDevice(device.address, MountStatus.connected);
      notifyListeners();

      await sendToDevice('ORIONV1:');
      Dialogs.toast('Conectado con ${device.name}');
    } catch (error) {
      setStatusDevice(device.address, MountStatus.noConnected);
      deviceConnected = null;
      notifyListeners();
      await Dialogs.error('No se pudo conectar con ${device.name}: $error');
    }
  }

  Future<void> disconnectDevice() async {
    final device = deviceConnected;
    if (device == null) return;

    final accept = await Dialogs.confirm(
      '¿Seguro quieres desemparejarte?',
      'Al desemparejarte la app ya no se comunicará con el dispositivo.',
    );
    if (!accept) return;

    setStatusDevice(device.address, MountStatus.available);
    await _link?.disconnect();
    deviceConnected = null;
    notifyListeners();
    Dialogs.toast('Se ha desconectado del dispositivo');
  }

  // ------------------------------------------------------------------ envío
  Future<void> sendToDevice(String message) async {
    final link = _link;
    if (link == null || !link.isConnected) {
      sendLogDevice('TX (sin conexión): $message');
      return;
    }
    sendLogDevice('TX: $message');
    await link.send(message);
  }

  // ------------------------------------------------------------------ tiempo
  void tickTime() {
    final now = DateTime.now();
    if (!isHourEditing) {
      if (isOnline) return;

      if (isCustomTime && _customBaseTime != null) {
        final elapsed = now.millisecondsSinceEpoch - stopwatchStart;
        dtNow = _customBaseTime!.add(Duration(milliseconds: elapsed));
      } else {
        dtNow = now;
        _customBaseTime = null;
        stopwatchStart = now.millisecondsSinceEpoch;
      }
    } else {
      stopwatchStart = now.millisecondsSinceEpoch;
      _customBaseTime = dtNow;
    }
  }

  void setCustomTime(DateTime value) {
    dtNow = value;
    _customBaseTime = value;
    stopwatchStart = DateTime.now().millisecondsSinceEpoch;
    isCustomTime = true;
    notifyListeners();
  }

  void resetTimeToNow() {
    isCustomTime = false;
    isHourEditing = false;
    _customBaseTime = null;
    dtNow = DateTime.now();
    notifyListeners();
  }

  /// Segundos desde el inicio del día (para el slider de la app móvil).
  int get secondsOfDay {
    final start = DateTime(dtNow.year, dtNow.month, dtNow.day);
    return dtNow.difference(start).inSeconds;
  }

  void setSecondsOfDay(int seconds) {
    final start = DateTime(dtNow.year, dtNow.month, dtNow.day);
    setCustomTime(start.add(Duration(seconds: seconds.clamp(0, 86399))));
  }

  // ---------------------------------------------------------------- contadores
  void tickCounters() {
    if (isTracking) {
      noticed = !noticed;
      trackingSeconds = ((DateTime.now().millisecondsSinceEpoch - deviceDateCT) /
              1000)
          .clamp(0, 359999)
          .toInt();
      trackingTimeStr = Astro.secondsOfDayToHms(trackingSeconds);
    } else {
      noticed = false;
      trackingSeconds = 0;
      trackingTimeStr = '00:00:00';
    }

    if (isGoTo && goToTime > 0) {
      noticed = !noticed;
      goToTimeStr = goToTime.toStringAsFixed(0).padLeft(2, '0');
      goToTime -= 1;
    } else if (!isTracking) {
      goToTimeStr = '00:00';
      goToTime = 0;
    }
  }

  void setFps(int value) {
    if (fps == value) return;
    fps = value;
    notifyListeners();
  }

  // ------------------------------------------------------------------ cielo
  /// Orientación inicial: mira al sur con la inclinación de la latitud.
  void resetCamera() {
    rotationAz = 90;
    rotationAlt = 270 - latitude;
    rotationRoll = 0;
    touchedRA = 0;
    touchedDEC = 90;
    notifyListeners();
  }

  /// Hora sideral local en grados (para AR/DEC <-> azimut/altitud).
  double get localSiderealDegrees =>
      starSelected.getLocalSiderealTime(longitude, dtNow) * 15;

  ({double az, double alt}) equatorialToHorizontal(double raDeg, double decDeg) =>
      Astro.equatorialToHorizontalLst(
        raDeg,
        decDeg,
        localSiderealDegrees,
        latitude,
      );

  /// Convierte el centro de la vista en coordenadas ecuatoriales.
  void syncTouchedFromCamera() {
    final coord = Astro.horizontalToEquatorial(
      rotationAz - 90,
      -(rotationAlt - 270),
      0,
      latitude,
    );
    touchedRA = coord.ra;
    touchedDEC = coord.dec;
  }

  /// Coloca el marcador del observador al tocar el cielo.
  void setTouchedFromAzAlt(double az, double alt) {
    final coord = Astro.horizontalToEquatorial(az, alt, 0, latitude);
    touchedRA = coord.ra;
    touchedDEC = coord.dec;
    notifyListeners();
  }

  /// Arrastre: gira el cielo como en la app móvil.
  void rotateBy(double dx, double dy, {double gain = 0.6}) {
    const minZoom = 4.0;
    final factor = SkyProjection.sensitivityFactor(rotationAlt);
    final zoomEffective = (zoom3D * (1 - factor)) + (minZoom * factor);
    final safeZoom = zoomEffective <= 0 ? 0.0001 : zoomEffective;

    rotationAz -= dx * (gain / safeZoom);
    rotationAlt -= dy * (gain / zoom3D);

    rotationAz = rotationAz >= 360
        ? 0
        : (rotationAz <= 0 ? 360 : rotationAz);
    rotationAlt = Astro.clamp(rotationAlt, 180.5, 359.5);

    syncTouchedFromCamera();
    notifyListeners();
  }

  /// Zoom (pinza o rueda del ratón).
  void zoomBy(double factor) {
    zoomFactor = Astro.clamp(zoomFactor * factor, 4, 10000);
    zoom3D = zoomFactor < 4 ? 4 : zoomFactor;
    setZoom(zoom3D);
  }

  void selectStar(Star star) {
    star.precess(dtNow);
    starSelected = star;
    star.calculatePositionWithDate(latitude, longitude, dtNow);
    notifyListeners();
  }

  void clearStar() {
    starSelected = Star.coordinates(0, 0, 0, 0, 0, 0, '', 0, 6);
    refresh();
  }

  /// Notifica a la interfaz desde fuera del estado (los widgets no pueden
  /// llamar a [notifyListeners] porque es un miembro protegido).
  void refresh() => notifyListeners();

  void toggleSidebar() => setSidebarCollapsed(!sidebarCollapsed);

  Future<void> setSidebarCollapsed(bool value) async {
    if (sidebarCollapsed == value) return;
    sidebarCollapsed = value;
    await _settings.set('sidebarCollapsed', value);
    notifyListeners();
  }

  void setGrids({bool? azimuthal, bool? equatorial}) {
    if (azimuthal != null) isAzimuthalGrid = azimuthal;
    if (equatorial != null) isEquatorialGrid = equatorial;
    _settings.set('isAzimuthalGrid', isAzimuthalGrid);
    _settings.set('isEquatorialGrid', isEquatorialGrid);
    notifyListeners();
  }

  void setMagnitudeLimit(double value) {
    magMax = value;
    notifyListeners();
  }

  void toggleBelowHorizon() {
    showBelowHorizon = !showBelowHorizon;
    notifyListeners();
  }

  void setZoom(double value) {
    zoom3D = value;
    zoomFactor = value;
    if (zoom3D > 20) {
      magMax = 6 + (2 * (zoom3D / 150));
      rAdjust = 2 * (zoom3D / 150);
    } else if (magMax > 6) {
      magMax = 6;
      rAdjust = 0;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------ montura
  /// Puerto de MainService.goto(): mueve la montura al punto centrado.
  Future<void> goTo({double? ra, double? dec, bool isUser = false}) async {
    final raPoint = ra ?? touchedRA;
    final decPoint = dec ?? touchedDEC;

    final head = isUser
        ? '¿Desea aceptar esta petición?'
        : (isOnline
            ? '¿Desea solicitar ir al objeto centrado?'
            : '¿Desea ir al objeto centrado?');
    final message = isUser
        ? 'Un usuario quiere mover el dispositivo; al aceptar se moverá.'
        : (isOnline
            ? 'El administrador debe aceptar su solicitud para poder moverse.'
            : 'El dispositivo se moverá al punto centrado del cuadro.');

    if (!await Dialogs.confirm(head, message)) return;

    if (isOnline) {
      remote.send({
        'action': 'goto',
        'username': username,
        'RA': touchedRA,
        'DEC': touchedDEC,
      });
      return;
    }

    final posDEC = decPoint > 180 ? decPoint - 450 : decPoint - 90;
    final posRA = raPoint > 180 ? raPoint - 360 : raPoint;

    final decSteps = (200 * microsteps1 * drv1r) * (posDEC / 360);
    final raSteps = (200 * microsteps2 * drv2r) * (posRA / 360);

    final distDEC = (position1 - decSteps).abs();
    final distRA = (position2 - raSteps).abs();

    double speed;
    double accel;
    final double N;
    if (distDEC > distRA) {
      speed = speed1;
      accel = accel1;
      N = distDEC;
    } else {
      speed = speed2;
      accel = accel2;
      N = distRA;
    }

    final dAccel = speed * speed / (2 * accel);
    double T;
    if (N > 2 * dAccel && accel > 0 && speed > 0) {
      final tAccel = speed / accel;
      final dConst = N - 2 * dAccel;
      final tConst = dConst / speed;
      T = 2 * tAccel + tConst;
    } else {
      T = 2 * math.sqrt(accel > 0 ? N / accel : 0) + 1;
    }

    goToTime = T;
    goToTimeStr = T.toStringAsFixed(0).padLeft(2, '0');

    await sendToDevice('GOTO:$posDEC,$posRA');
  }

  /// Posición de origen de la montura.
  Future<void> goHome() async {
    if (await Dialogs.confirm(
      '¿Desea ir a la posición inicial?',
      'El dispositivo se moverá al punto de partida donde empezó.',
    )) {
      await sendToDevice('GOTO:0,0');
    }
  }

  /// Activa o desactiva el seguimiento sideral.
  Future<void> toggleTracking() async {
    final enable = !isTracking;
    if (await Dialogs.confirm(
      '¿Desea ${enable ? 'activar' : 'desactivar'} el modo seguimiento?',
      'El dispositivo se moverá a la velocidad de rotación de la tierra de forma constante.',
    )) {
      await sendToDevice('FLLW:$enable');
    }
    deviceDateCT = DateTime.now().millisecondsSinceEpoch;
  }

  // --------------------------------------------------------------- settings
  Future<void> setUsername(String value) async {
    username = value.trim().isEmpty ? 'Invitado' : value.trim();
    isNew = false;
    await _settings.set('username', username);
    await _settings.set('isNew', false);
    notifyListeners();
  }

  Future<void> resetSettings() async {
    await _settings.reset();
    await init();
  }

  Future<int> get baudRate => _settings.get<int>('baudRate');

  Future<void> setBaudRate(int value) async {
    await _settings.set('baudRate', value);
    notifyListeners();
  }
}
