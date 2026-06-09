using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Application;
using Toybox.Math;

class SpiralView extends WatchUi.WatchFace {

    // ---- geometry / animation tuning ----
    private const TURNS  = 8;     // number of spiral revolutions across the radius
    private const STEPS  = 460;   // polyline segments (resolution vs. speed trade-off)

    // ---- screen ----
    private var _w  as Lang.Number = 454;
    private var _h  as Lang.Number = 454;
    private var _cx as Lang.Number = 227;
    private var _cy as Lang.Number = 227;
    private var _r  as Lang.Number = 220;   // outer spiral radius

    // ---- precomputed (unrotated) spiral, polar form ----
    private var _sr    as Lang.Array<Lang.Float> or Null;  // radius per point
    private var _stheta as Lang.Array<Lang.Float> or Null; // base angle per point

    // ---- settings ----
    private var _spiralColor as Lang.Number = 0xFF0000;  // red
    private var _handColor   as Lang.Number = 0xFFFFFF;  // white
    private var _bgColor     as Lang.Number = 0x000000;  // black
    private var _rotSpeed    as Lang.Float  = 0.30;      // radians / second
    private var _showSecond  as Lang.Boolean = false;

    private var _lowPower as Lang.Boolean = false;

    function initialize() {
        WatchFace.initialize();
        reloadSettings();
    }

    function reloadSettings() as Void {
        var app = Application.getApp();
        _spiralColor = colorFor(propNum(app, "SpiralColor", 0)); // default red
        _handColor   = colorFor(propNum(app, "HandColor",   7)); // default white
        _bgColor     = colorFor(propNum(app, "BgColor",     8)); // default black

        var s = propNum(app, "RotateSpeed", 0);
        if      (s == 1) { _rotSpeed = 1.70; }
        else if (s == 2) { _rotSpeed = 2.60; }
        else             { _rotSpeed = 1.00; } // slow (default)

        _showSecond = propBool(app, "ShowSecond", false);
    }

    function onLayout(dc as Graphics.Dc) as Void {
        _w  = dc.getWidth();
        _h  = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        _r  = ((_w < _h ? _w : _h) / 2) - 4;
        buildSpiral();
    }

    // Power-law spiral: angle theta = thetaMax*u, radius r = R*u^2  (u in 0..1).
    // The u^2 radius makes the gap between successive turns grow toward the rim.
    // u is sampled as (i/N)^(1/3) so points pack denser outward -> smooth curve.
    private function buildSpiral() as Void {
        var thetaMax = TURNS * 2.0 * Math.PI;
        var rr = new [STEPS + 1];
        var tt = new [STEPS + 1];
        for (var i = 0; i <= STEPS; i += 1) {
            var u = Math.pow(i.toFloat() / STEPS, 1.0 / 3.0);
            tt[i] = thetaMax * u;
            rr[i] = _r * u * u;
        }
        _sr = rr;
        _stheta = tt;
    }

    function onShow() as Void {}
    function onHide() as Void {}
    function onEnterSleep() as Void { _lowPower = true; WatchUi.requestUpdate(); }
    function onExitSleep()  as Void { _lowPower = false; WatchUi.requestUpdate(); }

    function onUpdate(dc as Graphics.Dc) as Void {
        // background
        dc.setColor(_bgColor, _bgColor);
        dc.clear();

        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        if (_lowPower) {
            // Always-on: keep it dark — no animated spiral, thin hands only.
            drawHands(dc, now, true);
            return;
        }

        // phase advances with real time so rotation speed is fps-independent
        var phase = (System.getTimer().toFloat() / 1000.0) * _rotSpeed;
        drawSpiral(dc, phase);
        drawHands(dc, now, false);

        // drive the animation loop while awake
        WatchUi.requestUpdate();
    }

    private function drawSpiral(dc as Graphics.Dc, phase as Lang.Float) as Void {
        var sr = _sr;
        var st = _stheta;
        if (sr == null || st == null) { return; }

        dc.setColor(_spiralColor, Graphics.COLOR_TRANSPARENT);

        var px = _cx;
        var py = _cy;
        for (var i = 0; i <= STEPS; i += 1) {
            var a = phase - st[i];   // mirrored spiral -> clockwise spin, still expanding outward
            var x = _cx + sr[i] * Math.cos(a);
            var y = _cy + sr[i] * Math.sin(a);
            if (i > 0) {
                // pen grows from ~6px near the center toward the rim...
                var w = 6.0 + 12.0 * (sr[i] / _r);
                // ...then the outer tail tapers back to a point over the last 20%
                var t = i.toFloat() / STEPS;
                if (t > 0.80) {
                    w = w * (1.0 - t) / 0.20;   // 1.0 -> 0
                }
                var wi = w.toNumber();
                if (wi >= 1) {                  // sub-pixel tip simply vanishes
                    dc.setPenWidth(wi);
                    dc.drawLine(px, py, x, y);
                }
            }
            px = x;
            py = y;
        }
        dc.setPenWidth(1);
    }

    private function drawHands(dc as Graphics.Dc, now as Gregorian.Info, dim as Lang.Boolean) as Void {
        var hour = now.hour % 12;
        var min  = now.min;
        var sec  = now.sec;

        var minAngle  = (min + sec / 60.0) / 60.0 * 2.0 * Math.PI;
        var hourAngle = (hour + min / 60.0) / 12.0 * 2.0 * Math.PI;

        var white = _handColor;

        if (dim) {
            // AOD: thin outlined-style hands, minimal lit pixels
            dc.setColor(white, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine(_cx, _cy, tipX(hourAngle, _r * 0.50), tipY(hourAngle, _r * 0.50));
            dc.setPenWidth(2);
            dc.drawLine(_cx, _cy, tipX(minAngle, _r * 0.78), tipY(minAngle, _r * 0.78));
            dc.setPenWidth(1);
            return;
        }

        // hour hand (short, wide)
        dc.setColor(white, Graphics.COLOR_TRANSPARENT);
        fillHand(dc, hourAngle, _r * 0.52, _r * 0.14, 10, 4);

        // minute hand (long, slim)
        fillHand(dc, minAngle, _r * 0.82, _r * 0.14, 7, 3);

        // optional second hand
        if (_showSecond) {
            var secAngle = sec / 60.0 * 2.0 * Math.PI;
            dc.setColor(_spiralColor, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(tipX(secAngle, -_r * 0.16), tipY(secAngle, -_r * 0.16),
                        tipX(secAngle,  _r * 0.86), tipY(secAngle,  _r * 0.86));
            dc.setPenWidth(1);
        }

        // center hub
        dc.setColor(white, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, 7);
        dc.setColor(_bgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, 3);
    }

    // Tapered hand as a 4-point polygon. Angle measured clockwise from 12 o'clock.
    // length = distance to tip, back = length behind center, baseW/tipW = widths.
    private function fillHand(dc as Graphics.Dc, a as Lang.Float, length as Lang.Float,
                             back as Lang.Float, baseW as Lang.Number, tipW as Lang.Number) as Void {
        var sa = Math.sin(a);
        var ca = Math.cos(a);
        var hb = baseW / 2.0;
        var ht = tipW / 2.0;

        var bx = _cx - back * sa;          // back point (behind center)
        var by = _cy + back * ca;
        var tx = _cx + length * sa;        // tip
        var ty = _cy - length * ca;

        var pts = [
            [(bx + hb * ca).toNumber(), (by + hb * sa).toNumber()],
            [(bx - hb * ca).toNumber(), (by - hb * sa).toNumber()],
            [(tx - ht * ca).toNumber(), (ty - ht * sa).toNumber()],
            [(tx + ht * ca).toNumber(), (ty + ht * sa).toNumber()]
        ];
        dc.fillPolygon(pts);
    }

    private function tipX(a as Lang.Float, len as Lang.Float) as Lang.Number {
        return (_cx + len * Math.sin(a)).toNumber();
    }
    private function tipY(a as Lang.Float, len as Lang.Float) as Lang.Number {
        return (_cy - len * Math.cos(a)).toNumber();
    }

    // shared palette: each color picker stores an index into this list
    private function colorFor(i as Lang.Number) as Lang.Number {
        if (i == 1) { return 0x1E90FF; } // blue
        if (i == 2) { return 0x00E5FF; } // cyan
        if (i == 3) { return 0x00C853; } // green
        if (i == 4) { return 0x9B59FF; } // purple
        if (i == 5) { return 0xFF8C00; } // orange
        if (i == 6) { return 0xFFD400; } // yellow
        if (i == 7) { return 0xFFFFFF; } // white
        if (i == 8) { return 0x000000; } // black
        return 0xFF0000;                 // red (0, default)
    }

    // ---- property helpers ----
    private function propNum(app, key as Lang.String, def as Lang.Number) as Lang.Number {
        var v = app.getProperty(key);
        return (v == null) ? def : v.toNumber();
    }
    private function propBool(app, key as Lang.String, def as Lang.Boolean) as Lang.Boolean {
        var v = app.getProperty(key);
        return (v == null) ? def : v;
    }
}
