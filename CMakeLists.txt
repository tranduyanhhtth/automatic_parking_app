cmake_minimum_required(VERSION 3.16)

project(smart_parking_system VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Qml Sql Multimedia SerialPort Network)

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

    RESOURCES
        src/assets/logo_icon.jpg

    SOURCES
        utils/camera/cameramanager.h utils/camera/cameramanager.cpp
        utils/db/databasemanager.h utils/db/databasemanager.cpp
        utils/config/settings.h utils/config/settings.cpp
        utils/io_card/hidkeyboardcardreader.h utils/io_card/hidkeyboardcardreader.cpp
        utils/io_barrier/usbrelaybarrier.h utils/io_barrier/usbrelaybarrier.cpp
        utils/ocr/ocrprocessor.h utils/ocr/ocrprocessor.cpp
        utils/ocr/yolo_onnx_detector.h utils/ocr/yolo_onnx_detector.cpp
        controller/parkingcontroller.h controller/parkingcontroller.cpp
        domain/ports/icardreader.h
        domain/model/parkingrecord.h
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
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.smart_parking_system
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appsmart_parking_system
    PRIVATE Qt6::Sql Qt6::Qml Qt6::Quick Qt6::Multimedia Qt6::SerialPort Qt6::Network
    PRIVATE onnxruntime
)

# Windows: link D3D11/DXGI for GPU availability detection
if (WIN32)
    target_link_libraries(appsmart_parking_system PRIVATE d3d11 dxgi)
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
