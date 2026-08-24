include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-led-nightmode
PKG_VERSION:=0.4.0
PKG_RELEASE:=4
PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE
LUCI_TITLE:=LED night mode for OpenWrt
LUCI_DESCRIPTION:=Preserve and restore OpenWrt LED triggers while applying day and night profiles.
LUCI_DEPENDS:=+luci-base +jshn +procd +rpcd +sunwait +uci
LUCI_PKGARCH:=all
LUCI_MAINTAINER:=mv-go <28507807+mv-go@users.noreply.github.com>
LUCI_URL:=https://github.com/mv-go/luci-app-led-nightmode

define Package/led-nightmode-provider-quectel-qnwcfg-ledmode
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Quectel QNWCFG LED provider for LED Night Mode
  DEPENDS:=+luci-app-led-nightmode +picocom
  PKGARCH:=all
  MAINTAINER:=mv-go <28507807+mv-go@users.noreply.github.com>
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

include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,led-nightmode-provider-quectel-qnwcfg-ledmode))
