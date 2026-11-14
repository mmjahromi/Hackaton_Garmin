import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

// Included only with monkeyc -t. Exercises real Garmin drawing APIs in the VM.
(:test)
function avatarDemoCycle(logger as Test.Logger) as Boolean {
    var demo = new RaceForgeAvatarDemoController();
    var renderer = new RaceForgeAvatarRenderer();
    var buffer = Graphics.createBufferedBitmap({:width => 260, :height => 260});
    var dc = buffer.get();
    Test.assert(dc != null);
    var context = (dc as Graphics.BufferedBitmap).getDc();
    var poses = [:IDLE, :JOG, :EASE, :WALK, :RECOVER, :CELEBRATE];
    for (var pass = 0; pass < 3; pass += 1) {
        for (var phase = 0; phase < poses.size(); phase += 1) {
            var model = demo.getModel();
            Test.assertEqual(model.pose, poses[phase]);
            Test.assertEqual(model.modeText, "DEMO");
            if (phase == 0 || phase == 5) {
                Test.assertEqual(model.hrText, "HR --");
            }
            context.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            context.clear();
            renderer.draw(context, model, 70, 51, 120, 120);
            // Also exercise an offset, reduced embedded widget.
            renderer.draw(context, model, 12, 20, 72, 84);
            var font = Graphics.FONT_SMALL;
            if (context.getTextWidthInPixels(model.headline, font) > 206) {
                font = Graphics.FONT_XTINY;
            }
            Test.assert(context.getTextWidthInPixels(model.headline, font) <= 206);
            logger.debug(model.pose.toString() + ": " + model.headline);
            demo.advance();
        }
        Test.assertEqual(demo.phase, 0);
    }
    return true;
}

(:test)
function avatarStartDelegate(logger as Test.Logger) as Boolean {
    var buffer = Graphics.createBufferedBitmap({:width => 260, :height => 260});
    var bitmap = buffer.get();
    Test.assert(bitmap != null);
    var context = (bitmap as Graphics.BufferedBitmap).getDc();
    var view = new RaceForgeView();
    var delegate = new RaceForgeDelegate(view);
    view.onShow();
    for (var press = 0; press < 18; press += 1) {
        view.onUpdate(context);
        Test.assert(delegate.onSelect());
    }
    view.onHide();
    view.onShow();
    view.onUpdate(context);
    view.onHide();
    logger.debug("18 START callbacks and hide/show completed without errors");
    return true;
}
