cmake_minimum_required(VERSION 3.21)

project(smart_parking_tests LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

enable_testing()

find_package(Qt6 6.8 REQUIRED COMPONENTS
    Core
    Concurrent
    Gui
    Multimedia
    SerialPort
    Sql
    Test
)

qt_add_executable(smart_parking_tests
    test_core_workflow.cpp
    ../controller/parkingcontroller.h
    ../controller/parkingcontroller.cpp
    ../domain/ports/icardreader.h
    ../security/authmanager.h
    ../security/authmanager.cpp
    ../utils/db/databasemanager.h
    ../utils/db/databasemanager.cpp
    ../utils/db/paymentutils.h
    ../utils/db/paymentutils.cpp
    ../utils/io_barrier/usbrelaybarrier.h
    ../utils/io_barrier/usbrelaybarrier.cpp
)

target_include_directories(smart_parking_tests PRIVATE ..)

target_link_libraries(smart_parking_tests PRIVATE
    Qt6::Core
    Qt6::Concurrent
    Qt6::Gui
    Qt6::Multimedia
    Qt6::SerialPort
    Qt6::Sql
    Qt6::Test
)

add_test(NAME smart_parking_tests COMMAND smart_parking_tests)
