cmake_minimum_required(VERSION 3.16)

project(automatic_parking_app VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appautomatic_parking_app
    main.cpp
)

qt_add_qml_module(appautomatic_parking_app
    URI automatic_parking_app
    VERSION 1.0
    QML_FILES
        Main.qml
        QML_FILES qml/EntryGate.qml
        QML_FILES qml/ExitGate.qml
        SOURCES src/cameramanager.h src/cameramanager.cpp
        SOURCES src/databasemanager.h src/databasemanager.cpp
        SOURCES src/cardreader.h src/cardreader.cpp
        SOURCES src/barriercontroller.h src/barriercontroller.cpp
        SOURCES src/ocrprocessor.h src/ocrprocessor.cpp
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appautomatic_parking_app PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appautomatic_parking_app
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appautomatic_parking_app
    PRIVATE Qt6::Quick
)

include(GNUInstallDirs)
install(TARGETS appautomatic_parking_app
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
