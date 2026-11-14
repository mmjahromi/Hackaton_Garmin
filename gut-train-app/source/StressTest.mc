import Toybox.Lang;
import Toybox.Test;

(:test)
function stressValidity(logger as Logger) as Boolean {
    Test.assert(StressPolicy.valid(0, 100, 1000));
    Test.assert(StressPolicy.valid(100, 1060, 1000));
    Test.assert(StressPolicy.valid(25.0, 0, 1000));
    Test.assert(!StressPolicy.valid(25, 1061, 1000));
    Test.assert(!StressPolicy.valid(25, null, 1000));
    Test.assert(!StressPolicy.valid(25, -1, 1000));
    Test.assert(!StressPolicy.valid(25, 100.5, 1000));
    var invalid=[null, -1, 101, 25.5, "25"];
    for(var i=0;i<invalid.size();i++) {
        Test.assert(!StressPolicy.valid(invalid[i], 100, 1000));
        Test.assert(StressPolicy.band(invalid[i])==null);
    }
    return true;
}

(:test)
function stressBands(logger as Logger) as Boolean {
    var scores=[0,25,26,50,51,75,76,100];
    var bands=["resting","resting","low","low","medium","medium","high","high"];
    for(var i=0;i<scores.size();i++) { Test.assert(StressPolicy.band(scores[i]).equals(bands[i])); }
    return true;
}

(:test)
function stressRefreshBoundary(logger as Logger) as Boolean {
    Test.assert(StressPolicy.shouldRefresh(0,null));
    Test.assert(!StressPolicy.shouldRefresh(60999,1000));
    Test.assert(StressPolicy.shouldRefresh(61000,1000));
    Test.assert(!StressPolicy.shouldRefresh(5000,10000));
    return true;
}

(:test)
class StressFeedProbe extends LiveFeed {
    var reads=0;
    var missing=false;
    function initialize() { LiveFeed.initialize(); }
    function readStress(now) {
        reads++;
        if (!missing) { stress=42; stressAt=100; }
    }
}

(:test)
function stressCacheRetainsRealTimestamp(logger as Logger) as Boolean {
    var feed=new StressFeedProbe();
    var body={"status"=>"active"};
    feed.addStress(body,0,1000);
    Test.assert(feed.reads==1 && body["stress"]==42 && body["stressAt"]==100);
    feed.addStress(body,59999,1059);
    Test.assert(feed.reads==1 && body["stressAt"]==100);
    feed.addStress(body,60000,1060);
    Test.assert(feed.reads==2 && body["stressAt"]==100);
    // An invalid newest reading clears the cache; missing data is also cached.
    feed.missing=true;
    feed.addStress(body,120000,1120);
    Test.assert(feed.reads==3 && body["stress"]==null && body["stressAt"]==null);
    feed.addStress(body,125000,1125);
    Test.assert(feed.reads==3 && body["stress"]==null);
    return true;
}

(:test)
function stressInactiveAndClockCorrection(logger as Logger) as Boolean {
    var feed=new StressFeedProbe();
    var body={"status"=>"active"};
    feed.addStress(body,0,1000);
    body["status"]="paused";
    feed.addStress(body,60000,1060);
    Test.assert(feed.reads==1 && body["stress"]==null && body["stressAt"]==null);
    body["status"]="completed";
    feed.addStress(body,65000,1065);
    Test.assert(feed.reads==1 && body["stress"]==null && body["stressAt"]==null);
    body["status"]="active";
    feed.addStress(body,66000,1066);
    Test.assert(feed.reads==2 && body["stressAt"]==100);
    feed.addStress(body,67000,39);
    Test.assert(feed.reads==2 && body["stress"]==null && body["stressAt"]==null);
    return true;
}

(:test)
function stressConsentAndDemoDoNotRead(logger as Logger) as Boolean {
    var feed=new StressFeedProbe();
    feed.send({"mode"=>"LIVE","status"=>"active"},false);
    feed.send({"mode"=>"DEMO","status"=>"active"},true);
    Test.assert(feed.reads==0 && feed.stressCheckedMs==null);
    return true;
}

(:test)
function dashboardLinkTextIsPlain(logger as Logger) as Boolean {
    return DashLinkText.status(null).equals("Dashboard: connecting") &&
        DashLinkText.status(200).equals("Dashboard connected") &&
        DashLinkText.status(-104).equals("Dashboard not connected") &&
        DashLinkText.status(404).equals("Dashboard not connected");
}
