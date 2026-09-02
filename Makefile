include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-led-nightmode
PKG_VERSION:=0.5.1
PKG_RELEASE:=1
PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE
LUCI_NAME:=luci-app-led-nightmode
LUCI_TITLE:=LED night mode for OpenWrt
LUCI_DESCRIPTION:=Preserve and restore OpenWrt LED triggers while applying day and night profiles.
LUCI_DEPENDS:=+luci-base +led-nightmode
LUCI_PKGARCH:=all
LUCI_MAINTAINER:=Mv Go <rapture-ribose6k@icloud.com>
LUCI_URL:=https://github.com/mv-go/luci-app-led-nightmode

define Package/led-nightmode
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=LED night mode runtime for OpenWrt
  DEPENDS:=+jshn +procd +rpcd +sunwait +uci
  PKGARCH:=all
  MAINTAINER:=Mv Go <rapture-ribose6k@icloud.com>
  URL:=https://github.com/mv-go/luci-app-led-nightmode
endef

define Package/led-nightmode/description
  Discovers Linux LED class devices at runtime, preserves their original
  triggers and brightness, and applies reversible day and night profiles.
endef

define Package/led-nightmode/conffiles
/etc/config/led-nightmode
endef

define Package/led-nightmode/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./core/root/etc/config/led-nightmode $(1)/etc/config/led-nightmode
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./core/root/etc/init.d/led-nightmode $(1)/etc/init.d/led-nightmode
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./core/root/etc/uci-defaults/99-led-nightmode $(1)/etc/uci-defaults/99-led-nightmode
	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./core/root/usr/libexec/led-nightmode-provider-service $(1)/usr/libexec/led-nightmode-provider-service
	$(INSTALL_BIN) ./core/root/usr/libexec/led-nightmode-service $(1)/usr/libexec/led-nightmode-service
	$(LN) led-nightmode-service $(1)/usr/libexec/led-nightmode-schedule
	$(LN) ../led-nightmode-service $(1)/usr/libexec/rpcd/luci.led-nightmode
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./core/root/usr/sbin/led-nightmode $(1)/usr/sbin/led-nightmode
endef

define Package/led-nightmode/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || /etc/init.d/rpcd reload 2>/dev/null
exit 0
endef

define Package/led-nightmode-provider-quectel-qnwcfg-ledmode
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Quectel QNWCFG LED provider for LED Night Mode
  DEPENDS:=+led-nightmode +picocom
  PKGARCH:=all
  MAINTAINER:=Mv Go <rapture-ribose6k@icloud.com>
  URL:=https://github.com/mv-go/luci-app-led-nightmode
endef

define Package/led-nightmode-provider-quectel-qnwcfg-ledmode/description
  Adds opt-in control of supported Quectel modem network indicators through
  the QNWCFG ledmode AT command.
endef

define Package/led-nightmode-provider-quectel-qnwcfg-ledmode/install
	$(INSTALL_DIR) $(1)/usr/libexec/led-nightmode/providers
	$(INSTALL_BIN) ./providers/quectel-qnwcfg-ledmode/root/usr/libexec/led-nightmode/providers/quectel-qnwcfg-ledmode $(1)/usr/libexec/led-nightmode/providers/quectel-qnwcfg-ledmode
endef

define Package/luci-app-led-nightmode/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	rm -f /tmp/luci-indexcache.*
	rm -rf /tmp/luci-modulecache/
}
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,led-nightmode))
$(eval $(call BuildPackage,led-nightmode-provider-quectel-qnwcfg-ledmode))
