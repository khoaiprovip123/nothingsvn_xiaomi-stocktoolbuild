# CustomApps — user-supplied APKs
#
# Drop files here and the next build installs them into the ROM.
# Controlled by config.env: `install_custom_apps=true|false`.
#
# Layout:
#   *.apk                      → product/priv-app/<Name>/<Name>.apk
#   <AppName>/                 → product/priv-app/<AppName>/  (keep lib/, jars…)
#   overlay/*.apk              → product/overlay/
#   privapp_whitelist_*.xml    → product/etc/permissions/
#
# Example:
#   CustomApps/MyLauncher.apk
#   CustomApps/MyLauncher/          ← optional lib/ folder
#   CustomApps/privapp_whitelist_com.example.myapp.xml
