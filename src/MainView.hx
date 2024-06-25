package;

import haxe.ui.Toolkit;
import haxe.ui.events.EventType;
import haxe.ui.events.UIEvent;
import haxe.ui.containers.ListView;
import haxe.ui.geom.Rectangle;
import haxe.ui.geom.Point;
import haxe.ui.events.DragEvent;
import haxe.ui.dragdrop.DragManager;
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
		#if !sys
		// Hide the quit menu if we're not on a Sys platform, as it won't do anything
		menuItemQuit.hidden = true;
		#end
	}

	public dynamic function exit(value:Int):Void {}

	@:bind(menuItemLoadTest, MouseEvent.CLICK)
	private function onMenuItemLoadTest(_) {
		loadString(Toolkit.assets.getText("assets/example.csv"));
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

	@:bind(menuItemQuit, MouseEvent.CLICK)
	private function onMenuItemQuit(e) {
		exit(0);
	}

    @:bind(rootComponent, ColumnControlEvent.COLUMN_REVEAL)
    @:bind(rootComponent, ColumnControlEvent.COLUMN_HIDE)
	function onColumnHide(e:ColumnControlEvent) {
        var header = tv.header.getComponentAt(e.columnIndex);
        if (header == null)
            return;
        header.hidden = e.type == ColumnControlEvent.COLUMN_HIDE;
    }

	// Handles drag-end events re-emitted by the column control sidebar
	//
	// Works out where it insert, and does the insertion.
	@:bind(rootComponent, ColumnControlEvent.COLUMN_MOVE)
	function onDragEnd(e:ColumnControlEvent) {
        var draggedItem = e.sourceControl;
		var point:Point = new Point(draggedItem.screenLeft, draggedItem.screenTop);
        var draggedItemIx = draggedItem.preDragIndex;
		var components = findComponentsUnderPoint(point.x, point.y, ColumnControlItemRenderer);
		if (components.length <= 1)
			return; // We have no target item + target?
		
		var targetItem = cast(components[0], ColumnControlItemRenderer);
		var targetIx = columnControlList.getComponentIndex(targetItem);
		
		// Increment the index, unless we've been dragged right to the very top
		// This is so we insert *below* the target item.
		if (point.y > columnControlList.getComponentAt(0).screenTop)
			targetIx += 1;

		// Make sure we're not out of range.
		if (targetIx >= columnControlList.dataSource.size)
			targetIx = columnControlList.itemCount - 1;

		// Move the draggedItem below the target
		//trace("moving item " + columnControlList.getComponentIndex(draggedItem) + " to " + ix);
		columnControlList.setComponentIndex(draggedItem, targetIx);

        // Duplicate this in the TableView
        var draggedColumn = tv.header.getComponentAt(draggedItemIx);
        trace("dragged "+draggedColumn+" from "+draggedItemIx);
        if (draggedColumn != null) {
            tv.header.setComponentIndex(draggedColumn, targetIx);
            tv.invalidateComponentLayout();
        }
	}

	private var maxRedirections = 10;

	private function download(url:String, redirections:Int = 0) {
		var http = new haxe.Http(url);
		http.onError = function(error:String) {
			//			trace("error "+error); // DEBUG
			NotificationManager.instance.addNotification({
				title: "Download unsuccessful",
				body: "Error with " + url + " - " + error,
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

			download(location, redirections + 1);
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
		var columnControlData = new ArrayDataSource<Dynamic>();
		for (ix in 0...headers.length) {
			var header = headers[ix];
			{
				var col = tv.addColumn(header);
				col.sortable = true;
				col.id = colId(ix);
				col.autoWidth = true;
			}
			{
				// Add an item to the column list datasource
				columnControlData.add({columnHeader: header, id: "list" + colId(ix)});
			}
		}

		// Now reset the renderers for the columns.
		// We have to do this or the renderers won't be appropriate.
		// See https://community.haxeui.org/t/dynamic-tableview/299/6
		tv.itemRenderer.removeAllComponents();
		for (ix in 0...headers.length) {
			var header = headers[ix];

			{
				// Add a TableView column
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
		}
		tv.dataSource = ds;

		// Add a ListView column
		var ir = new ColumnControlItemRenderer();
		columnControlList.itemRenderer = ir;
		columnControlList.dataSource = columnControlData;
	}
}

class ColumnControlEvent extends UIEvent {
    public static final COLUMN_MOVE:EventType<ColumnControlEvent> = EventType.name("columnmove");
    public static final COLUMN_HIDE:EventType<ColumnControlEvent> = EventType.name("columnhide");
    public static final COLUMN_REVEAL:EventType<ColumnControlEvent> = EventType.name("columnreveal");
    public static final COLUMN_FILTER:EventType<ColumnControlEvent> = EventType.name("columnfilter");
    public static final COLUMN_UNFILTER:EventType<ColumnControlEvent> = EventType.name("columnunfilter");
 
    public var columnIndex:Int = -1;
    public var sourceControl:ColumnControlItemRenderer = null;

    public function new(
        type:EventType<ColumnControlEvent>,
        columnIndex:Int = -1,
        sourceControl:ColumnControlItemRenderer = null,
        bubble:Null<Bool> = false,
        data:Dynamic = null) {
        super(type, bubble, data);
        this.columnIndex = columnIndex;
        this.sourceControl = sourceControl;
    }

    public override function clone():ColumnControlEvent {
        var c:ColumnControlEvent = new ColumnControlEvent(this.type);
        c.data = this.data;
        c.type = this.type;
        c.target = this.target;
        c.columnIndex = this.columnIndex;
        c.sourceControl = this.sourceControl;
        postClone(c);
        return c;
    }
}

@:build(haxe.ui.ComponentBuilder.build("assets/column-control-item.xml"))
class ColumnControlItemRenderer extends ItemRenderer {
    public var preDragIndex:Int = -1;

	@:bind(visibleButton, MouseEvent.CLICK)
	function onVisibleClick(e) {
        var type = this.visibleButton.selected? 
            ColumnControlEvent.COLUMN_HIDE : ColumnControlEvent.COLUMN_REVEAL; 
        var event = new ColumnControlEvent(type, getIndex(), this);
        rootComponent.dispatch(event);
	}

	@:bind(filterButton, MouseEvent.CLICK)
	function onFilterClick(e) {
		filterText.hidden = !filterText.hidden;
        var type = this.filterButton.selected? 
            ColumnControlEvent.COLUMN_FILTER : ColumnControlEvent.COLUMN_UNFILTER;
        var event = new ColumnControlEvent(type, getIndex(), this);
        rootComponent.dispatch(event);
	}

	function onDragStart(e:DragEvent) {
        getIndex();
		moveComponentToFront();
	}

    function getIndex():Int {
        // There's a bit of magic know-how in getting our parent's parent!
        // Hope it never changes?
        return preDragIndex = this.parentComponent.parentComponent.getComponentIndex(this);
    }

	function onDragEnd(e:DragEvent) {
		// Work out where we were dropped
		if (e.data != null)
			return; // This event is intended for the root control

		var moveEvent = new ColumnControlEvent(ColumnControlEvent.COLUMN_MOVE, this);
		rootComponent.dispatch(moveEvent);
	}

	public override function onReady() {
		super.onReady();

		var bounds = parentComponent.screenBounds;
		registerEvent(DragEvent.DRAG_END, onDragEnd);
		registerEvent(DragEvent.DRAG_START, onDragStart);
		DragManager.instance.registerDraggable(this, {
			mouseTarget: this,
			dragBounds: new Rectangle(0, 0, bounds.width, bounds.height),
		});
	}

	private override function onDataChanged(data:Dynamic) {
		super.onDataChanged(data);
		if (data == null) {
			return;
		}

		columnControlHeader.text = data.columnHeader;
	}
}
