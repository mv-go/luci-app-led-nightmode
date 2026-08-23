include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-led-nightmode
PKG_VERSION:=0.2.0
PKG_RELEASE:=2
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=mv-go <28507807+mv-go@users.noreply.github.com>

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-led-nightmode
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LED night mode for OpenWrt
  DEPENDS:=+procd +sunwait +uci
  PKGARCH:=all
endef

define Package/led-nightmode-provider-quectel-qnwcfg-ledmode
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Quectel QNWCFG LED provider for LED Night Mode
  DEPENDS:=+luci-app-led-nightmode +picocom
  PKGARCH:=all
endef

define Package/led-nightmode-provider-quectel-qnwcfg-ledmode/description
  Adds opt-in control of supported Quectel modem network indicators through
  the QNWCFG ledmode AT command.
endef

define Package/luci-app-led-nightmode/description
  Preserve and restore OpenWrt LED triggers while applying day and night profiles.
endef

define Build/Compile
endef

define Package/luci-app-led-nightmode/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/led-nightmode $(1)/etc/config/led-nightmode
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/led-nightmode $(1)/etc/init.d/led-nightmode
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./root/usr/libexec/led-nightmode-service $(1)/usr/libexec/led-nightmode-schedule
	$(INSTALL_BIN) ./root/usr/libexec/led-nightmode-provider-service $(1)/usr/libexec/led-nightmode-provider-service
	$(INSTALL_BIN) ./root/usr/libexec/led-nightmode-service $(1)/usr/libexec/led-nightmode-service
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./root/usr/sbin/led-nightmode $(1)/usr/sbin/led-nightmode
endef

define Package/led-nightmode-provider-quectel-qnwcfg-ledmode/install
	$(INSTALL_DIR) $(1)/usr/libexec/led-nightmode/providers
	$(INSTALL_BIN) ./root/usr/libexec/led-nightmode/providers/quectel-qnwcfg-ledmode $(1)/usr/libexec/led-nightmode/providers/quectel-qnwcfg-ledmode
endef

define Package/luci-app-led-nightmode/conffiles
/etc/config/led-nightmode
endef

$(eval $(call BuildPackage,luci-app-led-nightmode))
$(eval $(call BuildPackage,led-nightmode-provider-quectel-qnwcfg-ledmode))
