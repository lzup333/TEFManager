package eternal.future.tefmanager.utils

import platform.posix.exit

actual fun exitApplication() {
    exit(0)
}
