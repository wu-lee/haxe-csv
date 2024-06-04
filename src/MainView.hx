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

	@:bind(menuItemLoad, MouseEvent.CLICK)
	private function onMenuItemLoad(_) {
		loadFile({
			fullPath: "/home/nick/Downloads/2023.csv",
			name: "2023.csv"
		});
	}

	// @:bind(menuItemLoad, MouseEvent.CLICK)
	private function onMenuItemLoadxxx(_) {
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
		var headerIr = ComponentBuilder.fromFile("assets/column.xml");

		//var data = Assets.getText("assets/example.csv");
		//loadString(data);
		return;
	
		var dialog = new DownloadDialog();
		dialog.onDialogClosed = function(e:DialogEvent) {
			var url = "http://data.solidarityeconomy.coop/dotcoop/standard.csv";
			//trace("downloading "+url);
			//download(url);
		}
		dialog.showDialog();
	}

	private function download(url:String) {
		var http = new haxe.Http(url);

		http.onData = function(data:String) {
			trace("downloading "+url);
			NotificationManager.instance.addNotification({
				title: "Download ununsuccessful",
				body: "Error with " + url,
				type: NotificationType.Success
			});
			loadString(data);
		};
		http.onError = function(error:String) {
			NotificationManager.instance.addNotification({
				title: "Download unsuccessful",
				body: "Error with " + url+" - "+error,
				type: NotificationType.Error
			});
		}
		http.onStatus = function(status) {
			NotificationManager.instance.addNotification({
				title: "Status "+status,
				body: "Status is "+status,
				type: NotificationType.Info
			});
		}

		http.request();
	}

	// Defines how we generate a colum ID from its index
	private function colId(ix:Int) {
		return "c" + ix;
	}

	private function loadString(data:String) {
		trace("downloading "+data.substr(0,100));

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
