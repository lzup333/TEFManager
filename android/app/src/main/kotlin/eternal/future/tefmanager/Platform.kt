package eternal.future.tefmanager

/** Minimal platform state used by the Xposed entry point and the UI bridge. */
object Platform {
    @JvmStatic
    var isAndroidModuleActive: Boolean = false
}
