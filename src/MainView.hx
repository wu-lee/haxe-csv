package;

//import openfl.Assets;
import haxe.ui.ComponentBuilder;
import haxe.ui.notifications.NotificationType;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.containers.dialogs.Dialog.DialogEvent;
import haxe.ui.components.Label;
import haxe.ui.core.ItemRenderer;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.VBox;
import haxe.ui.events.MouseEvent;
import haxe.ui.containers.dialogs.Dialogs;
import format.csv.Reader;



@:build(haxe.ui.ComponentBuilder.build("assets/main-view.xml"))
class MainView extends VBox {
	public function new() {
		super();
	}

	@:bind(menuItemLoadTest, MouseEvent.CLICK)
	private function onMenuItemLoadTest(_) {
		loadFile({
			fullPath: "/home/nick/Downloads/2023.csv",
			name: "2023.csv"
		});
	}

	@:bind(menuItemLoad, MouseEvent.CLICK)
	private function onMenuItemLoad(_) {
		Dialogs.openFile(function(button, selectedFiles) {
			if (button == DialogButton.OK) {
				loadFile(selectedFiles[0]);
			}
		}, {
			readContents: false,
			title: "Open File",
			readAsBinary: false,
			extensions: [{extension: 'csv', label: 'CSV'}],
		});
	}

	@:bind(menuItemDownload, MouseEvent.CLICK)
	private function onMenuItemDownload(e) {
		var dialog = new DownloadDialog();
		dialog.onDialogClosed = function(e:DialogEvent) {
			download(dialog.url.text);
		}
		dialog.showDialog();
	}

	private var maxRedirections = 10;
	private function download(url:String, redirections:Int = 0) {
		var http = new haxe.Http(url);
		http.onError = function(error:String) {
//			trace("error "+error); // DEBUG
			NotificationManager.instance.addNotification({
				title: "Download unsuccessful",
				body: "Error with " + url+" - "+error,
				type: NotificationType.Error
			});
		}

		http.onStatus = function(status:Int) {
//			trace("status "+status); // DEBUG
			if (status == 200) {
				http.onData = function(data:String) {
//					trace("data "+data.substr(0,100)); // DEBUG
					loadString(data);
				};
				return;	
			}
			if (status < 300 || status >= 400)
				return;

			if (redirections > maxRedirections) {
				return; // FIXME handle?
			}
			var location = http.responseHeaders["Location"];
			if (location == null)
				return;

			download(location, redirections+1);
		}

//		trace((redirections > 0? 'redirection $redirections to ' : "downloading ")+url); // DEBUG
		http.request();
	}

	// Defines how we generate a colum ID from its index
	private function colId(ix:Int) {
		return "c" + ix;
	}

	private function loadString(data:String) {
		var reader = new Reader();
		reader.open(data);
		load(reader);
	}

	private function loadFile(file:SelectedFileInfo) {
		trace("load " + file.name);
		this.topComponent.screen.title = file.name;

		#if sys
		var stream = sys.io.File.read(file.fullPath, false);
		var reader = new Reader();
		reader.open(stream);
		load(reader);
		#end
	}

	private function load(reader:Reader) {
		// Populate a new datasource and headers array from the CSV first
		var headers:Array<String> = null;
		var ds = new ArrayDataSource<Dynamic>();
		for (record in reader) {
			if (headers == null) {
				headers = record;
				continue;
			}
			// We're forced by TableView's implementation to use anonymous objects and reflection
			// rather than the probably preferable StringMap
			var item:Dynamic = {};
			for (ix in 0...record.length) {
				var header = headers[ix];
				Reflect.setField(item, colId(ix), record[ix]);
			}
			ds.add(item);
		}

		// Now add the headers we found as table columns
		tv.virtual = true;
		tv.clearContents(true);
		for (ix in 0...headers.length) {
			var header = headers[ix];
			var col = tv.addColumn(header);
			col.sortable = true;
			col.id = colId(ix);
			col.autoWidth = true;
		}


		// Now reset the renderers for the columns.
		// We have to do this or the renderers won't be appropriate.
		// See https://community.haxeui.org/t/dynamic-tableview/299/6
		tv.itemRenderer.removeAllComponents();
		for (ix in 0...headers.length) {
			var header = headers[ix];

			var ir = new ItemRenderer();
			var label = new Label();
			label.percentWidth = 100;
			label.verticalAlign = "center";
			label.id = colId(ix);
			label.autoHeight = false;
			label.clip = true;
			label.wordWrap = false;
			label.onChange = (e) -> {
				e.target.tooltip = e.target.value;
			};
			ir.addComponent(label);
			tv.itemRenderer.addComponent(ir);
		}
		tv.dataSource = ds;
	}

}
