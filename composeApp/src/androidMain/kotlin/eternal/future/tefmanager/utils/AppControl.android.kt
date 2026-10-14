package eternal.future.tefmanager.utils

import eternal.future.tefmanager.MainActivity

actual fun exitApplication() {
    MainActivity.context?.finishAffinity()
}
