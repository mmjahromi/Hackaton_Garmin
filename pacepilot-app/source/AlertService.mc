import Toybox.Attention;

// The gate can be tested without vibrating the simulator.
class AlertGate {
    var lastId = -1;
    var lastAt = null;
    function initialize() {}
    function allow(id, now) {
        if (id == lastId) { return false; }
        lastId = id;
        if (lastAt != null && now - lastAt < 10000) { return false; }
        lastAt = now;
        return true;
    }
}
class AlertService {
    var gate;
    function initialize() { gate = new AlertGate(); }
    function emit(id, advice, now) {
        if (!gate.allow(id, now)) { return; }
        if (!(Attention has :vibrate)) { return; }
        try {
            var pattern = [new Attention.VibeProfile(50, 200)];
            if (advice == :WALK) {
                pattern.add(new Attention.VibeProfile(0, 200));
                pattern.add(new Attention.VibeProfile(50, 200));
            }
            Attention.vibrate(pattern);
        } catch (e) {}
    }
}
