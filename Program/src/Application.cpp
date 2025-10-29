// src/Application.cpp

#include "Application.hpp"
#include "nlohmann/json.hpp"
#include <cpr/cpr.h>

#include <iostream>
#include <fstream>
#include <string>
#include <unordered_map>
#include <vector>
#include <chrono>
#include <thread>
#include <memory>

using json = nlohmann::json;

// --- Моделі даних та Реєстр ---
struct HostInfo {
    std::string id;
    std::string hostname;
    std::string os_version;
    std::vector<std::string> ip_addresses;
};

class DeviceRegistry {
public:
    void updateHost(const HostInfo& host) {
        for (const auto& ip : host.ip_addresses) {
            if (!ip.empty()) {
                m_ip_to_host[ip] = std::make_shared<HostInfo>(host);
            }
        }
    }
    std::shared_ptr<HostInfo> findHostByIp(const std::string& ip) {
        auto it = m_ip_to_host.find(ip);
        return (it != m_ip_to_host.end()) ? it->second : nullptr;
    }
private:
    std::unordered_map<std::string, std::shared_ptr<HostInfo>> m_ip_to_host;
};

// --- Реалізація методів класу Application ---

Application::Application() {
    m_deviceRegistry = std::make_unique<DeviceRegistry>();
    std::cout << "Application initialized." << std::endl;
}

Application::~Application() = default;

void Application::run() {
    std::cout << "C++ Orchestrator starting..." << std::endl;
    updateRegistryFromFleet();
    tailSuricataLog();
}

void Application::updateRegistryFromFleet() {
    std::cout << "\n--- Updating device registry from Fleet API ---" << std::endl;

    std::string apiUrl = "https://fleet:8080";
    std::string apiToken = "L5M+Xve9qlQV+oW4ea7PTLGGaLHoaZkr8vwGQTwhvtn2yXigdAQmdNgkZ1SY+NtVI5WxVGyvVJmcWsY09sjsbw=="; // !! ВСТАВТЕ СВІЙ ТОКЕН СЮДИ !!

    if (apiToken.empty() || apiToken == "ВАШ_ДОВГИЙ_API_ТОКЕН_З_FLEET_UI") {
        std::cerr << "Warning: FLEET_API_TOKEN is not set in the code. Skipping Fleet update." << std::endl;
        std::cout << "-------------------------------------------\n" << std::endl;
        return;
    }

    // ## ЗМІНА ТУТ: Повністю змінюємо налаштування SSL ##
    cpr::SslOptions sslOpts = cpr::Ssl(
        // Вказуємо шлях до нашого сертифіката як довіреного
        cpr::ssl::CaInfo{"/etc/ssl/certs/fleet_server.crt"},
        // Вимикаємо перевірку імені хоста (fleet != localhost)
        cpr::ssl::VerifyHost{false}
    );

    cpr::Response r = cpr::Get(
        cpr::Url{apiUrl + "/api/v1/fleet/hosts"},
        cpr::Bearer{apiToken},
        sslOpts, // Передаємо наші нові SSL-налаштування
        cpr::Proxies{}
    );

    if (r.error) {
        std::cerr << "CPR Error: " << r.error.message << " (Code: " << static_cast<int>(r.error.code) << ")" << std::endl;
    }
    
    std::cout << "Fleet API Status Code: " << r.status_code << std::endl;
    
    if (r.status_code == 200) {
        try {
            json j = json::parse(r.text);
            if (j.contains("hosts")) {
                if (j["hosts"].empty()) {
                    std::cout << "No hosts found in Fleet." << std::endl;
                }
                for (const auto& host_json : j["hosts"]) {
                    HostInfo host;
                    host.id = std::to_string(host_json.value("id", 0));
                    host.hostname = host_json.value("hostname", "N/A");
                    host.os_version = host_json.value("os_version", "N/A");
                    host.ip_addresses.push_back(host_json.value("primary_ip", ""));
                    m_deviceRegistry->updateHost(host);
                }
                std::cout << "Registry updated successfully." << std::endl;
            }
        } catch (json::parse_error& e) {
            std::cerr << "Failed to parse Fleet response: " << e.what() << std::endl;
        }
    } else {
        std::cerr << "Error from Fleet API. Response: " << r.text << std::endl;
    }
    std::cout << "-------------------------------------------\n" << std::endl;
}

void Application::processSuricataEvent(const std::string& line) {
    try {
        json j = json::parse(line);
        if (j.contains("event_type") && j["event_type"] == "flow") {
            std::string src_ip = j.value("src_ip", "");
            std::string dest_ip = j.value("dest_ip", "");
            std::cout << "--- New Flow Event ---" << std::endl;
            auto src_host = m_deviceRegistry->findHostByIp(src_ip);
            std::cout << "Source: " << src_ip << " (" << (src_host ? src_host->hostname : "Unknown") << ")" << std::endl;
            auto dest_host = m_deviceRegistry->findHostByIp(dest_ip);
            std::cout << "Destination: " << dest_ip << " (" << (dest_host ? dest_host->hostname : "Unknown") << ")" << std::endl;
            std::cout << std::endl;
        }
    } catch (json::parse_error& e) { /* Ignore */ }
}

void Application::tailSuricataLog() {
    std::string logPath = "/var/log/suricata/eve.json";
    std::cout << "Tailing Suricata log file at " << logPath << "..." << std::endl;
    
    std::ifstream log_file;
    while (true) {
        if (!log_file.is_open()) {
            log_file.open(logPath);
            if (!log_file.is_open()) {
                std::cerr << "Waiting for Suricata log file..." << std::endl;
                std::this_thread::sleep_for(std::chrono::seconds(5));
                continue;
            }
            std::cout << "Suricata log file opened successfully." << std::endl;
            log_file.seekg(0, std::ios::end);
        }

        std::string line;
        if (std::getline(log_file, line)) {
            if (!line.empty()) {
                processSuricataEvent(line);
            }
        } else {
            if (log_file.eof()) {
                log_file.clear();
            } else if (log_file.fail() || log_file.bad()) {
                std::cerr << "Error reading log file. Re-opening..." << std::endl;
                log_file.close();
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
        }
    }
} 