import Toybox.Lang;

// Pure timeline, in milliseconds of active playback. Mutates a retained model.
// This is illustrative visual cadence, never measured athlete step frequency.
class RaceForgeAvatarAnimator {
    function initialize() {}

    function periodMs(model as RaceForgeAvatarModel) as Number {
        var walking = model.motion == :WALK;
        var speed = model.speedMps;
        var period = walking ? 2200 : 1250;
        if (speed != null && speed >= 0 && speed == speed) {
            // Saturating nonlinear mapping; extreme speeds remain bounded.
            var bounded = speed > 12.0f ? 12.0f : speed;
            var ratio = bounded / (bounded + 2.0f);
            period = (walking ? 2400 - 800 * ratio : 1600 - 700 * ratio).toNumber();
        }
        if (model.advice == :EASE_OFF && !walking) { period += 180; }
        return period;
    }

    function apply(model as RaceForgeAvatarModel, animationTimeMs as Number) as Void {
        var time = animationTimeMs < 0 ? 0 : animationTimeMs;
        model.frame = 0; model.bob = 0; model.breath = 0;
        model.showSweat = false;
        if (model.lifecycle == :PAUSED || model.visualState == :PAUSED ||
            model.visualState == :SENSOR_UNAVAILABLE) { return; }
        model.breath = (time / 500) % 4;
        if (model.motion == :RUN || model.motion == :WALK) {
            if (model.movement != :STILL) {
                var period = periodMs(model);
                model.frame = ((time % period) * 4) / period;
                model.bob = model.frame % 2 == 0 ? -2 : 0;
            }
        } else if (model.motion == :START) {
            model.readyLean = time < 400 ? 0 : (time < 800 ? 1 : 2);
            model.bob = time >= 800 && model.breath % 2 == 1 ? -1 : 0;
        } else if (model.motion == :CELEBRATE) {
            model.frame = time < 2400 ? (time / 300) % 4 : 3;
            model.bob = time < 2400 && model.frame % 2 == 1 ? -3 : 0;
        }
        model.showSweat = (model.visualState == :RUNNING_EXHAUSTED ||
                           model.visualState == :RUNNING_WINDED) && model.breath >= 2;
    }
}
