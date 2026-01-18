pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var iconCache: ({})
    
    function getCachedIcon(str) {
        if (!str) return "image-missing";
        if (iconCache[str]) return iconCache[str];
        
        const result = guessIcon(str);
        iconCache[str] = result;
        return result;
    }

    function iconExists(iconName) {
        return (Quickshell.iconPath(iconName, true).length > 0) 
            && !iconName.includes("image-missing");
    }

    // Validate icon and return fallback if needed
    function validateIcon(iconName) {
        if (!iconName || iconName.length === 0) {
            return "image-missing";
        }
        
        // If it's an absolute path, check if file exists
        if (iconName.startsWith("/")) {
            const resolvedPath = Quickshell.iconPath(iconName, true);
            if (resolvedPath.length === 0) {
                return "image-missing";
            }
            return iconName;
        }
        
        // For icon names (not paths), check if they exist in the theme
        if (iconExists(iconName)) {
            return iconName;
        }
        
        return "image-missing";
    }

    function getIconFromDesktopEntry(className) {
        if (!className || className.length === 0) return null;

        const normalizedClassName = className.toLowerCase();

        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            if (app.command && app.command.length > 0) {
                const executableLower = app.command[0].toLowerCase();
                if (executableLower === normalizedClassName) {
                    return app.icon || "application-x-executable";
                }
            }
            if (app.name && app.name.toLowerCase() === normalizedClassName) {
                return app.icon || "application-x-executable";
            }
            if (app.keywords && app.keywords.length > 0) {
                for (let j = 0; j < app.keywords.length; j++) {
                    if (app.keywords[j].toLowerCase() === normalizedClassName) {
                        return app.icon || "application-x-executable";
                    }
                }
            }
        }
        return null;
    }

    function guessIcon(str) {
        if (!str || str.length == 0) return "image-missing";

        const desktopIcon = getIconFromDesktopEntry(str);
        if (desktopIcon) return desktopIcon;

        if (substitutions[str])
            return substitutions[str];

        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            const replacedName = str.replace(
                substitution.regex,
                substitution.replace,
            );
            if (replacedName != str) return replacedName;
        }

        if (iconExists(str)) return str;

        const extensionGuess = str.split('.').pop().toLowerCase();
        if (iconExists(extensionGuess)) return extensionGuess;

        const dashedGuess = str.toLowerCase().replace(/\s+/g, "-");
        if (iconExists(dashedGuess)) return dashedGuess;

        return str;
    }

    property var substitutions: ({
        "code-url-handler": "visual-studio-code",
        "Code": "visual-studio-code",
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "footclient": "foot",
        "zen": "zen-browser",
        "vivaldi": "vivaldi-snapshot",
        "brave": "brave-browser"
    })
    
    property list<var> regexSubstitutions: [
        {
            "regex": /^steam_app_(\d+)$/,
            "replace": "steam_icon_$1"
        },
        {
            "regex": /Minecraft.*/,
            "replace": "minecraft"
        },
        {
            "regex": /.*polkit.*/,
            "replace": "system-lock-screen"
        }
    ]

    readonly property list<DesktopEntry> list: Array.from(DesktopEntries.applications.values)
        .sort((a, b) => a.name.localeCompare(b.name))
    
    // Index structure for fast searching
    property var searchIndex: []
    
    function buildIndex() {
        const newIndex = [];
        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            newIndex.push({
                name: app.name.toLowerCase(),
                command: (app.command && app.command.length > 0) ? app.command.join(' ').toLowerCase() : "",
                executable: (app.command && app.command.length > 0) ? app.command[0].toLowerCase() : "",
                comment: (app.comment || "").toLowerCase(),
                genericName: (app.genericName || "").toLowerCase(),
                keywords: (app.keywords || []).map(k => k.toLowerCase()),
                original: app
            });
        }
        searchIndex = newIndex;
    }
    
    property var allAppsCache: null

    function invalidateCache() {
        allAppsCache = null;
    }

    onListChanged: {
        allAppsCache = null;
        buildIndex();
    }
    
    Component.onCompleted: {
        buildIndex();
    }
    
    function getAllApps() {
        if (allAppsCache) return allAppsCache;

        const results = [];
        
        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            
            let iconToUse = app.icon || "application-x-executable";
            if (iconCache[iconToUse]) {
                iconToUse = iconCache[iconToUse];
            } else {
                let validated = validateIcon(iconToUse);
                iconCache[iconToUse] = validated;
                iconToUse = validated;
            }

            results.push({
                name: app.name,
                icon: iconToUse,
                id: app.id,
                execString: app.execString,
                comment: app.comment || "",
                categories: app.categories || [],
                runInTerminal: app.runInTerminal || false,
                execute: () => {
                    app.execute();
                }
            });
        }
        
        // Sort alphabetically
        results.sort((a, b) => {
            return a.name.localeCompare(b.name);
        });
        
        allAppsCache = results;
        return results;
    }
    
    function fuzzyQuery(search) {
        if (!search || search.length === 0) return [];
        
        const searchLower = search.toLowerCase();
        const results = [];
        
        // Ensure index exists
        if (searchIndex.length === 0 && list.length > 0) buildIndex();
        
        for (let i = 0; i < searchIndex.length; i++) {
            const entry = searchIndex[i];
            let score = 0;
            let matchFound = false;
            
            // Search in name (highest priority)
            if (entry.name === searchLower) {
                score += 100; // Exact name match
                matchFound = true;
            } else if (entry.name.startsWith(searchLower)) {
                score += 80; // Name starts with search
                matchFound = true;
            } else if (entry.name.includes(searchLower)) {
                score += 60; // Name contains search
                matchFound = true;
            }
            
            // Search in executable
            if (entry.executable.includes(searchLower)) {
                score += 40;
                matchFound = true;
            }
            
            // Search in comment
            if (entry.comment.includes(searchLower)) {
                score += 30;
                matchFound = true;
            }
            
            // Search in generic name
            if (entry.genericName.includes(searchLower)) {
                score += 35;
                matchFound = true;
            }
            
            // Search in keywords
            for (let j = 0; j < entry.keywords.length; j++) {
                if (entry.keywords[j].includes(searchLower)) {
                    score += 25;
                    matchFound = true;
                    break;
                }
            }
            
            if (matchFound) {
                const app = entry.original;
                let iconToUse = app.icon || "application-x-executable";
                if (iconCache[iconToUse]) {
                    iconToUse = iconCache[iconToUse];
                } else {
                    let validated = validateIcon(iconToUse);
                    iconCache[iconToUse] = validated;
                    iconToUse = validated;
                }
                
                results.push({
                    name: app.name,
                    icon: iconToUse,
                    id: app.id,
                    execString: app.execString,
                    comment: app.comment || "",
                    categories: app.categories || [],
                    runInTerminal: app.runInTerminal || false,
                    score: score,
                    execute: () => {
                        app.execute();
                    }
                });
            }
        }
        
        // Sort by score (highest first), then alphabetically
        results.sort((a, b) => {
            if (a.score !== b.score) {
                return b.score - a.score;
            }
            return a.name.localeCompare(b.name);
        });
        
        return results;
    }
}
