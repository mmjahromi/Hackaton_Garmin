import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

// Regression for the audit's release-blocking stale selection after replanning.
(:test)
function weeklyPersonalizationShrinksPlanSafely(logger as Test.Logger) as Boolean {
    var view=new RaceForgeAdventureView();
    view.flow=RaceForgeWeeklyFixtures.flow();
    view.flow.setupProfile["days"]=5; view.flow.finishSetup();
    var buttons=new RaceForgeAdventureDelegate(view);
    buttons.onSelect();
    for(var i=0;i<4;i+=1) { buttons.onNextPage(); }
    Test.assertEqual(view.flow.selected,4);
    buttons.onBack(); buttons.onMenu(); buttons.onNextPage(); buttons.onSelect();
    buttons.onSelect(); // setup step 1: activity days
    buttons.onNextPage(); // 5 wraps to 3 days
    buttons.onSelect(); buttons.onSelect(); buttons.onSelect();
    Test.assertEqual(view.flow.journey.missions().size(),4);
    var ref=Graphics.createBufferedBitmap({:width=>260,:height=>260});
    var surface=ref.get() as Graphics.BufferedBitmap;
    view.onUpdate(surface.getDc());
    Test.assert(view.flow.selected<view.flow.journey.missions().size());
    Test.assert(view.layoutValid);
    view.shutdown();
    logger.debug("Personalization 5 -> 4 checkpoints resets selection and redraws safely");
    return true;
}
