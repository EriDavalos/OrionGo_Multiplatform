# OrionGo Platform

Aplicación **Flutter** para controlar monturas Orion desde **Android** y desde
**computadora (Windows)**, migrada desde la app Ionic/Angular `OrionGo_Mobile`.

Conserva las mismas vistas de la app móvil, con un diseño adaptado a cada
tamaño de pantalla.

## Vistas

| Vista | Descripción |
| --- | --- |
| **Inicio** | Cielo estelar 3D interactivo (arrastre, pinza y rueda del ratón), reloj del cielo, retículas, magnitud límite, seguimiento y GoTo. |
| **Monturas** | Catálogo de monturas registradas, montura predeterminada y estado de conexión. |
| **Remoto** | Modo administrador y modo usuario mediante WebSocket (`oriongo.ddns.net:443`), con consola y lista de usuarios. |
| **Ajustes de motor** | Telemetría en vivo de los dos drivers (pasos, ángulo, micropasos, velocidad, aceleración, UART). |
| **Configuraciones** | Perfil, ubicación del observador, conexión e identificador de usuario. |
| **Emparejar montura** | Bluetooth en Android; puertos serie (incluye Bluetooth SPP) en computadora. |
| **Buscar objeto** | Búsqueda por nombre y tipo en el catálogo `assets/data/stars.json`. |
| **Ubicación** | Mapa OpenStreetMap para fijar la latitud/longitud del observador. |
| **Consolas** | Tramas enviadas/recibidas de la montura y actividad del servidor. |

## Diseño responsivo

- **Teléfono:** barra superior con menú deslizable y controles flotantes sobre
  el cielo, igual que `OrionGo_Mobile`.
- **Escritorio (≥ 1000 px):** barra lateral fija con las secciones y las
  herramientas, contenido centrado con ancho máximo, paneles/diálogos centrados
  en lugar de hojas inferiores y telemetría en rejilla.

## Cielo estelar

La matemática astronómica se migró tal cual desde la app móvil
(`lib/models/stars.dart`, `lib/core/astronomy.dart`): precesión J2000, hora
sideral local, conversión AR/DEC ↔ azimut/altitud y proyección en perspectiva.

La proyección 3D (`lib/painters/projection3d.dart`) se resuelve con
[`vector_math`](https://pub.dev/packages/vector_math): las rotaciones de azimut,
altitud y roll se componen en **una sola matriz** que se reutiliza para cada
punto. Sobre eso, `lib/painters/sky_painter.dart` dibuja el cielo con
`CustomPainter`.

Con esto el cielo completo (retículas, miles de estrellas, horizonte, terreno,
montura y observadores) se repinta cada cuadro en un solo lienzo. Para un campo
de estrellas es más rápido y más preciso que añadir un motor 3D pesado como
`three_dart` (puerto de three.js, hoy poco mantenido) o `flutter_gl`, que no
aportarían nada al dibujo vectorial que ya necesita el mapa.

## Conexión con la montura

Toda la app usa una única abstracción, `MountLink`
(`lib/services/mount_link.dart`), con dos implementaciones:

- **Android — `AndroidMountLink`:** Bluetooth serial clásico (SPP/RFCOMM) sobre
  un `MethodChannel` propio (`oriongo/mount_bt`) implementado en Kotlin
  (`android/app/src/main/kotlin/com/oriongo/platform/MountBluetoothPlugin.kt`).
  Usa el UUID SPP estándar y el mismo protocolo que la app móvil
  (`ORIONV1:`, `SNDD:`, `SPD:`, `ADCG:`, `GOTO:`, `FLLW:`).
- **Computadora — `SerialMountLink`:** puerto serie vía
  [`flutter_libserialport`](https://pub.dev/packages/flutter_libserialport).
  Los dispositivos Bluetooth emparejados en el sistema operativo aparecen como
  puertos serie (`COM5` en Windows, `/dev/rfcomm0` en Linux), así que la misma
  implementación cubre Bluetooth y USB.

La vista **Emparejar montura** cambia sola: en Android lista dispositivos
emparejados y descubiertos; en computadora lista los puertos serie del sistema.

## Cómo ejecutar

```bash
flutter pub get

# Android (necesita Android SDK + un teléfono o emulador)
flutter run -d <device-id>

# Windows (necesita Visual Studio con "Desktop development with C++")
flutter run -d windows

# Pruebas y análisis
flutter test
flutter analyze
```

### Requisitos en Windows

1. **Modo desarrollador activado** (`start ms-settings:developers`): los builds
   con plugins necesitan soporte de enlaces simbólicos.
2. **Carga de trabajo C++ de Visual Studio** para compilar la app de escritorio.
3. Android: instalar el **SDK de Android** (`flutter doctor` lo verifica).

> Nota del entorno: si `flutter` está instalado en `C:\Program Files\flutter`,
> el tool puede fallar al escribir su caché ("Flutter failed to open a file at
> ...\bin\cache\lockfile") porque esa carpeta requiere permisos de
> administrador. Ejecutar Flutter desde una instalación propia del usuario
> (por ejemplo `C:\flutter`) evita el problema.

## Estructura

```
lib/
├── app.dart                     Shell responsivo (barra lateral / drawer)
├── main.dart                    Arranque, estado y enlace con la montura
├── core/                        Tema, puntos de quiebre, utilidades astronómicas
├── models/                      Star, componentes sexagesimales, dispositivos
├── painters/                    Proyección 3D y pintor del cielo
├── pages/                       Una vista por sección
├── services/                    Estado global, ajustes, enlace montura, WebSocket
└── widgets/                     Paneles, menús, consola y superficie del cielo
```
