/**
 * ...
 * @author theck
 */

 
import com.theck.DBCooper.DBTargetData;
import com.GameInterface.Game.Character;
import com.Utils.ID32;
import com.Utils.LDBFormat;
import mx.utils.Delegate;
 
class com.theck.DBCooper.DBTargetManager
{
	
	static var debugMode:Boolean = false;
	static var debugPrefix:String = "DBTM: ";
	
	private var TargetList:Object;
	private var player:Character;
	
	private var combatUpdateInterval:Number; // interval variable for updating during combat
	static var POLLING_INTERVAL:Number = 2000; // ms update interval
	
	
	public function DBTargetManager(player_in:ID32) 
	{
		TargetList = new Object();
		player = Character.GetCharacter(player_in);
		
		player.SignalToggleCombat.Connect(OnToggleCombat, this);
		
	}
	
	public function AddTarget(target:ID32) {
		Debug("Target added: " + target.m_Instance + " " + Character.GetCharacter(target).GetName() );
		var entry:DBTargetData = new DBTargetData( target, player.GetID() );
		TargetList[target] = entry;
	}
	
	public function RemoveTarget(target:ID32) {
		if ( TargetList[target] ) {
			delete TargetList[target];
		}		
	}
	
	public function NewTarget(target:ID32) {
		//Debug("target: " + target.m_Instance + " " + Character.GetCharacter(target).GetName());
		if ( target ) {
			if ( TargetList[target] ) {
				Debug("Target updated: " + target.m_Instance + " " + Character.GetCharacter(target).GetName() );
				TargetList[target].Update();			
			}
			else {
				AddTarget(target);
			}
		}
	}
	
	private function MaintainTargetList() {
		var time:Number = getTimer();
		//Debug("MTL: t=" + time + ", size=" + DatabaseLength() );
		
		// cycle through list and remove expired entries 
		for ( var i in TargetList ) {
			
			// never remove current target - this prevents weirdness caused by leaving and re-entering
			// combat while maintaining a target
			if ( i != String(player.GetOffensiveTarget() ) ) {
				
				// remove entries where the stacks should have expired
				if ( TargetList[i].stacks <= 1 && TargetList[i].stackExpireTime > 0 && TargetList[i].stackExpireTime < time ) {
					Debug("MTL: t=" + getTimer() + ", Entry " + i + " (" + TargetList[i].name + ")" + " removed due to stack expiration, current target is " + player.GetOffensiveTarget() );
					delete TargetList[i];
				}
				
				// remove entries where the target never gained stacks
				else if ( TargetList[i].targetExpireTime < time ) {
					Debug("MTL: t=" + getTimer() + ", Entry " + i + " (" + TargetList[i].name + ")" + " removed due to target expiration, current target is " + player.GetOffensiveTarget() );
					delete TargetList[i];
				}
			}
		}
	}
	
	public function ContainsTarget(target:ID32) {
		if ( TargetList[target] ) {
			return true;
		}
		return false;
	}
	
	public function TargetHasDB(target:ID32) {
		if ( ContainsTarget(target) ) {
			
			//necessary b/c there is no unique indication of when a buff drops to 0 stacks
			TargetList[target].Update(); 
			
			//Debug("Stacks: " + TargetList[target].Stacks());
			return ( TargetList[target].Stacks() > 0 )
		}
		return false;
	}
	
	public function GetTargetEntry(target:ID32):DBTargetData {
		if ( TargetList[target] ) { return TargetList[target]; }
	}
	
	private function OnToggleCombat(state:Boolean) {
		Debug("OnToggleCombat");
		if ( state ) {
			// start cleanup interval
			combatUpdateInterval = setInterval(Delegate.create(this, MaintainTargetList), POLLING_INTERVAL);	
		}
		else {
			// clear interval
			clearInterval(combatUpdateInterval);
			
			// schedule list destruction
			setTimeout(Delegate.create(this, ClearTargetEntryList), 5000);
		}		
	}
	
	private function ClearTargetEntryList() {
		
		// only do this if we're not in combat (in case we've re-entered combat since scheduling this call
		if ( !player.IsInCombat() ) {
			
			// delete entire list
			for ( var i in TargetList ) {
				delete TargetList[i];
			}
		}
	}
	
	private function DatabaseLength():Number {
		var count:Number = 0; 
		var key:String; 

		for (key in TargetList)
		{ 
			count++; 
		}
		return count;
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