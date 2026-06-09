using Toybox.Application;
using Toybox.WatchUi;

class HypnosApp extends Application.AppBase {
    private var _view as HypnosView or Null;

    function initialize() { AppBase.initialize(); }
    function onStart(state) {}
    function onStop(state) {}

    function getInitialView() {
        _view = new HypnosView();
        return [ _view ];
    }

    function onSettingsChanged() {
        if (_view != null) { _view.reloadSettings(); }
        WatchUi.requestUpdate();
    }
}
