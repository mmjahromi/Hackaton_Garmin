// User-reported feedback supports choices; it never infers physiological readiness.
module Recovery {
    function shorter(goal) { return goal > 360 ? goal - 300 : 60; }
    function suggestedChoice(energy, soreness, effort) {
        return energy == 0 || soreness == 2 || effort == 2 ? 1 : 0;
    }
    function nextGoal(goal, choice) {
        if (choice == 2) { return null; }
        return choice == 1 ? shorter(goal) : goal;
    }
}
