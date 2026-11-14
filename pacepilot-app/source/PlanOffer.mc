import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;

// "Get today's plan": reads the dashboard's suggestion so the user can
// choose to use it. Pure parsing lives in the module so it can be tested;
// the class below only makes the one web request.
module PlanOffer {
    const ACTIVITY = {"walk" => "walk", "run_walk" => "run/walk", "cycle" => "ride"};

    function waiting() {
        return {:ok => false, :waiting => true, :text => "Connecting...", :detail => "Reaching your dashboard"};
    }

    // Turns the dashboard's answer into what the plan screen shows. Anything
    // unexpected becomes a plain "nothing changed" message, never a setting.
    function parse(code, data) {
        if (code != 200 || !(data instanceof Dictionary)) {
            return {:ok => false, :text => "Dashboard not connected", :detail => "Check your phone is nearby and online"};
        }
        if (data["available"] != true) {
            return {:ok => false, :text => "Plan sharing is off", :detail => "Turn on Send plan to watch on the dashboard"};
        }
        var s = data["suggestion"];
        if (!(s instanceof Dictionary)) {
            return {:ok => false, :text => "No plan today", :detail => "Set preferences on the dashboard"};
        }
        var minutes = s["durationMin"];
        var reason = s["reason"] instanceof String ? s["reason"] : "";
        if ("rest".equals(s["kind"]) && (!(minutes instanceof Number) || minutes <= 0)) {
            return {:ok => false, :text => "Rest day suggested", :detail => reason};
        }
        if (!(minutes instanceof Number) || minutes < 1 || minutes > 90 || !(s["id"] instanceof String)) {
            return {:ok => false, :text => "Plan not usable", :detail => "Nothing changed"};
        }
        var activity = ACTIVITY.hasKey(s["activity"]) ? ACTIVITY[s["activity"]] : "session";
        var goal = minutes * 60;
        if (goal < 60) { goal = 60; }
        if (goal > 3600) { goal = 3600; }
        // A demo plan is simulated data: say so, and never report against it.
        var demo = data["demo"] == true;
        return {:ok => true, :demo => demo, :text => (demo ? "Demo: " : "") + minutes.toString() + " min " + activity,
                :detail => reason, :goalSec => goal, :id => s["id"]};
    }

    // Splits a sentence over two short lines at a word boundary. Anything
    // that still does not fit the second line is cut.
    function wrap(text, max) {
        if (text == null) { return ["", ""]; }
        if (text.length() <= max) { return [text, ""]; }
        var cut = max;
        while (cut > 0 && !text.substring(cut, cut + 1).equals(" ")) { cut--; }
        if (cut == 0) { cut = max; }
        var first = text.substring(0, cut);
        var rest = text.substring(text.substring(cut, cut + 1).equals(" ") ? cut + 1 : cut, text.length());
        if (rest.length() > max) { rest = rest.substring(0, max - 3) + "..."; }
        return [first, rest];
    }
}

class PlanSync {
    var view = null;
    function initialize() {}
    // app=pacepilot lets the dashboard show "PacePilot checked in just now".
    // With demo true it asks for the labelled demo plan instead.
    function fetch(v, demo) {
        view = v;
        try {
            Communications.makeWebRequest("https://gut-train-web.vercel.app/api/watch-config",
                demo ? {"app" => "pacepilot", "mode" => "demo"} : {"app" => "pacepilot"},
                {:method => Communications.HTTP_REQUEST_METHOD_GET,
                 :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},
                method(:onResult));
        } catch (e) { v.onPlan(-1, null); }
    }
    function onResult(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        if (view != null) { view.onPlan(code, data); }
    }
}
