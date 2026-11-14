import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

(:test)
function avatarAnimationFrames(logger as Test.Logger) as Boolean {
    var animator = new RaceForgeAvatarAnimator();
    var renderer = new RaceForgeAvatarRenderer();
    var ref = Graphics.createBufferedBitmap({:width => 260, :height => 260});
    var bitmap = ref.get() as Graphics.BufferedBitmap;
    var dc = bitmap.getDc();
    var model = new RaceForgeAvatarModel(:JOG, "NICE RHYTHM", "HR 130", "DEMO");
    model.lifecycle = :ACTIVE;
    var period = animator.periodMs(model);
    for (var i = 0; i < 4; i += 1) {
        animator.apply(model, (period * i + 3) / 4);
        Test.assertEqual(model.frame, i);
        renderer.draw(dc, model, 58, 40, 144, 144);
    }
    animator.apply(model, period * 100 + period / 2);
    Test.assertEqual(model.frame, 2);
    model.visualState = :RUNNING_EXHAUSTED;
    model.flush = 2;
    animator.apply(model, 1000);
    Test.assertEqual(model.breath, 2);
    Test.assert(model.showSweat);
    renderer.draw(dc, model, 58, 40, 144, 144);
    animator.apply(model, 2000);
    Test.assertEqual(model.breath, 0);
    Test.assert(!model.showSweat);
    model.motion = :START; model.visualState = :READY_TO_RUN;
    animator.apply(model, 0); Test.assertEqual(model.readyLean, 0);
    animator.apply(model, 900); Test.assertEqual(model.readyLean, 2);
    renderer.draw(dc, model, 15, 24, 72, 84);
    model.motion = :CELEBRATE; model.visualState = :CELEBRATING;
    animator.apply(model, 5000);
    Test.assertEqual(model.bob, 0); Test.assertEqual(model.frame, 3);
    logger.debug("Four timed frames, delayed callback, breath/sweat, starting crouch and final hold");
    return true;
}

