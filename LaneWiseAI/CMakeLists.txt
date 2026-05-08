cmake_minimum_required(VERSION 3.16)

project(LaneWiseAI VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.10)

qt_add_executable(appLaneWiseAI
    main.cpp
    gradient_descent.hpp
    gradient_descent.cpp
    lanewisecontroller.hpp
    lanewisecontroller.cpp
)

qt_add_qml_module(appLaneWiseAI
    URI LaneWiseAI
    VERSION 1.0
    QML_FILES
        Main.qml
)

qt_add_resources(appLaneWiseAI lane_data
    PREFIX "/"
    FILES
        data/shipment_routes.csv
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appLaneWiseAI PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appLaneWiseAI
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appLaneWiseAI
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
)

install(TARGETS appLaneWiseAI
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
