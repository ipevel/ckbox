package com.ckbox.app

import android.app.Activity
import android.os.Bundle
import com.ckbox.app.extensions.wrapAction
import com.ckbox.app.widget.HomeWidgetRenderer
import com.ckbox.app.widget.HomeWidgets

class TempActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent.action) {
            wrapAction("START") -> GlobalState.handleStart()
            wrapAction("STOP") -> GlobalState.handleStop()
            wrapAction("CHANGE") -> GlobalState.handleToggle()
            wrapAction(HomeWidgetRenderer.REFRESH_ACTION) -> HomeWidgets.refresh(this)
        }
        finishAndRemoveTask()
    }
}
