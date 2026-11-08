#pragma once

#include <string>
#include <vector>
#include <memory>

namespace Nova {

struct ApplicationItem {
    std::string id;
    std::string name;
    std::string category;
    std::string exec;
    std::string icon;
    std::vector<std::string> keywords;
};

class NovaLauncherWindow {
public:
    NovaLauncherWindow();
    ~NovaLauncherWindow() = default;

    std::vector<ApplicationItem> search(const std::string& query) const;
    std::vector<ApplicationItem> getByCategory(const std::string& category) const;
    const std::vector<ApplicationItem>& allApplications() const { return m_apps; }

    void launch(const std::string& appId) const;

private:
    void initApplications();
    std::vector<ApplicationItem> m_apps;
};

} // namespace Nova

