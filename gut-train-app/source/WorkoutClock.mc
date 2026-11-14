module WorkoutClock {
    function seconds(now, start, pausedMs, pauseAt, paused, speed) {
        var ms=(paused ? pauseAt : now)-start-pausedMs;
        return ms < 0 ? 0 : (ms*speed)/1000;
    }
}
