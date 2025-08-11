cmake_minimum_required(VERSION 3.16)

project(automatic_parking_app VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)

find_package(Qt6 REQUIRED COMPONENTS Quick Qml Sql Multimedia)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appautomatic_parking_app
    src/main.cpp
)

qt_add_qml_module(appautomatic_parking_app
    URI automatic_parking_app
    VERSION 1.0
    QML_FILES
        src/qml/MainWindow.qml
        src/qml/MainWindowForm.ui.qml

    SOURCES
        utils/camera/cameramanager.h utils/camera/cameramanager.cpp
        utils/db/databasemanager.h utils/db/databasemanager.cpp
        utils/io_card/cardreader.h utils/io_card/cardreader.cpp
        utils/io_barrier/barriercontroller.h utils/io_barrier/barriercontroller.cpp
        utils/ocr/ocrprocessor.h utils/ocr/ocrprocessor.cpp
        controller/parkingcontroller.h controller/parkingcontroller.cpp
    domain/ports/icardreader.h
    domain/model/parkingrecord.h
)

# Ensure we can include headers via paths like "domain/ports/..."
target_include_directories(appautomatic_parking_app PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

set_target_properties(appautomatic_parking_app PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appautomatic_parking_app
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appautomatic_parking_app
    PRIVATE Qt6::Sql Qt6::Qml Qt6::Quick Qt6::Multimedia
)

include(GNUInstallDirs)
install(TARGETS appautomatic_parking_app
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
