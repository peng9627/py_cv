cmake_minimum_required(VERSION 3.10)

# 1. 在 project 之前设置 vcpkg 静态标识
if(WIN32)
    set(VCPKG_TARGET_TRIPLET "x64-windows-static" CACHE STRING "")
endif()

project(wechat_scanner_project)

# 2. 设置 C++ 标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 3. 【跨平台可移植性关键】设置链接和 RPATH 策略
if(WIN32)
    # Windows: 强制使用静态运行库 (MT)，消除对 MSVCP140.dll 的依赖
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    set(OpenCV_STATIC ON)
elseif(APPLE)
    # 【修复】设置最低 macOS 部署版本，确保向后兼容性
    set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15" CACHE STRING "Minimum macOS version")
    set(CMAKE_MACOSX_RPATH 1)
    set(CMAKE_INSTALL_RPATH "@executable_path/")
elseif(UNIX AND NOT APPLE)
    # Linux: 设置 RPATH，让程序优先在自身目录下寻找 .so 库
    set(CMAKE_INSTALL_RPATH "$ORIGIN")
    set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
endif()

# 4. 寻找 OpenCV
find_package(OpenCV REQUIRED)

# 5. 添加可执行文件
add_executable(wechat_scanner wechat_scanner.cpp)

# 6. 包含头文件与链接库
target_include_directories(wechat_scanner PRIVATE ${OpenCV_INCLUDE_DIRS})
target_link_libraries(wechat_scanner PRIVATE ${OpenCV_LIBS})

# 7. 处理 Windows 编码
if(MSVC)
    target_compile_options(wechat_scanner PRIVATE /utf-8)
endif()

# 8. 自动拷贝模型文件夹
set(MODEL_DIR_NAME "models")
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${MODEL_DIR_NAME}")
    add_custom_command(TARGET wechat_scanner POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/${MODEL_DIR_NAME}"
            "$<TARGET_FILE_DIR:wechat_scanner>/${MODEL_DIR_NAME}"
            COMMENT "Copying ${MODEL_DIR_NAME} to output directory..."
    )
endif()

# 9. 打印调试信息
message(STATUS "--------------------------------------------")
message(STATUS "Build Platform: ${CMAKE_SYSTEM_NAME}")
message(STATUS "OpenCV version: ${OpenCV_VERSION}")
message(STATUS "OpenCV Static:  ${OpenCV_STATIC}")
message(STATUS "macOS Deployment Target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
message(STATUS "--------------------------------------------")
