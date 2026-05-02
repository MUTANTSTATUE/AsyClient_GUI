cmake_minimum_required(VERSION 3.16)
project(AsyClient_GUI VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Find Qt
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network Multimedia)
find_package(Qt6 OPTIONAL_COMPONENTS Qt5Compat)
if(NOT Qt6_FOUND)
    find_package(Qt5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 GraphicalEffects Network Multimedia)
endif()

include_directories(include)

add_executable(AsyClient_GUI
    main.cpp
    ClientWrapper.cpp
    ClientWrapper.h
    qml.qrc
)

# Link the static library we copied
target_link_libraries(AsyClient_GUI
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/lib/libasyc_client.a
    Qt${Qt6_VERSION_MAJOR}::Core
    Qt${Qt6_VERSION_MAJOR}::Gui
    Qt${Qt6_VERSION_MAJOR}::Qml
    Qt${Qt6_VERSION_MAJOR}::Quick
    Qt${Qt6_VERSION_MAJOR}::QuickControls2
    Qt${Qt6_VERSION_MAJOR}::Network
    Qt${Qt6_VERSION_MAJOR}::Multimedia
    $<$<BOOL:${Qt6Compat5_FOUND}>:Qt6::Qt5Compat>
    pthread
)
