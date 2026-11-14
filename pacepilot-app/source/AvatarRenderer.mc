// From prototypes/raceforge-avatar.
import Toybox.Graphics;
import Toybox.Lang;

// Original procedural artwork. Character only; caller clears and requests redraw.
// 120x120 design grid. No per-frame arrays, sensors, timers, storage or navigation.
// Resets clip to the full Dc and pen to 1. Parent reapplies its drawing state.
class RaceForgeAvatarRenderer {
    private var _left as Number = 0;
    private var _top as Number = 0;
    private var _size as Number = 120;
    private var _dy as Number = 0;
    private const SKIN = 0xFFAA55;
    private const EDGE = 0x555555;
    private const TEAL = 0x00AAAA;
    private const DARK_TEAL = 0x005555;
    private const ORANGE = 0xFF5500;
    private const WHITE = 0xFFFFFF;
    // knee/ankle pairs, then elbow/wrist pairs. Opposing arms and legs.
    private var _run as Array<Array<Number>> = [
        [43,94,29,108, 79,88,70,100, 39,66,30,53, 83,64,94,49],
        [56,98,52,111, 72,92,85,99, 40,67,37,57, 82,66,88,54],
        [76,88,68,100, 45,94,29,108, 37,62,29,49, 84,68,94,57],
        [53,92,39,99, 66,98,72,111, 39,64,32,53, 81,68,85,58]
    ];
    private var _walk as Array<Array<Number>> = [
        [48,97,40,110, 70,97,80,110, 41,74,36,86, 79,74,85,82],
        [54,98,53,111, 67,97,73,108, 44,75,42,88, 77,75,79,87],
        [51,97,42,110, 72,97,82,110, 43,74,46,82, 80,74,86,86],
        [53,97,47,108, 66,98,67,111, 44,75,42,88, 77,75,79,87]
    ];

    function initialize() {}

    function draw(dc as Graphics.Dc, model as RaceForgeAvatarModel,
                  left as Number, top as Number, width as Number, height as Number) as Void {
        if (width < 24 || height < 24) { return; }
        _size = width < height ? width : height;
        _left = left + (width - _size) / 2;
        _top = top + (height - _size) / 2;
        _dy = 0;
        dc.setClip(left, top, width, height);
        ellipse(dc, 31, 113, 60, 4, 0x555555);
        _dy = model.bob;
        var hx = 62;
        var hy = 29;
        var bx = 60;
        var by = 65;
        var state = model.visualState;
        var motion = model.motion;
        var joints = _run[model.frame % 4];
        if (motion == :WALK) { joints = _walk[model.frame % 4]; }
        if (motion == :RUN) {
            hx = 67; hy = 27; bx = 62;
        }
        if (state == :RUNNING_WINDED || state == :RUNNING_EXHAUSTED) {
            hx += 3; hy += 3; by += 2;
        }
        if (motion == :START) {
            // Shift from upright to a low, forward running-start stance.
            hx = 63 + model.readyLean * 6;
            hy = 30 + model.readyLean * 5;
            bx = 61 + model.readyLean * 3;
            by = 66 + model.readyLean * 3;
            leg(dc, 54, 86, 41, 95, 31, 110, DARK_TEAL);
            leg(dc, 67, 86, 81, 94, 89, 110, TEAL);
            arm(dc, bx - 12, by - 9, 51, 77, 43, 69, DARK_TEAL);
            arm(dc, bx + 12, by - 9, 89, 79, 98, 64, TEAL);
        } else if (motion == :RUN || motion == :WALK) {
            leg(dc, 54, 84, joints[0], joints[1], joints[2], joints[3], DARK_TEAL);
            arm(dc, bx - 12, by - 10, joints[8], joints[9], joints[10], joints[11], DARK_TEAL);
            leg(dc, 66, 84, joints[4], joints[5], joints[6], joints[7], TEAL);
        } else {
            leg(dc, 54, 85, 51, 98, 48, 111, DARK_TEAL);
            leg(dc, 66, 85, 70, 98, 73, 111, TEAL);
            if (motion == :CELEBRATE) {
                arm(dc, 48, 55, 34, 38, 27, 17, DARK_TEAL);
                arm(dc, 72, 55, 88, 38, 95, 17, TEAL);
                sparkle(dc, 15, 38, model.frame % 2);
                sparkle(dc, 106, 42, 1 - model.frame % 2);
            } else {
                arm(dc, 48, 56, 39, 75, 43, 87, DARK_TEAL);
                arm(dc, 72, 56, 83, 72, 80, 85, TEAL);
            }
        }
        // Neck, connected torso and singlet with side shading and race bib.
        stroke(dc, hx, hy + 18, bx, by - 9, EDGE, 12);
        stroke(dc, hx, hy + 18, bx, by - 9, SKIN, 8);
        rounded(dc, bx - 16, by - 15, 32, 36, 9, EDGE);
        rounded(dc, bx - 14, by - 14, 28, 33, 8, TEAL);
        rounded(dc, bx - 13, by - 10, 7, 27, 3, DARK_TEAL);
        stroke(dc, bx - 5, by - 14, bx + 5, by - 14, SKIN, 4);
        rounded(dc, bx - 7, by - 3, 15, 12, 2, WHITE);
        stroke(dc, bx - 3, by, bx + 3, by, DARK_TEAL, 2);
        stroke(dc, bx + 3, by, bx, by + 5, DARK_TEAL, 2);
        stroke(dc, bx - 12, by + 18, bx + 12, by + 18, 0x005555, 8);
        stroke(dc, bx - 12, by + 14, bx + 12, by + 14, WHITE, 2);
        if (motion == :RUN || motion == :WALK) {
            arm(dc, bx + 12, by - 10, joints[12], joints[13], joints[14], joints[15], TEAL);
        }
        face(dc, hx, hy, model);
        if (state == :RUNNING_WINDED || state == :RUNNING_EXHAUSTED) {
            if (model.breath > 0) {
                var puff = model.breath;
                ellipse(dc, hx + 20 + puff * 2, hy + 8 - puff, 3 + puff * 3, 3 + puff, WHITE);
                if (state == :RUNNING_EXHAUSTED) {
                    ellipse(dc, hx + 28, hy + 17, 4 + puff * 2, 4, 0xAAAAAA);
                }
            }
        }
        if (model.showSweat) {
            stroke(dc, hx - 25, hy - 2, hx - 28, hy + 4 + model.breath, TEAL, 3);
            circle(dc, hx - 28, hy + 5 + model.breath, 3, TEAL);
        }
        if (state == :SENSOR_UNAVAILABLE) {
            // Neutral, never an exertion face on missing HR.
            stroke(dc, 96, 52, 103, 52, WHITE, 2);
            stroke(dc, 103, 52, 103, 57, WHITE, 2);
            stroke(dc, 103, 57, 99, 60, WHITE, 2);
            circle(dc, 99, 65, 1, WHITE);
        }
        dc.setPenWidth(1);
        dc.setClip(0, 0, dc.getWidth(), dc.getHeight());
    }

    private function face(dc as Graphics.Dc, hx as Number, hy as Number,
                          model as RaceForgeAvatarModel) as Void {
        var state = model.visualState;
        var strained = state == :RUNNING_WINDED || state == :RUNNING_EXHAUSTED;
        var skin = model.flush == 2 ? 0xFF5555 : SKIN;
        circle(dc, hx - 19, hy + 1, 5, EDGE);
        circle(dc, hx - 19, hy + 1, 3, skin);
        circle(dc, hx, hy, 21, EDGE);
        circle(dc, hx, hy, 19, skin);
        ellipse(dc, hx - 18, hy - 21, 36, 14, 0x550000);
        stroke(dc, hx - 17, hy - 11, hx + 17, hy - 11, ORANGE, 5);
        stroke(dc, hx + 18, hy - 11, hx + 25, hy - 6, ORANGE, 3);
        stroke(dc, hx - 11, hy - 15, hx - 3, hy - 16, 0xAA5500, 2);
        if (model.flush > 0) {
            ellipse(dc, hx - 15, hy + 5, 8, 5, ORANGE);
            ellipse(dc, hx + 8, hy + 5, 8, 5, ORANGE);
        }
        if (state == :CELEBRATING) {
            stroke(dc, hx - 12, hy + 1, hx - 8, hy - 2, 0x000000, 2);
            stroke(dc, hx - 8, hy - 2, hx - 4, hy + 1, 0x000000, 2);
            stroke(dc, hx + 3, hy + 1, hx + 7, hy - 2, 0x000000, 2);
            stroke(dc, hx + 7, hy - 2, hx + 11, hy + 1, 0x000000, 2);
        } else {
            ellipse(dc, hx - 12, hy - 3, 7, strained ? 5 : 8, WHITE);
            ellipse(dc, hx + 3, hy - 3, 7, strained ? 5 : 8, WHITE);
            circle(dc, hx - 7, hy + 1, 2, 0x000000);
            circle(dc, hx + 8, hy + 1, 2, 0x000000);
            stroke(dc, hx - 12, hy - 7, hx - 5, hy - (strained ? 4 : 7), 0x000000, 2);
            stroke(dc, hx + 3, hy - (strained ? 4 : 7), hx + 10, hy - 7, 0x000000, 2);
        }
        stroke(dc, hx + 1, hy + 4, hx + 3, hy + 6, 0xAA5500, 2);
        if (strained) {
            ellipse(dc, hx - 4, hy + 10, 9, 4 + model.breath * 2, 0x000000);
        } else if (state == :SENSOR_UNAVAILABLE || state == :PAUSED || state == :RECOVERING || state == :RUNNING_FOCUSED) {
            stroke(dc, hx - 5, hy + 12, hx + 4, hy + 12, 0x000000, 2);
        } else {
            rounded(dc, hx - 7, hy + 9, 14, 8, 4, 0x000000);
            stroke(dc, hx - 4, hy + 10, hx + 4, hy + 10, WHITE, 2);
        }
    }

    private function x(v as Number) as Number { return _left + n(v); }
    private function y(v as Number) as Number { return _top + n(v + _dy); }
    private function n(v as Number) as Number { return v * _size / 120; }
    private function circle(dc as Graphics.Dc, cx as Number, cy as Number, r as Number, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x(cx), y(cy), n(r));
    }
    private function ellipse(dc as Graphics.Dc, ax as Number, ay as Number, w as Number, h as Number, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        // Garmin takes center + radii, unlike fillRoundedRectangle's bounds.
        dc.fillEllipse(x(ax + w / 2), y(ay + h / 2), n(w / 2), n(h / 2));
    }
    private function rounded(dc as Graphics.Dc, ax as Number, ay as Number, w as Number, h as Number, r as Number, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x(ax), y(ay), n(w), n(h), n(r));
    }
    private function stroke(dc as Graphics.Dc, ax as Number, ay as Number, bx as Number, by as Number, c as Number, thick as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        var pen = n(thick);
        dc.setPenWidth(pen > 0 ? pen : 1);
        dc.drawLine(x(ax), y(ay), x(bx), y(by));
        circle(dc, ax, ay, thick / 2, c);
        circle(dc, bx, by, thick / 2, c);
    }
    private function leg(dc as Graphics.Dc, ax as Number, ay as Number, kx as Number, ky as Number, fx as Number, fy as Number, c as Number) as Void {
        stroke(dc, ax, ay, kx, ky, EDGE, 10);
        stroke(dc, kx, ky, fx, fy - 3, EDGE, 8);
        stroke(dc, ax, ay, kx, ky, c, 8);
        stroke(dc, kx, ky, fx, fy - 3, SKIN, 6);
        stroke(dc, fx - 2, fy, fx + 7, fy, EDGE, 8);
        stroke(dc, fx - 2, fy - 1, fx + 6, fy - 1, WHITE, 6);
        stroke(dc, fx - 3, fy + 3, fx + 7, fy + 3, ORANGE, 2);
    }
    private function arm(dc as Graphics.Dc, ax as Number, ay as Number, ex as Number, ey as Number, hx as Number, hy as Number, c as Number) as Void {
        stroke(dc, ax, ay, ex, ey, EDGE, 10);
        stroke(dc, ex, ey, hx, hy, EDGE, 9);
        stroke(dc, ax, ay, ex, ey, c, 8);
        stroke(dc, ex, ey, hx, hy, SKIN, 6);
        circle(dc, hx, hy, 4, SKIN);
    }
    private function sparkle(dc as Graphics.Dc, sx as Number, sy as Number, phase as Number) as Void {
        stroke(dc, sx - 3 - phase, sy, sx + 3 + phase, sy, 0xFFAA00, 2);
        stroke(dc, sx, sy - 5 - phase, sx, sy + 5 + phase, 0xFFAA00, 2);
    }
}
