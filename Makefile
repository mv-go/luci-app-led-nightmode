include $(TOPDIR)/rules.mk

LUCI_TITLE:=LED night mode for OpenWrt
LUCI_DESCRIPTION:=Preserve and restore OpenWrt LED triggers while applying day and night profiles.
LUCI_DEPENDS:=+luci-base
LUCI_PKGARCH:=all

PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=mv-go <28507807+mv-go@users.noreply.github.com>

define Package/luci-app-led-nightmode/conffiles
/etc/config/led-nightmode
endef

include ../../luci.mk

# call BuildPackage - OpenWrt buildroot signature
