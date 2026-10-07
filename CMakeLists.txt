cmake_minimum_required(VERSION 3.20)
project(wx_macos_tooltip_probe CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(wxWidgets REQUIRED COMPONENTS core base)
include(${wxWidgets_USE_FILE})

add_executable(probe main.cpp probe.mm)
target_link_libraries(probe PRIVATE ${wxWidgets_LIBRARIES} "-framework Cocoa")
