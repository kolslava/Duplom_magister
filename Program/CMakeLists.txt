# CMakeLists.txt
cmake_minimum_required(VERSION 3.14)

project(NAC_ADAPTIVE_CPP VERSION 1.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ## ЗМІНА ТУТ: Явно вказуємо, куди встановлювати виконувані файли ##
include(GNUInstallDirs)
set(CMAKE_INSTALL_BINDIR bin)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# --- Підключення локальних залежностей ---

# nlohmann/json (тільки заголовки)
add_library(json INTERFACE)
target_include_directories(json INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/external/json/include")

# cpr (потребує компіляції)
set(CPR_BUILD_TESTS OFF CACHE BOOL "")
set(CPR_GENERATE_COVERAGE OFF CACHE BOOL "")
add_subdirectory(external/cpr)

# -----------------------------------------

# Знаходимо всі наші вихідні файли (.cpp) в каталозі src
file(GLOB_RECURSE SOURCES "src/*.cpp")

# Створюємо виконуваний файл
add_executable(NAC_ADAPTIVE_CPP ${SOURCES})

# Вказуємо, де шукати наші та зовнішні заголовні файли
target_include_directories(NAC_ADAPTIVE_CPP PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

# Підключаємо (лінкуюємо) бібліотеки до нашого проєкту
target_link_libraries(NAC_ADAPTIVE_CPP PRIVATE
  json
  cpr::cpr
)