// include/Application.hpp

#pragma once

#include <string>
#include <memory>

class DeviceRegistry;

class Application {
public:
    Application();
    ~Application();
    void run();

private:
    void tailSuricataLog();
    void processSuricataEvent(const std::string& line);
    void updateRegistryFromFleet();

    // Прибираємо члени класу для конфігурації
    std::unique_ptr<DeviceRegistry> m_deviceRegistry;
};