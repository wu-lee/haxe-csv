package ;

import haxe.ui.events.AppEvent;
import haxe.ui.HaxeUIApp;

class Main {
    public static function main() {
        var app = new HaxeUIApp();
        app.ready(function() {
            var mainView = new MainView();
            mainView.exit = (int:Int) -> {
                #if sys
                 Sys.exit(0);
                #else
                trace("platform does not support exiting");
                #end
            }
            app.addComponent(mainView);

            app.start();
        });
    }
}
