import Toybox.Lang;
import Toybox.Test;
import Toybox.Graphics;

(:test)
function weeklyVerticalSlice(logger as Test.Logger) as Boolean {
    var flow=new RaceForgeAdventureController();
    for(var setup=0;setup<4;setup+=1) { flow.select(); }
    Test.assertEqual(flow.journey.missions().size(),4);
    Test.assertEqual(flow.journey.data["position"] as Number,-1);
    flow.select(); Test.assertEqual(flow.screen,:LIST);
    flow.select(); Test.assertEqual(flow.screen,:PREVIEW);
    flow.select(); Test.assertEqual(flow.screen,:WORKOUT);
    for(var i=0;i<10;i+=1) { flow.step(250); }
    var before=flow.session.controller.sessionSec;
    flow.select(); Test.assertEqual(flow.screen,:PAUSE);
    for(var p=0;p<20;p+=1) { flow.step(250); }
    Test.assertEqual(flow.session.controller.sessionSec,before);
    flow.select();
    for(var j=0;j<180;j+=1) { flow.step(250); }
    Test.assertEqual(flow.screen,:SUMMARY);
    Test.assertEqual(flow.journey.completed(),0);
    flow.commitResult(); Test.assertEqual(flow.screen,:HOME);
    Test.assertEqual(flow.journey.completed(),1);
    Test.assertEqual(flow.journey.data["position"] as Number,0);
    logger.debug("Summit > mission > shared-controller demo > pause/resume > explicit completion > checkpoint");
    return true;
}

(:test)
function weeklyEndAndRendering(logger as Test.Logger) as Boolean {
    var view=new RaceForgeAdventureView();
    view.flow=new RaceForgeAdventureController();
    for(var setup=0;setup<4;setup+=1) { view.flow.select(); }
    var ref=Graphics.createBufferedBitmap({:width=>260,:height=>260});
    var bitmap=ref.get() as Graphics.BufferedBitmap; var dc=bitmap.getDc();
    view.onUpdate(dc); view.flow.select(); view.onUpdate(dc);
    view.flow.select(); view.onUpdate(dc); view.flow.select();
    view.flow.step(250); view.onUpdate(dc);
    view.flow.back(); Test.assertEqual(view.flow.screen,:END_CONFIRM); view.onUpdate(dc);
    view.flow.move(1); view.flow.select();
    Test.assertEqual(view.flow.screen,:SUMMARY); view.onUpdate(dc);
    view.flow.commitResult(); Test.assertEqual(view.flow.journey.completed(),0);
    view.onUpdate(dc); view.onHide();
    logger.debug("All first-slice screens render, early ending cannot award checkpoint");
    return true;
}
