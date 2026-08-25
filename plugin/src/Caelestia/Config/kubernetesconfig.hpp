#pragma once

#include <qstring.h>

#include "common.hpp"
#include "settings/objectnode.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

class KubernetesConfig : public settings::ObjectNode {
    CONFIG_NODE(KubernetesConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(int, updateInterval, 5000)
    CONFIG_PROPERTY(int, dragThreshold, 20)
    CONFIG_PROPERTY(bool, showOnHover, true)
    CONFIG_GLOBAL_PROPERTY(QString, terminal, u"kitty"_s)
    CONFIG_GLOBAL_PROPERTY(QString, defaultNamespace, u"default"_s)
};

} // namespace caelestia::config
