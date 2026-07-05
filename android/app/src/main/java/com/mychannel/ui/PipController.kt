package com.mychannel.ui

/**
 * Process-wide flag coordinating auto Picture-in-Picture (Task 5, REQ-5.x).
 *
 * The video player screen marks a video as active while it is on screen and
 * playing; [com.mychannel.MainActivity.onUserLeaveHint] reads this flag to
 * decide whether to auto-enter PiP when the user presses Home / recents.
 *
 * A simple thread-safe holder is sufficient here: there is only ever one
 * foreground player, and both the writer (the player composable) and the
 * reader (the activity) run on the main thread. It is marked [Volatile] purely
 * for defensive visibility.
 */
object PipController {

    /** True while a video is on screen and eligible for auto-PiP. */
    @Volatile
    var isVideoActive: Boolean = false
}
