/*
* ...
* @author theck
*/

import com.GameInterface.Game.BuffData;
import com.Utils.ID32;
import com.theck.DBCooper.DBTargetData;
import com.theck.DBCooper.DBTargetManager;
import com.theck.DBCooper.SimpleBar;
import com.Utils.Archive;
import com.GameInterface.Game.Character;
import com.Utils.GlobalSignal;
import com.theck.Utils.Common;
import com.theck.DBCooper.ConfigManager;
import flash.geom.Point;
import mx.utils.Delegate;
import com.Utils.LDBFormat;
import com.GameInterface.Inventory;
import com.GameInterface.InventoryItem;

class com.theck.DBCooper.DBCooper
{
	
	static var debugMode:Boolean = false;
	static var debugPrefix:String = "DBC: ";
	
	// Version
	static var version:String = "0.5.1";
	
	private var m_swfRoot:MovieClip;	
	public  var clip:MovieClip;	
	public  var bar:SimpleBar;	
	static  var barColors:Array = [0xbb5814, 0xf7741a]; // [darker (top) lighter (bottom)]
	private var guiThrottle:Boolean = false;
	
	private var m_player:Character;
	private var m_inventory:Inventory;
	private var m_currentTarget:Character;
	
	private var TargetManager:DBTargetManager;
	
	private var combatUpdateInterval:Number; // interval variable for updating during combat
	static var POLLING_INTERVAL:Number = 50; // ms update interval
	
	private var Config:ConfigManager;
	
	public function DBCooper(swfRoot:MovieClip){
		Debug("constructor called")
		
        m_swfRoot = swfRoot;
		m_player = Character.GetClientCharacter();
		m_currentTarget = null;
		
		Config = new ConfigManager();
		Config.NewSetting("fontsize", 16, "");
		Config.NewSetting("width", 250, "");
		
		clip = m_swfRoot.createEmptyMovieClip("DBCooper", m_swfRoot.getNextHighestDepth());
		
		clip._x = Stage.width /  2;
		clip._y = Stage.height / 2;	
		
		Config.NewSetting("position", new Point(clip._x, clip._y), "");
		
		TargetManager = new DBTargetManager( m_player.GetID() );		
	}

	public function Load(){
		
		com.GameInterface.UtilsBase.PrintChatText("DBCooper v" + version + " Loaded");
		m_inventory = new Inventory(new ID32(_global.Enums.InvType.e_Type_GC_WeaponContainer, Character.GetClientCharacter().GetID().GetInstance()));

		
		// connect signals here
		GlobalSignal.SignalSetGUIEditMode.Connect(GuiEdit, this);
		m_inventory.SignalItemAdded.Connect(OnWeaponChange, this);
		Config.SignalValueChanged.Connect(SettingChanged, this);
	}

	public function Unload(){
		
		// disconnect signals here
		GlobalSignal.SignalSetGUIEditMode.Disconnect(GuiEdit, this);
		m_inventory.SignalItemAdded.Disconnect(OnWeaponChange, this);
		Config.SignalValueChanged.Disconnect(SettingChanged, this);
	
	}
	
	public function Activate(config:Archive){
		Debug("Activate()");
		
		Config.LoadConfig(config);
		
		// create the bar
		CreateBar();
		
		// Move clip to location
		SetPos( Config.GetValue("position") );
		
		// run once to connect signals on load if Shotgun is equipped
		OnWeaponChange();
		
		// do some sanity checking in case we reloadui in combat
		if (  m_player.IsInCombat() && m_player.GetOffensiveTarget() ) {
			
			// set the current target to the player's target
			m_currentTarget = Character.GetCharacter(m_player.GetOffensiveTarget());
			
			// call functions that hook up signals
			OnCharacterOffensiveTargetChanged( m_currentTarget.GetID() );
			OnToggleCombat( m_player.IsInCombat() );
		}
	}

	public function Deactivate():Archive{
		var config = new Archive();
		config = Config.SaveConfig();
		return config;
	}
	
	//////////////////////////////////////////////////////////
	// GUI Functions
	//////////////////////////////////////////////////////////
	
	private function CreateBar() {
		Debug("CreateBar()");
		
		var fontSize:Number = Config.GetValue("fontsize");
		var width:Number = Config.GetValue("width");
		
		// nuke any old bar (hopefully?)
		bar.SetVisible(false);
		bar = undefined;
		
		// create a new one. Note position is (0,0) since location on screen is controlled by clip
		bar = new SimpleBar("DBBar", clip, 0, 0, width, fontSize, barColors);
		bar.Update(0.50, "0", "Bar Initialized");
		
		// hide on creation if no shotgun is equipped
		bar.SetVisible(IsShotgunEquipped());
	}
	
	private function SettingChanged(key:String) {
		Debug("ReCreateBar()");
		
		if ( key != "position" ) {
			// for when settings are updated. Create bar
			CreateBar();		
			
			// Move clip to location
			SetPos( Config.GetValue("position") );
		}
	}
		
	public function SetPos(pos:Point) {
		
		// sanitize inputs - this fixes a bug where someone changes screen resolution and suddenly the field is off the visible screen
		if ( pos.x > Stage.width || pos.x < 0 ) { pos.x = Stage.width / 2; }
		if ( pos.y > Stage.height || pos.y < 0 ) { pos.y = Stage.height / 2; }
		
		// set position
		clip._x = pos.x;
		clip._y = pos.y;
	}
	
	public function GetPos():Point {
		var pos:Point = new Point(clip._x, clip._y);
		Debug("GetPos: x: " + pos.x + "  y: " + pos.y, debugMode);
		return pos;
	}
	
	public function BarStartDrag() {
		Debug("BarStartDrag called");
        clip.startDrag();
    }

    public function BarStopDrag() {
		Debug("BarStopDrag called");
        clip.stopDrag();
		
		// grab position for config storage on Deactivate()
		var b_pos:Point = Common.getOnScreen(clip);
        Config.SetValue("position", b_pos ); 
		
		Debug("barStopDrag: x: " + b_pos.x + "  y: " + b_pos.y);
    }
	
	public function EnableInteraction(state:Boolean) {
		clip.hitTestDisable = !state;
		bar.ShowDragText(state);
		//bar.hitTestDisable = !state;
	}
	public function ToggleBackground(flag:Boolean) {
		clip.background = flag;
	}
	
	private function SetVisible(flag:Boolean) {
		clip.SetVisible(flag);
		bar.SetVisible(flag);
	}
	
	public function GuiEdit(state:Boolean) {
		
		EnableInteraction(state);
		ToggleBackground(state);
		SetVisible(state);
		
		if (state) {
			//Debug("GuiEdit true case");
			clip.onPress = Delegate.create(this, BarStartDrag);
			clip.onRelease = Delegate.create(this, BarStopDrag);
			
			// set throttle variable - this prevents extra spam when the game calls GuiEdit event with false argument, which it seems to like to do ALL THE DAMN TIME
			guiThrottle = true;
		}
		else if guiThrottle {
			//Debug("GuiEdit false case");
			clip.stopDrag();
			clip.onPress = undefined;
			clip.onRelease = undefined;
		}
		
		// set throttle variable
		guiThrottle = false;
		setTimeout(Delegate.create(this, ResetGuiThrottle), 100);
	}
	
	private function ResetGuiThrottle() {
		guiThrottle = true;
	}
	
	private function UpdateBarVisibility() {		
		SetVisible(TargetManager.TargetHasDB(m_currentTarget.GetID() ) ); 
	}
	
	//////////////////////////////////////////////////////////
	// Core Logic
	//////////////////////////////////////////////////////////
	
	private function UpdateCurrentTarget( charID:ID32 ) {
		// disconnect old signals
		if ( m_currentTarget ) {
			ConnectTargetingSignals();
		}
		
		// update m_currentTarget
		m_currentTarget = Character.GetCharacter(charID);
		
		// connect new signals	
		if ( m_currentTarget ) {
			DisconnectTargetingSignals();
		}
	}
	
	private function UpdateBar() {
		if TargetManager.TargetHasDB(m_currentTarget.GetID() ) {
			
			// display bar
			SetVisible(true);
			
			// various things possible to display
			var entry:DBTargetData = TargetManager.GetTargetEntry( m_currentTarget.GetID() );
			
			// remaining time (needed for bar pct)
			var timeRemaining:Number = entry.StackExpireTime() - getTimer();
			var pct:Number = timeRemaining / 5000;
			
			// display time
			var timeDisplay:String;
			timeDisplay = FormatTimeText (timeRemaining ) + " s";
						
			// target name
			var name:String = m_currentTarget.GetName();
		
			// only update it the remaining time is > 0
			// otherwise weird stuff happens b/c pct is < 0
			if ( timeRemaining > 0 ) {		
				bar.Update(pct, String(entry.Stacks()), timeDisplay );
			}
		}
		else {
			// hide bar if target doesn't have DB
			SetVisible(false);
		}
	}
	
	private function IsShotgunEquipped():Boolean {
		return ( m_inventory.GetItemAt(_global.Enums.ItemEquipLocation.e_Wear_First_WeaponSlot).m_Type == 1088 || m_inventory.GetItemAt(_global.Enums.ItemEquipLocation.e_Wear_Second_WeaponSlot).m_Type == 1088 );

	}
	
	//////////////////////////////////////////////////////////
	// Signal Handling
	//////////////////////////////////////////////////////////
	
	private function OnCharacterOffensiveTargetChanged(charID:ID32):Void {
		Debug("OnTargetChanged");
		
		// Note: charID > 0 always evaluates to "false" and ( charID) always evaluates to true
		// instead, make sure we conditionalize based on GetCharacter(charID) calls
		
		// if the target isn't nothing, update the currentTarget variable
		if ( Character.GetCharacter(charID) ) {
			Debug("updated m_currentTarget");
			UpdateCurrentTarget( charID );
		
			// add this entry to TargetManager (or update it)
			TargetManager.NewTarget(charID);
			
			// if the target already has an active DB
			if ( TargetManager.TargetHasDB(charID) ) 
			{
				// show display and update
				UpdateBar();
				SetVisible(true);
				
			}
			else {				
				// hide display
				SetVisible(false);
			}
		}
	}
	
	private function OnTargetBuffSignal(buffId:Number) {
		
		setTimeout(Delegate.create(this, UpdateBarVisibility), 50 );
	}
	
	private function OnToggleCombat(state:Boolean) {
		//Debug("OnToggleCombat");
		if ( state ) {
			// start periodic updates
			combatUpdateInterval = setInterval(Delegate.create(this, UpdateBar), POLLING_INTERVAL);	
		
			// add the current target entry to TargetManager (or update it)
			if ( m_currentTarget.GetID() ) {
				TargetManager.NewTarget (m_currentTarget.GetID() );
			}
			
		}
		else {
			// stop periodic updates
			clearInterval(combatUpdateInterval);
			
			// hide bar
			SetVisible(false);
		}
		
	}
	
	private function OnWeaponChange() {
		//Debug("OnWeaponChange");
		//Debug("Shotgun is " + IsShotgunEquipped() );
		if IsShotgunEquipped() {
			// connect signals
			m_player.SignalOffensiveTargetChanged.Connect(OnCharacterOffensiveTargetChanged, this);
			m_player.SignalToggleCombat.Connect(OnToggleCombat, this);
		}
		else {
			// disconnect signals
			m_player.SignalOffensiveTargetChanged.Disconnect(OnCharacterOffensiveTargetChanged, this);
			m_player.SignalToggleCombat.Disconnect(OnToggleCombat, this); 
		}
	}
	
	private function ConnectTargetingSignals() {
		m_currentTarget.SignalBuffAdded.Disconnect(OnTargetBuffSignal, this);
		m_currentTarget.SignalBuffUpdated.Disconnect(OnTargetBuffSignal, this);
		m_currentTarget.SignalBuffRemoved.Disconnect(OnTargetBuffSignal, this);
	}
	
	private function DisconnectTargetingSignals() {
		m_currentTarget.SignalBuffAdded.Connect(OnTargetBuffSignal, this);
		m_currentTarget.SignalBuffUpdated.Connect(OnTargetBuffSignal, this);
		m_currentTarget.SignalBuffRemoved.Connect(OnTargetBuffSignal, this);
	}
	
	//////////////////////////////////////////////////////////
	// String Formatting
	//////////////////////////////////////////////////////////
	
	private function FormatTimeText(time:Number):String {
		
		var outputText:String;
		
		var secs = Math.floor( ( time / 1000 ) );
		var dsecs = Math.floor( ( time - 1000 * secs ) / 100 );
		
		var secsString:String;
		var dsecsString:String;
		
		secsString = secs.toString();
		dsecsString = dsecs.toString();
		
		outputText = secsString + "." + dsecsString;
		return outputText;
	}
	
	//////////////////////////////////////////////////////////
	// Debugging
	//////////////////////////////////////////////////////////
	
	private function Debug(text:String) {
		if debugMode { com.GameInterface.UtilsBase.PrintChatText(debugPrefix + text) };
	}
	
	private function DEBUG_PrintDebuffsOnPlayer(char:Character) {
		
		// verbose debugging - report all debuffs
		var buffString:String = " ";
		for ( var j in char.m_BuffList ) {
			buffString += LDBFormat.LDBGetText( 50210, Number(j) ) + " (" + j + "), ";
		}
		Debug("DEBUG_PrintDebuffsOnPlayer(): debuff list for " + char.GetName() + ": " + buffString, true );
		
		
		buffString = " ";
		for ( var j in char.m_InvisibleBuffList ) {
			buffString += LDBFormat.LDBGetText( 50210, Number(j) ) + " (" + j + "), ";
		}
		Debug("DEBUG_PrintDebuffsOnPlayer(): invisible debuff list for " + char.GetName() + ": " + buffString, true );
	}
	
	private function DebugDumpObjectProperties(temp:Object) {
		for ( var prop in temp ) { 
			Debug("DDOP: Property " + prop + " has the value " + temp[prop]); 				
		} 
	}
}