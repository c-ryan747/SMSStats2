GO_EASY_ON_ME = 1
ARCHS = armv7 armv7s arm64
THEOS_DEVICE_IP=192.168.1.101

include /opt/theos/makefiles/common.mk

TWEAK_NAME = SMSStats2
SMSStats2_LIBRARIES = substrate
SMSStats2_FILES = Tweak.xm CRViewController.m CRViewControllerAll.m FMDatabase.m FMDatabaseAdditions.m FMDatabasePool.m FMDatabaseQueue.m FMResultSet.m
SMSStats2_FRAMEWORKS = UIKit 
SMSStats2_LDFLAGS = -lsqlite3
ADDITIONAL_OBJCFLAGS = -fobjc-arc

include /opt/theos/makefiles/tweak.mk

BUNDLE_NAME = SMSStats2
SMSStats2_INSTALL_PATH = /Library/Application Support/

include /opt/theos/makefiles/bundle.mk

after-install::
	install.exec "killall -9 SpringBoard"