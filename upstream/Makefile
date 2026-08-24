include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-led-nightmode
PKG_VERSION:=0.5.0
PKG_RELEASE:=7
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=mv-go <rapture-ribose6k@icloud.com>

LUCI_TITLE:=LED night mode for OpenWrt
LUCI_DESCRIPTION:=Preserve and restore OpenWrt LED triggers while applying day and night profiles.
LUCI_DEPENDS:=+luci-base +jshn +procd +rpcd +sunwait +uci
LUCI_URL:=https://github.com/mv-go/luci-app-led-nightmode

define Package/luci-app-led-nightmode/conffiles
/etc/config/led-nightmode
endef

define Package/luci-app-led-nightmode/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	rm -f /tmp/luci-indexcache.*
	rm -rf /tmp/luci-modulecache/
	/etc/init.d/rpcd reload 2>/dev/null
}
exit 0
endef

define Build/Prepare/luci-app-led-nightmode
	chmod 0600 $(PKG_BUILD_DIR)/root/etc/config/led-nightmode
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/uci-defaults/99-led-nightmode
endef

include ../../luci.mk

# call BuildPackage - OpenWrt buildroot signature
