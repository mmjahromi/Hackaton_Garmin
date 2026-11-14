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
