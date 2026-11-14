import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Runs every 5 minutes while the app is closed. If stress is high it asks
// the user to open the app for a one-minute breathing session.
(:background)
class BreatheService extends System.ServiceDelegate {

    // Don't prompt again within this many seconds of the last prompt or session.
    private const COOLDOWN_S = 30 * 60;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var stress = Stress.current();
        System.println("Background check, stress=" + stress);

        if (stress != null && stress >= Stress.THRESHOLD && !inCooldown()) {
            markPrompted();
            Background.requestApplicationWake(
                "Stress is high (" + stress + "). Take a 1-minute breath?");
        }
        Background.exit(stress);
    }

    private function inCooldown() as Boolean {
        var now = Time.now().value();
        var lastPrompt = Application.Storage.getValue("lastPromptAt") as Number?;
        var lastSession = Application.Storage.getValue("lastSessionAt") as Number?;
        if (lastPrompt != null && now - lastPrompt < COOLDOWN_S) {
            return true;
        }
        if (lastSession != null && now - lastSession < COOLDOWN_S) {
            return true;
        }
        return false;
    }

    private function markPrompted() as Void {
        try {
            Application.Storage.setValue("lastPromptAt", Time.now().value());
        } catch (e) {
            // Older firmware can't write storage from the background; skip the cooldown.
        }
    }
}
