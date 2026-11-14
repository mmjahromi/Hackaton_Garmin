import Toybox.Lang;
import Toybox.Test;
(:test)
function nutritionPlanIsUserBounded(logger as Logger) as Boolean {
    Test.assert(NutritionPlan.adjusted(50,1)==55);
    Test.assert(NutritionPlan.adjusted(30,-1)==30);
    Test.assert(NutritionPlan.adjusted(90,1)==90);
    return true;
}

(:test)
function nutritionSetupChoices(logger as Logger) as Boolean {
    var v = new NutritionSetup({"targetGph"=>50}, "Okay");
    Test.assert(!v.sharing && v.target == 50);
    v.change(1); Test.assert(v.target == 55);
    v.stage = 1; v.change(-1); Test.assert(v.food == 3);
    v.stage = 2; for(var i=0;i<20;i++) { v.change(-1); }
    Test.assert(v.portion == 5);
    v.stage = 3; v.change(-1); v.change(-1);
    Test.assert(v.DRINKS[v.drinkIndex] == 0);
    v.stage = 4; v.change(1); Test.assert(v.sharing);
    return true;
}
(:test)
function workoutClockExcludesStops(logger as Logger) as Boolean {
    Test.assert(WorkoutClock.seconds(11000,1000,0,0,false,1)==10);
    Test.assert(WorkoutClock.seconds(25000,1000,0,11000,true,1)==10);
    Test.assert(WorkoutClock.seconds(30000,1000,14000,11000,false,1)==15);
    Test.assert(WorkoutClock.seconds(25000,1000,0,11000,true,4)==40);
    Test.assert(WorkoutClock.seconds(0,1000,0,0,false,1)==0);
    return true;
}

(:test)
function liveFeedRespectsConsentAndRate(logger as Logger) as Boolean {
    Test.assert(!LiveFeedPolicy.due(false,"LIVE",false,10000,null,true));
    Test.assert(!LiveFeedPolicy.due(true,"DEMO",false,10000,null,true));
    Test.assert(!LiveFeedPolicy.due(true,"LIVE",true,10000,null,true));
    Test.assert(!LiveFeedPolicy.due(true,"LIVE",false,4999,0,false));
    Test.assert(LiveFeedPolicy.due(true,"LIVE",false,5000,0,false));
    Test.assert(LiveFeedPolicy.due(true,"LIVE",false,1,0,true));
    return true;
}

(:test)
function liveFeedKeepsLatestPendingState(logger as Logger) as Boolean {
    var feed=new LiveFeed();feed.busy=true;feed.lastStatus="active";
    feed.send({"mode"=>"LIVE","status"=>"paused"},true);
    Test.assert(feed.pending["status"].equals("paused"));
    feed.send({"mode"=>"LIVE","status"=>"active"},true);
    Test.assert(feed.pending["status"].equals("active"));
    feed.send({"mode"=>"LIVE","status"=>"completed"},true);
    Test.assert(feed.pending["status"].equals("completed"));
    return true;
}

(:test)
function resumeDoesNotPublishCachedReadings(logger as Logger) as Boolean {
    var feed=new LiveFeed();feed.busy=true;feed.lastStatus="paused";
    feed.send({"mode"=>"LIVE","status"=>"active","heartRate"=>150,"speedMps"=>3.0},true);
    Test.assert(feed.pending["heartRate"]==null && feed.pending["speedMps"]==null);
    var queued=new LiveFeed();queued.busy=true;queued.lastStatus="active";
    queued.send({"mode"=>"LIVE","status"=>"paused"},true);
    queued.send({"mode"=>"LIVE","status"=>"active","heartRate"=>160,"speedMps"=>4.0},true);
    Test.assert(queued.pending["heartRate"]==null && queued.pending["speedMps"]==null);
    return true;
}
