// Blocklist preferences
pref("extensions.blocklist.enabled", false);
pref("extensions.blocklist.interval", 0);
pref("extensions.blocklist.url", "");
pref("extensions.blocklist.detailsURL", "http://%LOCALE%.www.mozilla.com/%LOCALE%/blocklist/");

pref("app.update.enabled", false);
pref("app.update.auto", false);

// Defines how the Application Update Service notifies the user about updates:
//
// AUM Set to:        Minor Releases:     Major Releases:
// 0                  download no prompt  download no prompt
// 1                  download no prompt  download no prompt if no incompatibilities
// 2                  download no prompt  prompt
//
// See chart in nsUpdateService.js.in for more details
pref("app.update.mode", 2);
// If set to true, the Update Service will present no UI for any event.
pref("app.update.silent", false);

// Update service URL:
pref("app.update.url", "https://aus2.mozilla.org/update/2/%PRODUCT%/%VERSION%/%BUILD_ID%/%BUILD_TARGET%/%LOCALE%/%CHANNEL%/%OS_VERSION%/update.xml");

// Interval: Time between checks for a new version (in seconds)
//           default=1 day
pref("app.update.interval", 0);
// Interval: Time before prompting the user to download a new version that 
//           is available (in seconds) default=1 day
pref("app.update.nagTimer.download", 0);
// Interval: Time before prompting the user to restart to install the latest
//           download (in seconds) default=30 minutes
pref("app.update.nagTimer.restart", 0);
// Interval: When all registered timers should be checked (in milliseconds)
//           default=5 seconds
pref("app.update.timer", 0);

pref("extensions.update.enabled", false);
pref("browser.shell.checkDefaultBrowser", false);

// 0 = blank, 1 = home (browser.startup.homepage), 2 = last visited page, 3 = resume previous browser session
// The behavior of option 3 is detailed at: http://wiki.mozilla.org/Session_Restore
pref("browser.startup.page",                0);
pref("browser.startup.homepage",            "about:blank");
pref("browser.startup.homepage_override.mstone", "ignore");

pref("browser.cache.disk.capacity",         0);

// search engines URL
pref("browser.search.searchEnginesURL",      "");
// pointer to the default engine name
pref("browser.search.defaultenginename",      "chrome://browser-region/locale/region.properties");

// send ping to the server to update
pref("browser.search.update", false);

// disable search suggestions by default
pref("browser.search.suggest.enabled", false);

// handle external links
// 0=default window, 1=current window/tab, 2=new window, 3=new tab in most recent window
pref("browser.link.open_newwindow", 3);

// 3  at the end of the tabstrip
pref("browser.tabs.closeButtons", 3);

// Scripts & Windows prefs
pref("dom.disable_window_open_feature.location",  true);
pref("dom.disable_window_status_change",          true);
pref("dom.disable_window_move_resize",            true);
pref("dom.disable_window_flip",                   true);

// popups.policy 1=allow,2=reject
pref("privacy.popups.policy",               2);
pref("privacy.popups.usecustom",            true);
pref("privacy.popups.firstTime",            true);
pref("privacy.popups.showBrowserMessage",   true);
 
pref("privacy.item.history",    true);
pref("privacy.item.formdata",   true);
pref("privacy.item.passwords",  true);
pref("privacy.item.downloads",  true);
pref("privacy.item.cookies",    true);
pref("privacy.item.cache",      true);
pref("privacy.item.siteprefs",  true);
pref("privacy.item.sessions",   true);

pref("privacy.sanitize.sanitizeOnShutdown", true);
pref("privacy.sanitize.promptOnSanitize", false);

pref("network.cookie.enableForCurrentSessionOnly", true);

pref("accessibility.typeaheadfind", true);
pref("accessibility.typeaheadfind.timeout", 5000);
pref("accessibility.typeaheadfind.linksonly", false);
pref("accessibility.typeaheadfind.flashBar", 1);

pref("layout.spellcheckDefault", 0);

pref("browser.safebrowsing.enabled", false);
pref("browser.safebrowsing.remoteLookups", false);

// Tor stuff
pref("network.proxy.http", "localhost");
pref("network.proxy.http_port", 8118);
pref("network.proxy.socks", "localhost");
pref("network.proxy.socks_port", 9050);
pref("network.proxy.socks_remote_dns", true);
pref("network.proxy.ssl", "localhost");
pref("network.proxy.ssl_port", 8118);
pref("network.proxy.type", 1);

pref("extensions.torbutton.http_port", 8118);
pref("extensions.torbutton.http_proxy", "localhost");
pref("extensions.torbutton.https_port", 8118);
pref("extensions.torbutton.https_proxy", "localhost");
pref("extensions.torbutton.socks_host", "localhost");
pref("extensions.torbutton.socks_port", 9050);
pref("extensions.torbutton.cookie_jars", true);
pref("extensions.torbutton.clear_cookies", false);
