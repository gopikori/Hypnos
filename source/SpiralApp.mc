using Toybox.Application;
using Toybox.WatchUi;

class SpiralApp extends Application.AppBase {
    private var _view as SpiralView or Null;

    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}

    function getInitialView() {
        _view = new SpiralView();
        return [ _view ];
    }

    function onSettingsChanged() {
        if (_view != null) { _view.reloadSettings(); }
        WatchUi.requestUpdate();
    }
}
