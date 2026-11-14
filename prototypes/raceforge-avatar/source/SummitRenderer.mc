import Toybox.Graphics;
import Toybox.Lang;

class RaceForgeSummitRenderer {
    var _mountain=[[43,178],[85,118],[108,128],[143,56],[215,178]];
    var _snow=[[143,56],[125,94],[141,87],[154,100],[164,91]];
    var _points=[[68,166],[155,146],[105,121],[169,102],[143,70]];
    var _avatar=new RaceForgeAvatarRenderer();
    var _idle=new RaceForgeAvatarModel(:IDLE,"","HR --","DEMO");
    function initialize() {}
    function point(index,count) { return _points[count==4 ? [0,1,3,4][index] : index]; }
    function draw(dc,journey) {
        dc.setColor(0x005555,Graphics.COLOR_TRANSPARENT); dc.fillPolygon(_mountain);
        dc.setColor(0xAAAAAA,Graphics.COLOR_TRANSPARENT); dc.fillPolygon(_snow);
        var items=journey.missions(); var count=items.size();
        dc.setPenWidth(3); dc.setColor(0xAAAAAA,Graphics.COLOR_TRANSPARENT);
        for(var i=1;i<count;i+=1) {
            var a=point(i-1,count); var b=point(i,count); dc.drawLine(a[0],a[1],b[0],b[1]);
        }
        dc.setPenWidth(1);
        for(var j=0;j<count;j+=1) {
            var p=point(j,count); var complete=items[j]["status"].equals("complete");
            dc.setColor(complete ? 0x00AAAA : (j==journey.nextIndex() ? 0xFFAA00 : 0x555555),Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(p[0],p[1],6);
            dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_TRANSPARENT);
            if(complete) { dc.drawLine(p[0]-3,p[1],p[0],p[1]+2); dc.drawLine(p[0],p[1]+2,p[0]+3,p[1]-3); }
            if(items[j]["status"].equals("skipped")) { dc.drawLine(p[0]-3,p[1]-3,p[0]+3,p[1]+3); }
        }
        var position=journey.data["position"];
        var at=position<0 ? [55,181] : point(position,count);
        _avatar.draw(dc,_idle,at[0]-19,at[1]-41,38,38);
    }
}
