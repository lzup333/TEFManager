package eternal.future.tefmanager.utils

import android.util.Log

/** Tiny logger shim so the ported native helpers keep their call sites. */
object AppLogger {
    private const val TAG = "TEFManager"

    fun d(message: String) = Log.d(TAG, message)

    fun i(message: String) = Log.i(TAG, message)

    fun w(message: String, throwable: Throwable? = null) =
        Log.w(TAG, message, throwable)

    fun e(message: String, throwable: Throwable? = null) =
        Log.e(TAG, message, throwable)
}
