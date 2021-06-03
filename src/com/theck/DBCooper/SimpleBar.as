/**
 * ...
 * @author theck
 * 
 * Much of this adapted from BooBars
 */

 
//import com.theck.Utils.Debugger;
import flash.geom.Matrix;
//import caurina.transitions.Tweener;
import com.Utils.Text;

class com.theck.DBCooper.SimpleBar
{
	private var debugMode:Boolean = false;
	private var debugPrefix:String = "DBC.SB: ";
	
	private var m_frame:MovieClip;
	private var m_bar:MovieClip;
	private var m_stackbox:MovieClip;
	private var m_scaleFrame:MovieClip;
	private var m_scaleWidth:Number;
	private var m_leftText:TextField;
	private var m_rightText:TextField;	
	private var m_dragText:TextField;
	private var m_parent:MovieClip;
	public var barHeight:Number;
	
	
	private static var m_radius:Number = 4;
	//private static var rightTextWidth:Number = 70;
	//private static var leftTextWidth:Number = 20;
	
	public function SimpleBar(name:String, parent:MovieClip, x:Number, y:Number, width:Number, inFontSize:Number, colors:Array) 
	{
		var fontSize:Number = inFontSize;
		if (fontSize == null || fontSize < 6) {
			fontSize = 14;
			Debug("Fontsize defaulted to " + fontSize, debugMode);
		}
		if ( colors == null ) {
			colors = [0x2E2E2E, 0x585858];  // Grey
		}
		
		m_parent = parent;
		m_frame = m_parent.createEmptyMovieClip(name + "CastBarFrame", m_parent.getNextHighestDepth());
		m_scaleFrame = m_frame.createEmptyMovieClip(name + "ScaleFrame", m_frame.getNextHighestDepth());
		m_bar = m_scaleFrame.createEmptyMovieClip(name+"Bar", m_scaleFrame.getNextHighestDepth());
		m_stackbox = m_frame.createEmptyMovieClip(name+"StackBox", m_scaleFrame.getNextHighestDepth());
		
		m_frame._x = x;
		m_frame._y = y;
		
		var textFormat:TextFormat = new TextFormat("_StandardFont", fontSize, 0xFFFFFF, true);
		textFormat.align = "center";
		
		var extents:Object = Text.GetTextExtent("8", textFormat, m_frame);
		var height:Number = extents.height + extents.height * 0.05 + 4;
		barHeight = Math.ceil(height);
		
		var leftTextWidth:Number = Math.ceil( extents.width * 1.75 );
		
		// create the bar
		CreateBar2(m_bar, width, height, colors);
		
		// Create the background for the text field showing stacks
		DrawFilledRoundedRectangle(m_stackbox, 0x000000, 0, 0x750505, 100, -leftTextWidth-1, 0, leftTextWidth, height);
		
		// create the text field showing number of stacks
		m_leftText = m_frame.createTextField(name + "_leftText", m_frame.getNextHighestDepth(), -leftTextWidth-1, m_frame._height / 2 - extents.height / 2, leftTextWidth, extents.height);
		textFormat.align = "center";
		m_leftText.setNewTextFormat(textFormat);
		m_leftText.backgroundColor =  0x750505;	
		m_leftText.background = false;
		
		// create the text field over the bar for showing name or time
		m_rightText = m_frame.createTextField(name + "_rightText", m_frame.getNextHighestDepth(),  0, m_frame._height / 2 - extents.height / 2, m_bar._width, extents.height);
		textFormat.align = "right";
		m_rightText.setNewTextFormat(textFormat);	
		m_rightText.background = false;
		
		// SUPER HACKY - for some reason MovieClips don't seem to register clicks in GUIEdit mode, but TextFields do. 
		// So we make one big TextField over the whole bar for GUIEdit purposes.
		m_dragText = m_frame.createTextField(name + "_dragText", m_frame.getNextHighestDepth(), 0, 0, width, m_frame._height );		
		textFormat.align = "center";
		m_dragText.setNewTextFormat(textFormat);
		m_dragText.text = "Drag Me";
		m_dragText._visible = false;
		
		// Draw the rectangle for the background of the bar (shows when it isn't full)
		DrawFilledRoundedRectangle(m_frame, 0x000000, 2, 0x000000, 50, 0, 0, width, height);
		
		//do this after CreateBar, otherwise it doesn't have a width
		m_scaleWidth = m_scaleFrame._width;		
	}
	
	
	public function SetVisible(flag:Boolean):Void { 
		m_frame._visible = flag; 
		m_bar._visible = flag;		
	}
	
	public function GetVisible():Boolean { return m_frame._visible;	}
	
	
	public function GetCoords():Object
	{
		var pt:Object = new Object();
		pt.x = m_frame._x;
		pt.y = m_frame._y;
		return pt;
	}
		
	public function Unload():Void
	{
		m_frame.removeMovieClip();
		m_frame = null;
	}
	
	public function ShowDragText(state:Boolean) {
		m_dragText._visible = state;
		m_leftText._visible = !state;
		m_rightText._visible = !state;
	}
	
	public function Update(pct:Number, leftString:String, rightString:String):Void
	{
		Debug("SimpleBar: pct is " + pct, debugMode);
		if ( pct == null ) {
			Debug("SimpleBar: pct is " + pct, debugMode);
			SetVisible(false);
			m_scaleFrame._width = m_scaleWidth;
		}		
		else {
			SetVisible(true);
			
			// update strings if provided
			if ( leftString != null ) {
				m_leftText.text = leftString;
			}
			if ( rightString != null ) {
				m_rightText.text = rightString;
			}
			
			if ( pct > 1 ) { pct = 1 };
			
			// update percentage bar
			m_scaleFrame._width = ( m_scaleWidth * pct );
		}
	}
	
	public function SetRightText(rightString:String):Void
	{
		if ( rightString != null ) {
			m_rightText.text = rightString;
		}
	}
	
	// Functions shamelessly stolen from BooBars and adapted for my nefarious purposes
	
	private function CreateBar(name:String, width:Number, height:Number, colours:Array):MovieClip
	{
		var bar:MovieClip = m_scaleFrame.createEmptyMovieClip(name, m_scaleFrame.getNextHighestDepth());
		DrawGradientFilledRoundedRectangle(bar, 0x000000, 0, colours, 0, 0, width, height);
		return bar;
	}
	
	private function CreateBar2(bar:MovieClip, width:Number, height:Number, colours:Array)
	{
		DrawGradientFilledRoundedRectangle(bar, 0x000000, 0, colours, 0, 0, width, height);		
	}
	
	private function DrawGradientFilledRoundedRectangle(mc:MovieClip, lineColour:Number, lineWidth:Number, fillColours:Array, x:Number, y:Number, width:Number, height:Number):Void
	{
		var alphas:Array = [100, 100];
		var ratios:Array = [0, 245];
		var matrix:Matrix = new Matrix();
		var colors:Array = [0x2E2E2E, 0x1C1C1C];
		
		matrix.createGradientBox(width, height, 90 / 180 * Math.PI, 0, 0);
		mc.lineStyle(lineWidth, lineColour, 100, true, "none", "square", "round");
		if (ColourArrayValid(fillColours) != true)
		{
			mc.beginGradientFill("linear", colors, alphas, ratios, matrix);
		}
		else
		{
			mc.beginGradientFill("linear", fillColours, alphas, ratios, matrix);
		}

		mc.moveTo(x + m_radius, y);
		mc.lineTo(x + (width-m_radius), y);
		mc.curveTo(x + width, y, x + width, y + m_radius);
		mc.lineTo(x + width, y + (height - m_radius));
		mc.curveTo(x + width, y + height, x + (width - m_radius), y + height);
		mc.lineTo(x + m_radius, y + height);
		mc.curveTo(x, y + height, x, y + (height - m_radius));
		mc.lineTo(x, y + m_radius);
		mc.curveTo(x, y, x + m_radius, y);
		mc.endFill();
	}
	
	private function DrawFilledRoundedRectangle(mc:MovieClip, lineColour:Number, lineWidth:Number, fillColour:Number, fillAlpha:Number, x:Number, y:Number, width:Number, height:Number):Void
	{
		mc.lineStyle(lineWidth, lineColour, 100, true, "none", "square", "round");
		mc.beginFill(fillColour, fillAlpha);
		mc.moveTo(x + m_radius, y);
		mc.lineTo(x + (width-m_radius), y);
		mc.curveTo(x + width, y, x + width, y + m_radius);
		mc.lineTo(x + width, y + (height - m_radius));
		mc.curveTo(x + width, y + height, x + (width - m_radius), y + height);
		mc.lineTo(x + m_radius, y + height);
		mc.curveTo(x, y + height, x, y + (height - m_radius));
		mc.lineTo(x, y + m_radius);
		mc.curveTo(x, y, x + m_radius, y);
		mc.endFill();
	}
	
	private function ColourArrayValid(inColours:Array):Boolean
	{
		if (inColours == null)
		{
			Debug("colours null", debugMode);
			return false;
		}
		
		if ((inColours instanceof Array) != true)
		{
			Debug("colours not array", debugMode);
			return false;
		}
		
		if (inColours.length != 2)
		{
			Debug("colours not 2 long", debugMode);
			return false;
		}
		
		if (inColours[0] == null || inColours[1] == null)
		{
			Debug("colours contents null", debugMode);
			return false;
		}
		
		if (typeof(inColours[0]) != "number" || typeof(inColours[1]) != "number")
		{
			Debug("colours not number " + typeof(inColours[0]), debugMode);
			return false;
		}
		
		if (inColours[0] < 0 || inColours[0] > 0xFFFFFF)
		{
			Debug("colour 0 invalid number " + inColours[0], debugMode);
			return false;
		}
		
		if (inColours[1] < 0 || inColours[1] > 0xFFFFFF)
		{
			Debug("colour 1 invalid number " + inColours[1], debugMode);
			return false;
		}
		
		return true;
	}
	
	//////////////////////////////////////////////////////////
	// Debugging
	//////////////////////////////////////////////////////////
	
	private function Debug(text:String) {
		if debugMode { com.GameInterface.UtilsBase.PrintChatText(debugPrefix + text) };
	}
}