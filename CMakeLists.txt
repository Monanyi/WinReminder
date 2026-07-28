cmake_minimum_required(VERSION 3.21)

project(WinReminder VERSION 2.0.1 LANGUAGES CXX)

include(CTest)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.11 REQUIRED COMPONENTS
    Core
    Gui
    Network
    Qml
    Quick
    QuickControls2
    Widgets
)

qt_standard_project_setup(REQUIRES 6.8)

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/app.rc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/app.rc"
    @ONLY
)
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/app.manifest.in"
    "${CMAKE_CURRENT_BINARY_DIR}/app.manifest"
    @ONLY
)

qt_add_executable(WinReminder
    WIN32
    src/main.cpp
    src/ReminderManager.cpp
    src/ReminderManager.h
    "${CMAKE_CURRENT_BINARY_DIR}/app.rc"
)

qt_add_qml_module(WinReminder
    URI WinReminder
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/AlarmWindow.qml
        qml/DateInput.qml
        qml/TimeInput.qml
)

target_compile_definitions(WinReminder PRIVATE
    UNICODE
    _UNICODE
    WIN32_LEAN_AND_MEAN
    WINREMINDER_VERSION="${PROJECT_VERSION}"
)

target_link_libraries(WinReminder PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Widgets
    winmm
    advapi32
    shell32
)

if(BUILD_TESTING)
    find_package(Qt6 6.11 REQUIRED COMPONENTS Test)

    qt_add_executable(WinReminderTests
        tests/ReminderManagerTests.cpp
        src/ReminderManager.cpp
        src/ReminderManager.h
    )

    target_include_directories(WinReminderTests PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
    )

    target_compile_definitions(WinReminderTests PRIVATE
        UNICODE
        _UNICODE
        WIN32_LEAN_AND_MEAN
    )

    target_link_libraries(WinReminderTests PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Test
        Qt6::Widgets
        winmm
        advapi32
        shell32
    )

    add_test(NAME ReminderManagerTests COMMAND WinReminderTests)
    set_tests_properties(ReminderManagerTests PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
    )
endif()
