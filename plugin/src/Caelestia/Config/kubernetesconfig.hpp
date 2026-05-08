#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

class KubernetesConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(int, updateInterval, 5000)
    CONFIG_PROPERTY(int, dragThreshold, 20)
    CONFIG_PROPERTY(bool, showOnHover, true)
    CONFIG_GLOBAL_PROPERTY(QString, terminal, u"kitty"_s)
    CONFIG_GLOBAL_PROPERTY(QString, defaultNamespace, u"default"_s)

public:
    explicit KubernetesConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace caelestia::config
