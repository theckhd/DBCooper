/**
 * ...
 * @author theck
 */

import com.GameInterface.Game.BuffData;
import com.GameInterface.Game.Character;
import com.Utils.ID32;
import com.Utils.LDBFormat;
 
 
 class com.theck.DBCooper.DBTargetData
{
	
	static var debugMode:Boolean = false;
	static var debugPrefix:String = "DBTD: ";
	
	private var player:ID32;
	public var target:ID32;
	public var name:String;
	
	private var stacks:Number;
	private var stackExpireTime:Number;
	private var targetExpireTime:Number;
	
	static var DB_DEBUFF_ID:Number = 9255644; // Dragon's Breath debuff w/o passive
	static var DB_DEBUFF_ID_2:Number = 9267971; // Dragon's Breath debuff w/ passive
	
	public function DBTargetData(target_in:ID32, player_in:ID32)
	{
		// store player and target IDs
		player = player_in;
		target = target_in;
		
		// initialize these values to -1 to indicate they haven't been set
		stacks = -1;
		stackExpireTime = -1;
		
		// default to a 30-second expire time for the target entry
		targetExpireTime = getTimer() + 30000;
		
		// connect signals
		var tar:Character = Character.GetCharacter(target);
		name = tar.GetName();
		tar.SignalBuffUpdated.Connect(OnBuffUpdate, this);
		tar.SignalCharacterDied.Connect(OnCharacterDied, this);
		//tar.SignalCharacterDestructed.Connect(OnCharacterDied, this);
		
	}
	
	private function OnBuffUpdate(buffId:Number) {		
		UpdateOnBuffSignal(buffId);	
		//DebugDumpObjectProperties(Character.GetCharacter(target).m_BuffList[buffId]);	
	}
	
	private function OnCharacterDied() {
		Debug("Died: " + target.m_Instance + "(" + name + ")");
		// can disconnect all signals now
		var tar:Character = Character.GetCharacter(target);
		tar.SignalBuffUpdated.Disconnect(OnBuffUpdate, this);
		tar.SignalCharacterDied.Disconnect(OnCharacterDied, this);
		//tar.SignalCharacterDestructed.Disconnect(OnCharacterDied, this);
		// set stacks to zero for early clean-up
		stacks = 0;
		targetExpireTime = getTimer() + 1000;
	}
	
	public function UpdateOnBuffSignal(buffId:Number) {

		//Debug("UOBS: " + target.m_Instance);
		//DebugDumpTargetData("before");

		if ( IsDragonsBreath(buffId) ) {
			
			// grab buff data quickly
			var buff:BuffData = Character.GetCharacter(target).m_BuffList[buffId];
			
			// check that it belongs to the player
			if (buff.m_CasterId == player.m_Instance) {
				
				// yay! it's ours. Update the entry with the new information
				stacks = buff.m_Count;
				stackExpireTime = getTimer() + buff.m_RemainingTime;
				targetExpireTime = getTimer() + buff.m_RemainingTime * stacks + 10000;
			}			
		}
		DebugDumpTargetData("UOBS");
	}
	
	// this Update() gets called when something in the database is re-targeted
	public function Update() {
		//Debug("Update(): t=" + getTimer() + ", entry=" + target.m_Instance + " (" + name + ")" );
		//DebugDumpTargetData("before");
		
		// Ugly awful hack Warning. 
		// For some reason, two bosses (HR5 and DW5) go immune for short periods and somehow disconnect their signals. 
		// No idea why, with HR5 it consistently happens after two Triggerthings are targeted. 
		// Didn't test DW5 in detail after implementing this "fix"
		
		// Every time we retarget something that's already in the database, we'll reconnect the signals.
		// This seems to fix the issue with those two bosses and doesn't seem to break anything else, so :shrug:
		// End Ugly Awful Hack
		var tar:Character = Character.GetCharacter(target);
		tar.SignalBuffUpdated.Connect(OnBuffUpdate, this);
		tar.SignalCharacterDied.Connect(OnCharacterDied, this);
		
		var time:Number = getTimer();
		
		// update the number of stacks and stack expire estimate
		while ( stacks > 1 && time > stackExpireTime ) {
			stackExpireTime += 5000;
			targetExpireTime += 5000;
			stacks--;
		}
		
		// if this takes us down to 1 stack and that stack should have expired, set to zero
		if ( stacks == 1 && time > stackExpireTime ) {
			Debug("Update(): " + name + " stacks set to zero");
			stacks = 0;
		}
		//DebugDumpTargetData("Update()");
	}
	
	public function Stacks():Number {
		return stacks;
	}
	
	public function StackExpireTime():Number {
		return stackExpireTime;
	}
	
	public function TargetExpireTime():Number {
		return targetExpireTime;
	}
	
	public function IsDragonsBreath(buffId:Number):Boolean {
		
		return ( buffId == DB_DEBUFF_ID || buffId == DB_DEBUFF_ID_2 );
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
	
	
	private function DebugDumpTargetData(str:String) {
		Debug(str + " (" + target.m_Instance +", " + name + "): t=" + getTimer() + ", stacks = " + stacks + ", sET = " + stackExpireTime + ", tET = " + targetExpireTime );
	}
}