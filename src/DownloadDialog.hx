import haxe.ui.notifications.NotificationType;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.containers.dialogs.Dialog;


using haxe.ui.animation.AnimationTools;

@:build(haxe.ui.macros.ComponentMacros.build("assets/download-dialog.xml"))
class DownloadDialog extends Dialog {
    public function new() {
        super();
        buttons = DialogButton.CANCEL | "Download";
        defaultButton = "Download";
    }
    
    public override function validateDialog(button:DialogButton, fn:Bool->Void) {
        var valid = true;
        if (button == "Download") {
            if (url.text == "" || url.text == null) {
                url.flash();
                valid = false;
            }

            if (valid == false) {
                NotificationManager.instance.addNotification({
                    title: "Invalid URL",
                    body: "There input value is not a valid URL.",
                    type: NotificationType.Error
                });
                this.shake();
            } else {
                NotificationManager.instance.addNotification({
                    title: "Download successful",
                    body: "Success with " + url.text,
                    type: NotificationType.Success
                });
            }
        }
        fn(valid);
    }
}