# Automatic Parking App

Windows desktop software for a two-lane automatic parking facility. The application combines camera streams, RFID readers, license-plate OCR, USB relay barriers, pricing, subscriptions, and revenue reporting in a Qt/QML interface.

## Main features

- Two configurable entrance/exit lanes
- GStreamer camera streaming and snapshots
- ONNX license-plate detection with Tesseract OCR
- HID keyboard-style RFID readers
- Serial USB relay barrier control
- SQLite parking sessions, users, cards, pricing, and subscriptions
- Checkout payments and revenue summaries
- Vietnamese QML administration interface

## Requirements

- Windows 10 or later, x64
- Visual Studio 2022 with the Desktop C++ workload
- CMake 3.21 or later
- Qt 6.8 with Quick, QML, SQL, Multimedia, SerialPort, Charts, Widgets, Concurrent, and Quick Controls 2
- GStreamer MSVC x64 runtime and development packages

ONNX Runtime and Tesseract development files are currently included under `lib/`.

## Build

The default GStreamer location is `C:\Program Files\gstreamer\1.0\msvc_x86_64`. Override it with `-DGSTREAMER_ROOT=...` when necessary.

```powershell
cmake -S . -B build -G "Visual Studio 17 2022" -A x64 `
  -DCMAKE_PREFIX_PATH=C:\Qt\6.8.3\msvc2022_64 `
  -DGSTREAMER_ROOT="C:\Program Files\gstreamer\1.0\msvc_x86_64"
cmake --build build --config Release --parallel
```

## Administrator configuration

Credentials are verified in C++ and are not embedded in QML. Set `SMART_PARKING_ADMIN_USERNAME` and `SMART_PARKING_ADMIN_PASSWORD_SHA256` before launching the application. See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for a PowerShell setup example.

If the hash is not configured, administrator login remains disabled.

## Demo data

Normal startup does not insert sample financial records. To populate a new database explicitly:

```powershell
.\appsmart_parking_system.exe --seed-demo-data
```

## Tests

The test target does not require cameras, RFID hardware, barriers, GStreamer, ONNX Runtime, or Tesseract. It uses fake cameras/readers/barriers and a temporary SQLite database.

```powershell
cmake -S tests -B build-tests -DCMAKE_PREFIX_PATH=C:\Qt\6.8.3\msvc2022_64
cmake --build build-tests --config Release --parallel
ctest --test-dir build-tests --build-config Release --output-on-failure
```

GitHub Actions runs the same suite for pushes and pull requests targeting `finale`.

## Repository layout

- `controller/`: application workflow coordination
- `domain/ports/`: hardware and persistence abstractions
- `security/`: administrator credential verification
- `utils/`: camera, database, OCR, RFID, and barrier adapters
- `src/qml/`: user interface and QML logic
- `tests/`: hardware-free automated tests

## License

This project is available under the MIT License. See [LICENSE](LICENSE).
