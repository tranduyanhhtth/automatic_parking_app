cmake_minimum_required(VERSION 3.16)

project(smart_parking_system VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Windows-only project guard
if (NOT WIN32)
    message(FATAL_ERROR "Windows only.")
endif()

find_package(Qt6 REQUIRED COMPONENTS Quick Qml Sql Multimedia SerialPort Network QuickControls2)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appsmart_parking_system
    src/main.cpp
)

qt_add_qml_module(appsmart_parking_system
    URI smart_parking_system
    VERSION 1.0
    QML_FILES
        src/qml/MainWindow.qml
        src/qml/MainWindowForm.ui.qml
        # Components
        src/qml/components/LaneComponent.ui.qml
        src/qml/components/ToastComponent.ui.qml
        src/qml/components/HidLogPanel.ui.qml
        src/qml/components/NavDrawer.ui.qml
        # Dialogs
        src/qml/dialogs/AdminDialog.ui.qml
        src/qml/dialogs/CameraSettingsDialog.ui.qml
        src/qml/dialogs/BarrierSettingsDialog.ui.qml
        src/qml/dialogs/SearchDialog.ui.qml
        src/qml/dialogs/LoginDialog.ui.qml
        src/qml/dialogs/SessionDetailDialog.ui.qml
        # Pages
        src/qml/pages/SearchPage.ui.qml
        src/qml/pages/AdminPage.ui.qml
        # Logic helpers
        src/qml/logic/CameraLogic.qml
        src/qml/logic/BarrierLogic.qml
        src/qml/logic/PricingLogic.qml
        src/qml/logic/SearchLogic.qml
        src/qml/logic/HidLogLogic.qml
        src/qml/logic/AdminLoginLogic.qml

    SOURCES
        utils/camera/cameramanager.h utils/camera/cameramanager.cpp
        utils/gstreamer/gstreamerplayer.h utils/gstreamer/gstreamerplayer.cpp
        utils/gstreamer/videoframeproducer.h
        utils/db/databasemanager.h utils/db/databasemanager.cpp
        utils/config/settings.h utils/config/settings.cpp
        utils/io_card/windows_rawinput_router.h utils/io_card/windows_rawinput_router.cpp
        utils/io_card/hidkeyboardcardreader_device.h utils/io_card/hidkeyboardcardreader_device.cpp
        utils/io_barrier/usbrelaybarrier.h utils/io_barrier/usbrelaybarrier.cpp
        utils/ocr/ocrprocessor.h utils/ocr/ocrprocessor.cpp
        utils/ocr/tesseract_ocr.h utils/ocr/tesseract_ocr.cpp
        utils/ocr/yolo_onnx_detector.h utils/ocr/yolo_onnx_detector.cpp
        controller/parkingcontroller.h controller/parkingcontroller.cpp
        domain/ports/icardreader.h
        domain/model/parkingrecord.h
)

# Include QML and other resources from qrc files (AUTORCC is enabled for the target)
target_sources(appsmart_parking_system PRIVATE
    src/assets/assets.qrc
)

# Ensure Qt MOC/UIC/RCC are enabled for this target
set_target_properties(appsmart_parking_system PROPERTIES
    AUTOMOC ON
    AUTOUIC ON
    AUTORCC ON
)

### --- ONNX Runtime --- ###
set(ONNXRUNTIME_DIR "${CMAKE_CURRENT_SOURCE_DIR}/lib/onnxruntime-win-x64-1.22.0")

# Định nghĩa macro để bật ONNX runtime trong mã nguồn
target_compile_definitions(appsmart_parking_system PRIVATE HAVE_ONNXRUNTIME)

target_include_directories(appsmart_parking_system PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${ONNXRUNTIME_DIR}/include
)

target_link_directories(appsmart_parking_system PRIVATE
    ${ONNXRUNTIME_DIR}/lib
)

set_target_properties(appsmart_parking_system PROPERTIES
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appsmart_parking_system
    PRIVATE Qt6::Sql Qt6::Qml Qt6::Quick Qt6::Multimedia Qt6::SerialPort Qt6::Network Qt6::QuickControls2
    PRIVATE onnxruntime
)

# Tích hợp Tesseract OCR (dùng vcpkg + MSVC x64)
option(ENABLE_TESSERACT "Bật Tesseract OCR" ON)
if (ENABLE_TESSERACT)
    set(HAVE_TESSERACT ON)
    target_compile_definitions(appsmart_parking_system PRIVATE HAVE_TESSERACT)
    # Liên kết thư mục vendor lib/tesseract trong source
    set(TESSERACT_VENDOR_DIR "${CMAKE_SOURCE_DIR}/lib/tesseract")
    # Chọn đúng biến thể theo cấu hình: Debug dùng hậu tố 'd', Release không
    set(TESSERACT_VENDOR_TESSERACT_LIB_DEBUG "tesseract55d")
    set(TESSERACT_VENDOR_TESSERACT_LIB_RELEASE "tesseract55")
    set(TESSERACT_VENDOR_LEPTONICA_LIB_DEBUG "leptonica-1.85.0d")
    set(TESSERACT_VENDOR_LEPTONICA_LIB_RELEASE "leptonica-1.85.0")
    if (EXISTS "${TESSERACT_VENDOR_DIR}/include" AND EXISTS "${TESSERACT_VENDOR_DIR}/lib")
        message(STATUS "Liên kết Tesseract từ vendor: ${TESSERACT_VENDOR_DIR}")
        target_include_directories(appsmart_parking_system PRIVATE
            "${TESSERACT_VENDOR_DIR}/include"
            "${TESSERACT_VENDOR_DIR}/include/tesseract"
            "${TESSERACT_VENDOR_DIR}/include/leptonica"
        )
        # Ưu tiên lib theo cấu hình: nếu có thư mục debug/lib thì dùng cho Debug, ngược lại fallback lib/
        target_link_directories(appsmart_parking_system PRIVATE
            "$<IF:$<CONFIG:Debug>,${TESSERACT_VENDOR_DIR}/debug/lib,${TESSERACT_VENDOR_DIR}/lib>"
            "${TESSERACT_VENDOR_DIR}/lib"
        )
        target_link_libraries(appsmart_parking_system PRIVATE
            $<$<CONFIG:Debug>:${TESSERACT_VENDOR_TESSERACT_LIB_DEBUG};${TESSERACT_VENDOR_LEPTONICA_LIB_DEBUG}>
            $<$<NOT:$<CONFIG:Debug>>:${TESSERACT_VENDOR_TESSERACT_LIB_RELEASE};${TESSERACT_VENDOR_LEPTONICA_LIB_RELEASE}>
        )
    else()
        message(FATAL_ERROR "Không tìm thấy vendor Tesseract tại ${TESSERACT_VENDOR_DIR}. Vui lòng đặt include/ và lib/ đúng vị trí.")
    endif()
endif()

if (WIN32 AND ENABLE_TESSERACT)
    # Sao chép DLL Tesseract theo cấu hình (tránh trộn Debug/Release -> gây bug)
    set(TESSERACT_VENDOR_DIR "${CMAKE_SOURCE_DIR}/lib/tesseract")
    add_custom_command(TARGET appsmart_parking_system POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "$<IF:$<CONFIG:Debug>,${TESSERACT_VENDOR_DIR}/debug/bin,${TESSERACT_VENDOR_DIR}/bin>"
        "$<TARGET_FILE_DIR:appsmart_parking_system>"
    COMMENT "Copy vendor tesseract DLLs for $<CONFIG> to output")
endif()

# Link GStreamer từ vendor (Windows only) — hỗ trợ cả 2 layout:
# 1) lib/gstreamer/{include,lib,bin}
# 2) lib/gstreamer/1.0/msvc_x86_64/{include,lib,bin}
set(_GSTREAMER_BASE "${CMAKE_SOURCE_DIR}/lib/gstreamer")
set(GSTREAMER_VENDOR_DIR "")

if (EXISTS "${_GSTREAMER_BASE}/include/gstreamer-1.0" AND EXISTS "${_GSTREAMER_BASE}/lib")
    # Flat layout
    set(GSTREAMER_VENDOR_DIR "${_GSTREAMER_BASE}")
elseif (EXISTS "${_GSTREAMER_BASE}/1.0/msvc_x86_64/include/gstreamer-1.0" AND EXISTS "${_GSTREAMER_BASE}/1.0/msvc_x86_64/lib")
    # Nested layout from official MSVC bundles
    set(GSTREAMER_VENDOR_DIR "${_GSTREAMER_BASE}/1.0/msvc_x86_64")
endif()

if (GSTREAMER_VENDOR_DIR STREQUAL "")
    message(FATAL_ERROR "Không tìm thấy GStreamer vendor.\n  Đã thử: ${_GSTREAMER_BASE} và ${_GSTREAMER_BASE}/1.0/msvc_x86_64.\nHãy đặt include/, lib/ và (bin/ hoặc debug/bin) đúng cấu trúc.")
endif()

message(STATUS "Linking vendored GStreamer from ${GSTREAMER_VENDOR_DIR}")
target_include_directories(appsmart_parking_system PRIVATE
    "${GSTREAMER_VENDOR_DIR}/include/gstreamer-1.0"
    "${GSTREAMER_VENDOR_DIR}/include"
    "${GSTREAMER_VENDOR_DIR}/include/glib-2.0"
    "${GSTREAMER_VENDOR_DIR}/lib/glib-2.0/include"
)
target_link_directories(appsmart_parking_system PRIVATE "${GSTREAMER_VENDOR_DIR}/lib")
target_link_libraries(appsmart_parking_system PRIVATE
    gstapp-1.0
    gstvideo-1.0
    gstbase-1.0
    gstreamer-1.0
    gobject-2.0
    glib-2.0
    intl
)

# Copy GStreamer runtime DLLs to the output. Prefer debug/bin when present; otherwise use bin.
if (EXISTS "${GSTREAMER_VENDOR_DIR}/debug/bin")
    add_custom_command(TARGET appsmart_parking_system POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${GSTREAMER_VENDOR_DIR}/debug/bin" "$<TARGET_FILE_DIR:appsmart_parking_system>"
        COMMENT "Copy vendored GStreamer debug/bin to output")
endif()
if (EXISTS "${GSTREAMER_VENDOR_DIR}/bin")
    add_custom_command(TARGET appsmart_parking_system POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${GSTREAMER_VENDOR_DIR}/bin" "$<TARGET_FILE_DIR:appsmart_parking_system>"
        COMMENT "Copy vendored GStreamer bin to output")
endif()

# Windows: link D3D11/DXGI for GPU availability detection and user32 for Raw Input
if (WIN32)
    target_link_libraries(appsmart_parking_system PRIVATE d3d11 dxgi user32)
endif()

# Sao chép ONNX Runtime DLL vào thư mục build
set(ONNXRUNTIME_DLL "${ONNXRUNTIME_DIR}/lib/onnxruntime.dll")
if (EXISTS ${ONNXRUNTIME_DLL})
    add_custom_command(TARGET appsmart_parking_system POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${ONNXRUNTIME_DLL}" "$<TARGET_FILE_DIR:appsmart_parking_system>"
        COMMENT "Copying onnxruntime.dll to output directory")
else()
    message(WARNING "onnxruntime.dll not found at ${ONNXRUNTIME_DLL}. Ensure the correct ONNX Runtime package is present.")
endif()

# Sao chép mô hình ONNX vào thư mục build
set(LP_MODEL "${CMAKE_CURRENT_SOURCE_DIR}/model/license_plate_detector.onnx")
if (EXISTS ${LP_MODEL})
    add_custom_command(TARGET appsmart_parking_system POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${LP_MODEL}" "$<TARGET_FILE_DIR:appsmart_parking_system>"
        COMMENT "Copying license_plate_detector.onnx to output directory")
endif()

include(GNUInstallDirs)
install(TARGETS appsmart_parking_system
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
