(
/* ===========================================

TX Image Synth App   (TXImageSynthApp.scd)

INTRO:
This code is a SuperCollider app for generating sounds based on images used as sonograms.
Images can be created by analysing a sound file, by importing an existing image file,
or by drawing coloured lines or shapes using the image tools provided.
Image files can be saved or imported.
The sonogram image can be synthesised using filtered noise, sine waves, phase modulation synthesis or wavetable synthesis.
EQ, frequency warping, time stretching, delay and reverb can be added.
Recordings can be saved as Sound files.
Project files, containing images and settings, can be saved.

Created by Paul Miller (palemoonrising.co.uk)

LICENSE: GNU GPL 3 license as per SuperCollider

BEFORE STARTING:
Download and install SuperCollider (https://supercollider.github.io)
Download and install SC3-plugins (https://supercollider.github.io/SC3-plugins)

TO START APP:
Open this file (TXImageSynthApp.scd) from inside SuperCollider with SC3-plugins installed.
Select the whole document - press Cmd+A (MacOS) / Ctrl+A (Win).
Evaluate the code - press Shift+Return.
Once the app starts, click on the Help button to open the Help Window.

THANKS:
This app was developed from code originally shared by PyoungRyang Ko on SuperCollider Forum thread:
https://scsynth.org/t/a-sketch-to-make-an-image-filter-similar-to-the-image-filter-in-audiosculpt/10317
The Perlin Noise code was adapted from the Simplex Noise sc quark, which was ported
to SuperCollider by Glen Fraser from original code by Stefan Gustavson.
Big thanks to all who share their code.

===========================================*/

// init

// V1 for normal use
/* V1 data dictionary variable d is local */
var d;
d = ();   // data dict
d.guiData = ();
// end of V1

// V2 used for building and testing
/* V2 data dictionary uses Interpreter variable d
if (d.isNil or: {d.class != Event}, {
	d = ();   // data dict
	d.guiData = ();
});
*/
// end of V2

// ============  Settings (initial values):  ============
d.fInitSettings = {
	Font.default = Font("Helvetica", 12);
	d.audioOutBus = 0;
	d.volume = 0.2;
	d.minPlayLength = 0.1;
	d.maxPlayLength = 600;
	d.playLength = 8;  // seconds, range: minPlayLength - maxPlayLength
	d.imageWidthSpec = ControlSpec(48, 1200, step: 1);
	d.imageHeightSpec = ControlSpec(12, 240, step: 1);
	d.imageWidth = 480;  // = number of time pixels
	d.imageHeight = 64;  // = number of freqs
	d.pixelWidth = 2;
	d.pixelHeight = 2;
	d.stretchImageOnResize = true;
	d.randSeed = 12345;
	d.freqModeOptions = [
		["MIDI Note Semitones (12 pitches per octave)", 'midiSemi'],
		["MIDI Note Quartertones (24 pitches per octave)", 'midiQuarter'],
		["MIDI Note Scale with Tuning (12 pitches per octave)", 'midiScale'],
		["All Harmonics (more freqs in higher octaves)", 'harm'],
		["Even Harmonics (more freqs in higher octaves)", 'harmEven'],
		["Odd Harmonics (more freqs in higher octaves)", 'harmOdd'],
		["Exponentially-Spaced (freqs spread evenly in octaves)", 'exp'],
		["Linearly-Spaced  (more freqs in higher octaves)", 'lin'],
	];
	d.freqModeShortNames = [
		["MIDI Note Semitones", 'midiSemi'],
		["MIDI Note Quartertones", 'midiQuarter'],
		["MIDI Note Scale with Tuning", 'midiScale'],
		["All Harmonics", 'harm'],
		["Even Harmonics", 'harmEven'],
		["Odd Harmonics", 'harmOdd'],
		["Exponentially-Spaced Frequencies", 'exp'],
		["Linearly-Spaced Frequencies", 'lin'],
	];
	d.freqMode = 'midiSemi';

	// only used for freqModes 'lin' or 'exp':
	d.freqRangeSpec = ControlSpec(20, 20000, 3);
	d.minFreq = 60;
	d.maxFreq = 6000;

	// only used for freqModes 'midiQuarter, 'midiSemi', 'midiScale', 'harm', 'harmEven', 'harmOdd':
	d.midiNoteRangeSpec = ControlSpec(16, 135, 'exp');
	// 135.midicps.asInteger; // = 19912
	// 16.midicps.ceil.asInteger; // = 21
	d.midiNoteLowest = 24;
	// NOTE: midiScale must be valid for midiPitchesPerOctave
	// and midiTuning must be valid for midiScale, use .checkTuningForMismatch
	d.midiPitchesPerOct = 12;
	d.midiScale = 'chromatic';
	d.midiTuning = 'et12';
	d.midiPlayNote = 60;
	d.playNoiseMix = 0.5;
	d.globalDetuneCentsSpec = ControlSpec(-100, 100);
	d.globalDetuneCents = 0;
	d.detunedCopiesSpec = ControlSpec(0, 4);
	d.detunedCopies = 0;
	d.detuneFirstVoice = false;
	d.copyRandDetuneCentsSpec = ControlSpec(0.01, 10, 4);
	d.copyRandDetuneCents = 0.2;

	// amplitude compensation
	d.ampCompOptions = [ // amp compensation
		["Off", 'off',
			{arg event, freq; 1;}
		],
		["A-weighted amp compensation, minAmp: 0.75", 'aWeighted75',
			{arg event, freq; AmpCompA.ir(freq.max(60), 60, 0.75);}
		],
		["A-weighted amp compensation, minAmp: 0.6", 'aWeighted60',
			{arg event, freq; AmpCompA.ir(freq.max(60), 60, 0.6);}
		],
		["A-weighted amp compensation, minAmp: 0.5", 'aWeighted50',
			{arg event, freq; AmpCompA.ir(freq.max(60), 60, 0.5);}
		],
		["A-weighted amp compensation, minAmp: 0.4", 'aWeighted40',
			{arg event, freq; AmpCompA.ir(freq.max(60), 60, 0.4);}
		],
		["A-weighted amp compensation, minAmp: 0.32 (default)", 'aWeighted32',
			{arg event, freq; AmpCompA.ir(freq.max(60), 60, 0.32);}
		],
		["A-weighted amp compensation, minAmp: 0.25", 'aWeighted25',
			{arg event, freq; AmpCompA.ir(freq.max(60), 60, 0.25);}
		],
		["Amp compensation, exponent: 0.1", 'exponent10',
			{arg event, freq; AmpComp.ir(freq.max(60), 60, 0.1);}
		],
		["Amp compensation, exponent: 0.2", 'exponent20',
			{arg event, freq; AmpComp.ir(freq.max(60), 60, 0.2);}
		],
		["Amp compensation, exponent: 0.3333 (default B)", 'exponent33',
			{arg event, freq; AmpComp.ir(freq.max(60), 60, 0.3333);}
		],
		["Amp compensation, exponent: 0.4", 'exponent40',
			{arg event, freq; AmpComp.ir(freq.max(60), 60, 0.4);}
		],
		["Amp compensation, exponent: 0.5", 'exponent50',
			{arg event, freq; AmpComp.ir(freq.max(60), 60, 0.5);}
		],
	];
	d.ampComp = 'off';
	d.ampCompFunc = {arg event, freq; AmpCompA.ir(freq.max(60), 60, 0.32);};
	d.masterCompress = 0.7;

	// sound source settings
	d.soundSourceOptions = [
		["Filtered Noise ", 'filteredNoise'],
		["Phase Mod Sines, Blue = Modulation", 'phaseModSines'],
		["Phase Mod Sines 2, Blue = Modulation, Red = Freq Ratio", 'phaseModSines2'],
		["Phase Mod Sines + Filtered Noise, Blue = Modulation, Red = Noise Mix", 'phaseModSinesNoise'],
		["Sines", 'sines'],
		["Wavetables, Blue = Morph 1-2-3", 'wavetables'],
		["Wavetables + Filtered Noise, Blue = Morph 1-2-3, Red = Noise Mix", 'wavetablesNoise'],
	];
	d.soundSource = 'sines';
	d.phaseModFreqRatio = 1.5;
	d.phaseModMaxModulation = 2;
	d.phaseModMinRatio = 1;
	d.phaseModMaxRatio = 4;
	d.phaseModRatioStepOptions = [
		["Off", '0', 0],
		["1 / 9", 'recip9', 9.reciprocal],
		["1 / 8", 'recip8', 8.reciprocal],
		["1 / 7", 'recip7', 7.reciprocal],
		["1 / 6", 'recip6', 6.reciprocal],
		["1 / 5", 'recip5', 5.reciprocal],
		["1 / 4", 'recip4', 4.reciprocal],
		["1 / 3", 'recip3', 3.reciprocal],
		["1 / 2", 'recip2', 2.reciprocal],
		["1", '1', 1],
	];
	d.phaseModRatioStep = '0';
	d.numHarmonics = 16;
	d.wtAmps = [   // wavetable harmonic ams
		[1] ++ (0 ! (d.numHarmonics - 1)),  // sine wave
		1.0 / (1, 2..d.numHarmonics).squared, // tri wave
		1.0 / (1, 2..d.numHarmonics), // saw wave
	];
	d.stereoModeOptions = [
		["Mono as Stereo: All Sounds in Centre", 'mono'],
		["Stereo by Color:  Green = Left, Blue = Centre, Red = Right", 'stereoColor'],
		["Stereo by Voice:  Spread Voices from Left to Right", 'stereoVoiceSpread'],
		["Stereo Random: Different Pan for each Frequency", 'stereoRandFreq'],
		["Stereo Seq 2-Step: Left/Right in Freq order", 'stereoLR'],
		["Stereo Seq 3-Step: Left/Centre/Right in Freq order", 'stereoLCR'],
		["Stereo Seq 4-Step: Left/Centre/Right/Centre in Freq order", 'stereoLCRC'],
	];
	d.stereoMode = 'stereoLCRC';

	// stereo delay
	d.delayMix = 0; // range 0-1
	d.delayL = 0.25; // range 0.01-2
	d.delayR = 0.25; // range 0.01-2
	d.decayTimeL = 1; // range 0.01-30
	d.decayTimeR = 1; // range 0.01-30

	// reverb JPverb
	d.reverbMix = 0; // range 0-1
	d.reverbTime = 0.3; // range 0.01 - 60
	d.reverbDamp = 0.1; // range 0-1
	d.reverbSize = 1; // range 0.5 - 5
	d.reverbEarlyRef = 0.7; // range 0-1
	d.reverbModDepth = 0.1; // range 0-1
	d.reverbModFreq = 2; // range 0-10
	d.reverbLow = 1; // range 0-1
	d.reverbMid = 1; // range 0-1
	d.reverbHigh = 1; // range 0-1
	d.reverbLoCutFreq = 500; // range 100-6000
	d.reverbHiCutFreq = 2000; // range 1000-10000

	// recording
	d.recordFormatOptions = [
		["16-bit aiff", 'aiff16'],
		["24-bit aiff", 'aiff24'],
		["32-bit float aiff", 'aiff32'],
		["16-bit wav", 'wav16'],
		["24-bit wav", 'wav24'],
		["32-bit float wav", 'wav32'],
	];
	d.recordFormat = 'wav24';
	d.recordTime = 8;
	d.recordTimePresets = [
		["Presets..,", nil],
		["5 secs", 5],
		["10 secs", 10],
		["20 secs", 20],
		["30 secs", 30],
		["1 min / 60 secs", 60],
		["2 min / 120 secs", 120],
		["3 min / 180 secs", 180],
		["4 min / 240 secs", 240],
		["5 min / 300 secs", 300],
		["10 min / 600 secs", 600],
	];

	// image tools
	d.toolModeOptions = [
		["Analysis - Sound To Image", 'analysis'],
		["Blur - Drag Box", 'blurDragBox'],
		["Blur - Whole Image", 'blurWholeImage'],
		["Colorize - Drag Box", 'colorizeDragBox'],
		["Copy, Cut, Paste - Select Box", 'selectDragBox'],
		["Compression - Select Box", 'compressionDragBox'],
		["Drag Draw - Box", 'dragDrawBox'],
		["Drag Draw - Oval", 'dragDrawOval'],
		["Drag Draw - Line, Curve", 'dragDrawLine'],
		["Drag Draw - Triangle", 'dragDrawTriangle'],
		["Drag Draw - Horizontal Bar", 'dragDrawHorizBar'],
		["Drag Draw - Vertical Bar", 'dragDrawVertBar'],
		["Paint - Boxes", 'paintBoxes'],
		["Paint - Ovals", 'paintOvals'],
		["Paint - Triangles", 'paintTriangles'],
		["Paint - Lines, Curves", 'paintLines'],
		["Paint - Spray", 'paintSpray'],
		["Perlin Noise - Select Box", 'perlinNoiseDragBox'],
		["Scale Filter - Select Box ", 'scaleFilterDragBox'],
	];
	d.toolMode = 'dragDrawBox';
	d.fillModeOptions = [
		["Outline Only", 'outline'],
		["Fill, Flat Color", 'fillFlat'],
		["Fill, Circular Fade, Centre -> Edge", 'fillCircularFade'],
		["Fill, Horizontal Fade, Left -> Right", 'fillHorizontalFade'],
		["Fill, Vertical Fade, Bottom -> Top", 'fillVerticalFade'],
		["Fill, Slope-Up Fade, BottomLeft -> TopRight,", 'fillSlopeUpFade'],
		["Fill, Slope-Down Fade, TopLeft -> BottomRight", 'fillSlopeDownFade'],
	];
	d.fillMode = 'fillFlat';
	d.fadeModeOptions = [
		["Fade In, Transparent to Color 1", 'fadeInTransparent'],
		["Fade In, Black to Color 1", 'fadeInBlack'],
		["Fade Out, Color 1 to Transparent", 'fadeOutTransparent'],
		["Fade Out, Color 1 to Black", 'fadeOutBlack'],
		["Cross-Fade, Color 1 to Color 2", 'crossFade'],
	];
	d.fadeMode = 'fadeInTransparent';
	d.paintModeOptions = [
		["Single - click to add, drag to move", 'single'],
		["Continuous - click and drag to paint", 'continuous'],
		["Horizontal Repeats - click to add, drag to move", 'repeatsH'],
		["Vertical Repeats - click to add, drag to move", 'repeatsV'],
	];
	d.paintMode = 'single';
	d.lineModeOptions = [
		["Straight Line", 'straight'],
		["Horizontal Line", 'horizontal'],
		["Vertical Line", 'vertical'],
		["Curve", 'curve'],
	];
	d.lineMode = 'straight';
	d.paintLineModeOptions = [
		["Straight Line", 'straight'],
		["Curve", 'curve'],
	];
	d.paintLineMode = 'straight';
	d.lineCurve = 1;
	d.triangleModeOptions = [
		["Straight Right-angled, Bottom Left", 'rtAngledBottomLeft'],
		["Straight Right-angled, Bottom Right", 'rtAngledBottomRight'],
		["Straight Right-angled, Top Left", 'rtAngledTopLeft'],
		["Straight Right-angled, Top Right", 'rtAngledTopRight'],
		["Straight Equilateral, Flat Top", 'equilateralTop'],
		["Straight Equilateral, Flat Bottom", 'equilateralBottom'],
		["Straight Equilateral, Flat Left", 'equilateralLeft'],
		["Straight Equilateral, Flat Right", 'equilateralRight'],
		["Curved Right-angled, Bottom Left", 'curvedRtAngledBottomLeft'],
		["Curved Right-angled, Bottom Right", 'curvedRtAngledBottomRight'],
		["Curved Right-angled, Top Left", 'curvedRtAngledTopLeft'],
		["Curved Right-angled, Top Right", 'curvedRtAngledTopRight'],
		["Curved Equilateral, Flat Top", 'curvedEquilateralTop'],
		["Curved Equilateral, Flat Bottom", 'curvedEquilateralBottom'],
		["Curved Equilateral, Flat Left", 'curvedEquilateralLeft'],
		["Curved Equilateral, Flat Right", 'curvedEquilateralRight'],
	];
	d.triangleMode = 'rtAngledBottomLeft';
	d.sprayModeOptions = [
		["Box Fade Out, Color 1 to Black", 'boxFadeOutBlack'],
		["Box Fade Out, Color 1 to Transparent", 'boxFadeOutTransparent'],
		["Box Flat, Color 1", 'boxFlat'],
		["Circular Fade Out, Color 1 to Black", 'circularFadeOutBlack'],
		["Circular Fade Out, Color 1 to Transparent", 'circularFadeOutTransparent'],
		["Circular Flat, Color 1", 'circularFlat'],
	];
	d.sprayMode = 'circularFadeOutTransparent';
	d.sprayRadiusSpec = ControlSpec(2, 200, step: 1);
	d.sprayRadius = 30;
	d.sprayDensitySpec = ControlSpec(5, 95, step: 0.01);
	d.sprayDensity = 50;
	d.colorizeModeOptions = [
		["Colorize, Flat - Color 1", 'colorizeFlat'],
		["Colorize, Circular Fade - Color 1 to Color 2", 'colorizeCircularFade'],
		["Colorize, Horizontal Fade - Color 1 to Color 2", 'colorizeHorizontalFade'],
		["Colorize, Vertical Fade - Color 1 to Color 2", 'colorizeVerticalFade'],
		["Colorize, Slope-Up Fade - Color 1 to Color 2", 'colorizeSlopeUpFade'],
		["Colorize, Slope-Down Fade - Color 1 to Color 2", 'colorizeSlopeDownFade'],
	];
	d.colorizeMode = 'colorizeFlat';
	d.colorPresets = [
		["presets", nil],
		["Black", Color.black],
		["Blue", Color.blue],
		["Cyan", Color.cyan],
		["Grey", Color.gray],
		["Green", Color.green],
		["Magenta", Color.magenta],
		["Red", Color.red],
		["Transparent", Color.clear],
		["White", Color.white],
		["Yellow", Color.yellow],
	];
	d.colorPresetsNoAlpha = [  // no transparency
		["presets", nil],
		["Black", Color.black],
		["Blue", Color.blue],
		["Cyan", Color.cyan],
		["Grey", Color.gray],
		["Green", Color.green],
		["Magenta", Color.magenta],
		["Red", Color.red],
		["White", Color.white],
		["Yellow", Color.yellow],
	];
	d.colorizePresets = [  // no transparency or black
		["presets", nil],
		["Blue", Color.blue],
		["Cyan", Color.cyan],
		["Green", Color.green],
		["Magenta", Color.magenta],
		["Red", Color.red],
		["White", Color(1, 0.999, 0.999, 1)],
		["Yellow", Color.yellow],
	];
	d.analysisSetsPlayLength = true;
	d.analysisCompLimit = false;
	d.analysisCompressionCurve = 2;  // range 0, 5
	d.analysisLimitCeiling = 1; // range 0.2, 1.0
	d.analysisColor = Color(1, 0.999, 0.999, 1);
	d.analysisStopped = false;
	d.perlinOctaves = 3;  // range 1,8
	d.perlinScaleX = 10;
	d.perlinScaleY = 10;
	d.perlinColor = Color(1, 0.999, 0.999, 1);
	d.perlinTripleNoise = true;   // separate noise for RGB
	d.perlinOffset = 0;  // range -0.999,0.999
	d.perlinRandSeed = 1000;  // range 0,99999
	d.perlinQuantize = 0;  // range 0,1
	d.useGate = false;
	d.useCompression = true;
	d.useLimiter = false;
	d.autoGainCompensation = false;
	d.gateThreshold = 0; // range 0.0, 0.4
	d.compressionCurve = 2;  // range -5, 5
	d.limitCeiling = 1; // range 0.5, 1.0
	// tool colors
	d.drawColor1 = Color.yellow;  // drawColor1 is main color
	d.drawColor2 = Color.red;   // only for fill modes fill_XXX_Fade with fadeMode 'crossFade'
	d.colorizeColor1 = Color.yellow;
	d.colorizeColor2 = Color.red;  // only for colorize modes 'colorizeAxial' or 'colorizeCircular'
	// Time Grid Steps
	d.timeGridStepsSpec = ControlSpec(2, 64, step: 1);
	d.timeGridSteps = 16;
	d.showTimeGrid = false;
	d.snapToTimeGrid = false;
	// freq grid
	d.showOctaves = false;   // only used for midi note freq modes

	/*  // removed for now
	d.showFreqGrid = false;  // only used for 'exp' and 'lin' freq modes
	d.freqDivisionsSpec = ControlSpec(2, 64, step: 1);
	d.freqDivisions = 8;
	d.snapToFreqGrid = false;
	*/

	// blur
	d.blurModeOptions = [
		["Left", 'left'],
		["Right", 'right'],
		["Left and Right", 'left_right'],
		["Up", 'up'],
		["Down", 'down'],
		["Up and Down", 'up_down'],
	];
	d.blurMode = 'left_right';
	d.blurCompositingOptions = Image.compositingOperations.select({arg item;
		['sourceOver', 'multiply', 'plus', 'plusDarker', 'plusLighter'].indexOf(item).notNil
	}).collect({arg item; var string;
		if (item == 'sourceOver', {string = item.asString + "(default)"}, {string = item.asString});
		[string, item];
	});
	d.blurCompositing = 'sourceOver';
	d.blurDepth = 0.5; // range 0-1
	d.blurSteps = 2;  // range 1-4
	// paste
	d.pasteModeOptions = [
		["Composite: Stretch Image to Fit", 'stretchToFit'],
		["Composite: Scale Image to Fill", 'scaleToFill'],
		["Composite: Scale Image to Fit", 'scaleToFit'],
		["Composite: Original Size", 'originalScale'],
		["Composite: Tile Image to Fill", 'tileToFill'],
		["Colorize: Stretch Image to Fit", 'colorizeStretchToFit'],
	];
	d.pasteMode = 'stretchToFit';
	d.pasteRepeatModeOptions = [
		["Paste Once", 'pasteOnce'],
		["Horizontal Repeats", 'repeatsH'],
		["Vertical Repeats", 'repeatsV'],
	];
	d.pasteRepeatMode = 'pasteOnce';
	d.pasteCompositingOptions = Image.compositingOperations.select({arg item;
		['sourceOver', 'plus', 'plusDarker', 'plusLighter'].indexOf(item).notNil
	}).collect({arg item; var string;
		if (item == 'sourceOver', {string = item.asString + "(default)"}, {string = item.asString});
		[string, item];
	});
	d.pasteCompositing = 'sourceOver';
	d.pasteOpacity = 1;
	// scale filter
	d.filterScale = 'major';
	d.filterScaleRoot = 0;  // 0 -> "C"
	d.filterScaleInvert = false;

	// paint tool settings
	d.maxToolSize = 500;
	d.toolWidth = 20; // range (1, d.maxToolSize)
	d.toolHeight = 20; // range (1, d.maxToolSize)
	d.toolUseWidthForHeight = false;
	d.toolRotation = 0; // range (-180, 180)
	d.toolRandWidthMix = 0; // range (0, 1)
	d.toolRandHeightMix = 0; // range (0, 1)
	d.toolRandRotationMix = 0; // range (0, 1)
	d.toolRandSpec = ControlSpec(0, 1);
	d.repeatsCountH = 8;   // range 1-99
	d.repeatsCountV = 8;   // range 1-99
	d.repeatsSpacingH = 60;   // range -/+ 1000
	d.repeatsSpacingV = 12;   // range -/+ 100
	d.repeatsDarken = 0;  // range 0-0.9
	d.repeatsDissolve = 0;  // range 0-0.9

	// gui colours
	d.colWindow = Color.grey(0.8);  // grey
	d.colButton = Color(0.17, 0.38, 0.58);  // blue
	d.colLabel = Color(0.97, 0.98, 1);  // pale blue
	d.colLabelString = Color(0.03, 0.28, 0.43);  // dark blue
	d.colHighlight = Color(1, 1, 0.7);  // pale yellow
	d.colHighlight2 = Color(1, 0.9, 0.8);  // pale orange
	d.colWarning = Color(1, 0.77, 0.77);  // pale yellow
	d.colError = Color(1, 0.8, 0.4);  // orange
	d.colPlayActive = Color(0.47, 0.8, 0.17);  // bright green
	d.colRecordTint = Color(1, 0.9, 0.87);
	d.moreColors = true;  // or false
	if (d.moreColors.not, {
		d.colPlay = d.colButton;
		d.colRecord = d.colButton;
		d.colStop = d.colButton;
		d.colSave = d.colButton;
		d.colClearImage = d.colButton;
		d.colHelp = d.colButton;
	}, {
		d.colPlay = Color(0.26, 0.54, 0.26);  // dark green
		d.colRecord = Color(0.72, 0.34, 0.34);  // red
		d.colStop = Color(0.37, 0.37, 0.44);  // dark grey-blue
		d.colSave = Color(0.5, 0.37, 0.62);  // purple
		d.colClearImage = Color(0.37, 0.37, 0.44);  // dark grey-blue
		d.colHelp = Color(0.8, 0.39, 0);  // orange
	});

	d.windowWidth = 840;
	d.windowHeight = 600;
	d.alwaysOnTop = false; // true keeps window in front

	d.displayTab = \settings;

	// ============  End of Settings  ============
};
// end of d.fInitSettings
d.fInitSettings;   // run function

d.fInit2 = {
	// init
	d.guiOptions = ();
	d.imageIndex = 0;  // image shown, played, recorded
	d.toolRotationSpec = ControlSpec(-180, 180);
	d.playLengthSpec = ControlSpec(d.minPlayLength, d.maxPlayLength, 2);
	d.playLengthBeatsSpec = ControlSpec(1, 100000);
	d.playLengthBeats = 16;
	d.playBPMSpec = ControlSpec(0.01, 100000);
	d.playBPM = 60 * d.playLengthBeats / d.playLength;
	d.playPosition = 0;
	d.playLooped = false;
	d.recordingStatus = "Not Ready: Open a record file before recording.";
	d.recordClockTime = 0.0;
	d.currentRecFileName = "";
	d.previousRecFileName = "";
	d.isRecording = false;
	d.recordingLevel = 1;
	d.recordingBus = Bus.audio(s, numChannels: 2);
	d.isDragDraw = false;
	d.isDragBlur = false;
	d.isDragColorize = false;
	d.isPainting = false;
	d.selectionBox = nil;
	d.useEQ = false;
	d.arrEQAmps = 1 ! d.imageHeight;
	d.useEnv = false;
	d.envCurve = 0.5 ! 480;
	d.useTimeStretch = false;
	d.maxStretch = 1.5;
	d.minStretch = 1 - (d.maxStretch - 1);
	d.timeStretchRateMulti = 1;
	d.arrNormTimeStretches = 0.5 ! 480;
	d.arrTimeStretches = 1 ! 480;
	d.usePitchShift = false;
	d.maxShift = 12;
	d.arrNormPitchShifts = 0.5 ! 480;
	d.arrPitchShifts = 0 ! 480;
	d.useWarp = false;
	d.warpCurve = Array.interpolation(240, 0, 1);
	d.useFX = false;
	d.showBackgroundImage = false;
};
// end of d.fInit2
d.fInit2;   // run function

d.fDefineFunctions = {
	d.fFreeAllResources = {
		if (d.arrImages.notNil, {
			d.arrImages.do({arg image; image.free});
			d.arrImages = nil;
		});
		if (d.recordBuffer.notNil, {
			d.recordBuffer.free;
			d.recordBuffer = nil;
		});
		if (d.arrWTBuffers.notNil, {
			d.arrWTBuffers.do({arg item; item.free});
			d.arrWTBuffers = nil;
		});
	};
	// synthdefs
	d.fAddRecordingSynthDef = {
		SynthDef("imageSynthRecord", { |bufnum, gate = 1, recordTime = 8|
			var switchTime, stopTime, timedGate, outEnv, inSig;
			switchTime = 0.01; // to stop clicks
			stopTime = (recordTime - switchTime).max(0.01);
			// timedGate = Trig1.ar(1, stopTime);
			timedGate = Sweep.ar(1, 1) < stopTime;
			// send message if stopTime reached
			SendReply.ar(1 - timedGate, cmdName: '/imageRecordSynthEnded');
			outEnv = EnvGen.kr(
				Env.new([0,1,1,0],[switchTime, 1, switchTime],'lin', 2),
				gate * timedGate,
				doneAction: 2
			);
			inSig = In.ar(d.recordingBus, 2);
			outEnv * DiskOut.ar(bufnum, inSig); // 2 channels
		}).add;
	};
	d.fAddRecordingSynthDef;  // run function
	d.fAddKeyboardSynthDef = {
		SynthDef("keyboardSynth", { |freq = 220, amp = 0.2|
			Out.ar(0,
				(d.ampCompFunc(freq) * SinOsc.ar(freq, 0, 0.07)
					* Env.perc(releaseTime: 1, level: amp).kr(2)
				) ! 2 // 2 channels
			);
		}).add;
	};
	d.fAddKeyboardSynthDef;  // run function
	d.fPlayKeyboardNote = {arg event, freq;
		d.keyboardSynth = Synth(\keyboardSynth, args: [\freq, freq, \amp, d.volume]);
		d.lastFreqPlayed = freq;
	};
	d.fAddSinesSynthDef = {
		SynthDef("sinesSynth", { |freq = 220, amp = 0.2|
			Out.ar(0,
				(amp * d.ampCompFunc(freq) * SinOsc.ar(freq, 0, 0.07)
					* Env([0, 1, 1, 0], [0.1, 1, 0.5]).kr(2)
				) ! 2 // 2 channels
			);
		}).add;
	};
	d.fAddSinesSynthDef;  // run function
	d.fPlaySinesNote = {arg event, freq;
		d.keyboardSynth = Synth(\sinesSynth, args: [\freq, freq, \amp, d.volume]);
	};
	d.fGetNoiseAmpForFreq = {arg event, freq;
		freq.explin(30, 10000, 140, 16);
	};
	d.fAddFilteredNoiseSynthDef = {
		SynthDef("filteredNoiseSynth", { |freq = 220, amp = 0.2|
			Out.ar(0,
				(amp * d.ampCompFunc(freq)
					* Resonz.ar(PinkNoise.ar * 120, freq, bwr: 0.004)
					* Env([0, 1, 1, 0], [0.1, 1, 0.5]).kr(2)
				) ! 2 // 2 channels
			);
		}).add;
	};
	d.fAddFilteredNoiseSynthDef;  // run function
	d.fPlayFilteredNoiseNote = {arg event, freq;
		d.keyboardSynth = Synth(\filteredNoiseSynth, args: [\freq, freq, \amp, d.volume]);
	};
	d.fAddPhaseModSynthDef = {
		SynthDef("phaseModSynth", { |freq = 220, amp = 0.2, freqRatio = 1.5, maxModulation = 5, noiseMix = 0.5|
			var modSweep = Env([0, 0, maxModulation, maxModulation], [0.1, 2, 0.1]).kr;
			var noise;
			if (d.soundSource == 'phaseModSines', {
				Out.ar(0,
					(d.ampCompFunc(freq) * PMOsc.ar(freq, freq * freqRatio, modSweep, mul: 0.2 * amp)
						* Env([0, 1, 1, 1, 0], [0.1, 2, 0.1, 0.5]).kr(2)
					) ! 2 // 2 channels
				);
			}, {
				noise = PinkNoise.ar * 120;
				Out.ar(0,
					(d.ampCompFunc(freq) *
						XFade2.ar(
							PMOsc.ar(freq, freq * freqRatio, modSweep, mul: 0.2 * amp),
							Resonz.ar(noise, freq, bwr: 0.004, mul: amp),
							pan: (noiseMix * 2) - 1
						)
						* Env([0, 1, 1, 1, 0], [0.1, 2, 0.1, 0.5]).kr(2)
					) ! 2 // 2 channels
				);
			});
		}).add;
	};
	d.fAddPhaseModSynthDef;  // run function
	d.fPlayPhaseModNote = {arg event, freq, noiseMix;
		d.keyboardSynth = Synth(\phaseModSynth, args: [\freq, freq, \amp, d.volume,
			\freqRatio, d.phaseModFreqRatio, \maxModulation, d.phaseModMaxModulation,
			\noiseMix, noiseMix, ]);
	};
	d.fAddPhaseModSynthDef2 = {
		SynthDef("phaseModSynth2", { |freq = 220, amp = 0.2, maxModulation = 5|
			var modSweep = Env([0, 0, maxModulation, maxModulation], [0.1, 2, 0.1]).kr;
			var ratioSweep = Env(
				[d.phaseModMinRatio, d.phaseModMinRatio, d.phaseModMaxRatio, d.phaseModMaxRatio],
				[0.1, 2, 0.1]
			).kr;
			var stepSize;
			if (d.phaseModRatioStep != '0', {
				stepSize = d.phaseModRatioStepOptions.flop.slice(2)
					[d.phaseModRatioStepOptions.flop.slice(1).indexOfEqual(d.phaseModRatioStep)];
				ratioSweep = ratioSweep.round(stepSize);
			});
			Out.ar(0,
				(d.ampCompFunc(freq) * PMOsc.ar(freq, freq * ratioSweep, modSweep, mul: 0.2 * amp)
					* Env([0, 1, 1, 1, 0], [0.1, 2, 0.1, 0.5]).kr(2)
				) ! 2 // 2 channels
			);
		}).add;
	};
	d.fAddPhaseModSynthDef2;  // run function
	d.fPlayPhaseModNote2 = {arg event, freq;
		d.keyboardSynth = Synth(\phaseModSynth2, args: [\freq, freq, \amp, d.volume,
			\maxModulation, d.phaseModMaxModulation,
		]);
	};
	d.fAddWavetableSynthDef = {
		SynthDef("wavetableSynth", { |freq = 220, amp = 0.2, bufnum, startInd = 0, endInd = 1.99, holdTime = 2,
			noiseMix = 0.5|
			var modSweep = Env([startInd, startInd, endInd, endInd], [0.1, holdTime, 0.1]).kr;
			var noise;
			if (d.soundSource == 'wavetables', {
				Out.ar(0,
					(d.ampCompFunc(freq) * VOsc.ar(bufnum + modSweep, freq, mul: 0.2 * amp)
						* Env([0, 1, 1, 1, 0], [0.1, holdTime, 0.1, 0.5]).kr(2)
					) ! 2 // 2 channels
				);
			}, {
				noise = PinkNoise.ar * 120;
				Out.ar(0,
					(
						d.ampCompFunc(freq) *
						XFade2.ar(
							VOsc.ar(bufnum + modSweep, freq, mul: 0.2 * amp),
							Resonz.ar(noise, freq, bwr: 0.004, mul: amp),
							pan: (noiseMix * 2) - 1
						)
						* Env([0, 1, 1, 1, 0], [0.1, holdTime, 0.1, 0.5]).kr(2)
					) ! 2 // 2 channels
				);
			});
		}).add;
	};
	d.fAddWavetableSynthDef;  // run function
	d.fPlayWavetableNote = {arg event, freq = 440, startInd = 0, endInd = 1.99, holdTime = 2;
		d.keyboardSynth = Synth(\wavetableSynth, args:
			[\freq, freq, \amp, d.volume, \bufnum, d.arrWTBuffers.first.bufnum,
				\startInd, startInd, \endInd , endInd, \holdTime, holdTime, \noiseMix, d.playNoiseMix, ]);
	};
	d.fSetAnalysisVol = {arg event, vol;
		if (d.analysisSynth.notNil, {
			d.analysisSynth.set(\amp, vol);
		});
	};

	// default settings
	// image defaults
	d.fBuildDefaultImageSettings = {
		d.imageSettingsKeys = [
			'playLength', 'playLooped', 'imageIndex', 'imageWidth', 'imageHeight', 'pixelWidth', 'pixelHeight',
			'randSeed', 'freqMode', 'minFreq', 'maxFreq', 'midiNoteLowest', 'ampComp', 'ampCompFunc', 'compression',
			'globalDetuneCents', 'copyRandDetuneCents', 'detunedCopies', 'detuneFirstVoice',
			'midiPitchesPerOct', 'midiScale', 'midiTuning',
			'timeGridSteps', 'showTimeGrid', 'snapToTimeGrid',
			'showOctaves', 'useEQ', 'arrEQAmps', 'useEnv', 'envCurve', 'useFX',
			// 'showFreqGrid', 'freqDivisions', 'snapToFreqGrid',  // removed for now
			'recordFormat', 'recordTime', 'useWarp', 'warpCurve',
		];
		d.defaultSettings = d.imageSettingsKeys.collect({arg key; [key, d[key].deepCopy]});
	};
	d.fBuildDefaultImageSettings;  // run function
	d.fLoadDefaultImageSettings = {
		d.defaultSettings.do({arg item;
			var key = item[0], val = item[1];
			d[key] = val.deepCopy;
		});
		d.fUpdateBPM;
		d.fResizeImages;
		d.fBuildArrFreqs;
	};
	// sound defaults
	d.fBuildDefaultSoundSettings = {
		d.soundSettingsKeys = [
			'soundSource', 'stereoMode', 'masterCompress', 'phaseModFreqRatio', 'phaseModMaxModulation',
			'phaseModMinRatio', 'phaseModMaxRatio', 'phaseModRatioStep',
			'numHarmonics', 'wtAmps', 'midiPlayNote',
		];
		d.defaultSoundSettings = d.soundSettingsKeys.collect({arg key; [key, d[key].deepCopy]});
	};
	d.fBuildDefaultSoundSettings;  // run function
	d.fLoadDefaultSoundSettings = {
		d.defaultSoundSettings.do({arg item;
			var key = item[0];
			var val = item[1];
			d[key] = val.deepCopy;
		});
	};
	// tool defaults
	d.fBuildDefaultToolSettings = {
		d.toolSettingsKeys = [
			'fillMode', 'fadeMode', 'paintMode', 'lineMode', 'paintLineMode', 'lineCurve', 'triangleMode',
			'sprayMode', 'sprayRadius', 'sprayDensity', 'colorizeMode',
			'analysisSetsPlayLength', 'analysisCompLimit',
			'analysisCompressionCurve', 'analysisLimitCeiling', 'analysisColor', 'analysisStopped ',
			'useGate', 'useCompression', 'useLimiter', 'autoGainCompensation',
			'gateThreshold', 'compressionCurve', 'limitCeiling',
			'perlinOctaves', 'perlinScaleX', 'perlinScaleY', 'perlinColor', 'perlinTripleNoise',
			'perlinOffset', 'perlinRandSeed', 'perlinQuantize',
			'drawColor1', 'drawColor2', 'colorizeColor1', 'colorizeColor2',
			'blurMode', 'blurCompositing', 'blurDepth', 'blurSteps',
			'pasteMode', 'pasteRepeatMode', 'pasteCompositing', 'pasteOpacity',
			'filterScale', 'filterScaleRoot', 'filterScaleInvert',
			'maxToolSize', 'toolWidth', 'toolHeight', 'toolUseWidthForHeight', 'toolRotation',
			'toolRandWidthMix', 'toolRandHeightMix', 'toolRandRotationMix',
			'repeatsCountH', 'repeatsCountV', 'repeatsSpacingH', 'repeatsSpacingV', 'repeatsDarken', 'repeatsDissolve',
		];
		d.defaultToolSettings = d.toolSettingsKeys.collect({arg key; [key, d[key].deepCopy]});
	};
	d.fBuildDefaultToolSettings;  // run function
	d.fLoadDefaultToolSettings = {
		d.defaultToolSettings.do({arg item;
			var key = item[0];
			var val = item[1];
			d[key] = val.deepCopy;
		});
	};
	// Time Stretch defaults
	d.fBuildDefaultTimeStretchSettings = {
		d.timeStretchSettingsKeys = [
			'useTimeStretch', 'minStretch', 'maxStretch', 'timeStretchRateMulti',
			'arrNormTimeStretches', 'arrTimeStretches',
		];
		d.defaultTimeStretchSettings = d.timeStretchSettingsKeys.collect({arg key; [key, d[key].deepCopy]});
	};
	d.fBuildDefaultTimeStretchSettings;  // run function
	d.fLoadDefaultTimeStretchSettings = {
		d.defaultTimeStretchSettings.do({arg item;
			var key = item[0];
			var val = item[1];
			d[key] = val.deepCopy;
		});
		d.fAddToCurveHistory('arrNormTimeStretches');
	};
	// Pitch Shift defaults
	d.fBuildDefaultPitchShiftSettings = {
		d.pitchShiftSettingsKeys = [
			'usePitchShift', 'maxShift', 'arrNormPitchShifts', 'arrPitchShifts',
		];
		d.defaultPitchShiftSettings = d.pitchShiftSettingsKeys.collect({arg key; [key, d[key].deepCopy]});
	};
	d.fBuildDefaultPitchShiftSettings;  // run function
	d.fLoadDefaultPitchShiftSettings = {
		d.defaultPitchShiftSettings.do({arg item;
			var key = item[0];
			var val = item[1];
			d[key] = val.deepCopy;
		});
		d.fAddToCurveHistory('arrNormPitchShifts');
	};
	// fx  defaults
	d.fBuildDefaultDelaySettings = {
		d.delaySettingsKeys = [
			'delayMix', 'delayL', 'delayR', 'decayTimeL', 'decayTimeR',
		];
		d.defaultDelaySettings = d.delaySettingsKeys.collect({arg key; [key, d[key].deepCopy]});
	};
	d.fBuildDefaultDelaySettings;  // run function
	d.fLoadDefaultDelaySettings = {
		d.defaultDelaySettings.do({arg item;
			var key = item[0];
			var val = item[1];
			d[key] = val.deepCopy;
		});
	};
	d.fBuildDefaultReverbSettings = {
		d.reverbSettingsKeys = [
			'reverbMix', 'reverbTime', 'reverbDamp', 'reverbSize',
			'reverbEarlyRef', 'reverbModDepth', 'reverbModFreq',
			'reverbLow', 'reverbMid', 'reverbHigh', 'reverbLoCutFreq', 'reverbHiCutFreq',
		];
		d.defaultReverbSettings = d.reverbSettingsKeys.collect({arg key; [key, d[key].deepCopy]});
	};
	d.fBuildDefaultReverbSettings;  // run function
	d.fLoadDefaultReverbSettings = {
		d.defaultReverbSettings.do({arg item;
			var key = item[0];
			var val = item[1];
			d[key] = val.deepCopy;
		});
	};
	// all default settings
	d.fLoadAllDefaultSettings = {
		d.fLoadDefaultImageSettings;
		d.fLoadDefaultSoundSettings;
		d.fLoadDefaultToolSettings;
		d.fLoadDefaultTimeStretchSettings;
		d.fLoadDefaultPitchShiftSettings;
		d.fLoadDefaultDelaySettings;
		d.fLoadDefaultReverbSettings;
		d.fAddToAllCurveHistories;
	};

	// col funcs
	d.fGetImageSelectCol = {arg event, ind;
		var outCol;
		if (d.imageIndex == ind, {
			outCol = d.colHighlight;
		}, {
			outCol = Color.white;
		});
		outCol;
	};
	d.fGetDisplayTabCol = {arg event, key, col;
		var outCol;
		if (d.displayTab == key, {
			outCol = col ? d.colHighlight;
		}, {
			outCol = Color.white;
		});
		outCol;
	};

	// show error
	d.fShowError = {arg event, errorString;
		var view = Window("Error",
			Rect(10, Window.availableBounds.height - 70, 500, 60))
		.background_(d.colError).front;
		StaticText(view, Rect(4, 6, 490, 22))
		.string_(" " ++ errorString).align_(\left)
		.stringColor_(Color.black).background_(d.colError);
		StaticText(view, Rect(4, 32, 60, 22))
		.string_("Close").align_(\center)
		.stringColor_(Color.white).background_(Color.red)
		.mouseDownAction_({view.close});
		view.alwaysOnTop_(true);
	};

	// wavetable buffers
	d.wtBufferLength = 2048;
	d.fAllocateWTBuffers = { // 3 wavetable buffers
		if (d.arrWTBuffers.notNil, {d.arrWTBuffers.do({arg item; item.free})}); // free old
		d.arrWTBuffers = Buffer.allocConsecutive(3, s, d.wtBufferLength * 2, 1);
	};
	d.fUpdateWTBuffer = {arg event, bufInd;
		d.arrWTBuffers[bufInd].sine1(d.wtAmps[bufInd], true, true, true);
	};
	d.fAllocUpdateWTBuffers = {
		forkIfNeeded {
			d.fAllocateWTBuffers;
			s.sync;
			3.do({arg i;
				d.fUpdateWTBuffer(i);
			});
		};
	};
	// Wavetable actions
	d.arrWavetableActions = [
		["- Wavetable Actions -",
			{}],
		["Preset - Sine Waveform", {arg wtInd;
			d.wtAmps[wtInd] = [1] ++ (0 ! (d.numHarmonics - 1));}],
		["Preset - Triangle waveform", {arg wtInd;
			d.wtAmps[wtInd] = 1.0 / (1, 2..d.numHarmonics).squared;}],
		["Preset - Square waveform", {arg wtInd;
			d.wtAmps[wtInd] = d.numHarmonics.collect({arg i; (i + 1).reciprocal * ((i + 1) % 2)});}],
		["Preset - Sawtooth waveform", {arg wtInd;
			d.wtAmps[wtInd] = 1.0 / (1, 2..d.numHarmonics);}],
		["Preset - Impulse waveform", {arg wtInd;
			d.wtAmps[wtInd] = (1 ! d.numHarmonics);}],
		["Disturb levels",  {arg wtInd;
			d.wtAmps[wtInd] = (d.wtAmps[wtInd] + ({0.05.rand2} ! d.numHarmonics)).clip(0, 1);}],
		["Randomise levels",  {arg wtInd;
			d.wtAmps[wtInd] = ({1.0.rand} ! d.numHarmonics;).normalize}],
		["Scramble levels",  {arg wtInd;
			d.wtAmps[wtInd] = d.wtAmps[wtInd].scramble;}],
		["Scramble levels, ignoring first harmonic", {arg wtInd;
			var newArr = d.wtAmps[wtInd].deepCopy;
			newArr = [newArr[0]] ++  newArr.keep(1 - newArr.size).scramble;
			d.wtAmps[wtInd] = newArr;
		}],
		["Reverse level order", {arg wtInd;
			d.wtAmps[wtInd] = d.wtAmps[wtInd].reverse;}],
		["Invert levels", {arg wtInd;
			var newArr = d.wtAmps[wtInd].deepCopy;
			newArr.do({arg item, i;
				d.wtAmps[wtInd][i] = 1 - item;
			});
		}],
		["Sort levels in asscending order", {arg wtInd; var newArr = d.wtAmps[wtInd].deepCopy;
			d.wtAmps[wtInd] = d.wtAmps[wtInd].sort;
		}],
		["Sort levels in descending order", {arg wtInd; var newArr = d.wtAmps[wtInd].deepCopy;
			d.wtAmps[wtInd] = d.wtAmps[wtInd].sort.reverse;
		}],
		["Bias levels Up", {arg wtInd; d.wtAmps[wtInd] = d.wtAmps[wtInd].collect({arg item, i;
			item.lincurve(0, 1, 0, 1, -1)});}],
		["Bias levels Down", {arg wtInd; d.wtAmps[wtInd] = d.wtAmps[wtInd].collect({arg item, i;
			item.lincurve(0, 1, 0, 1, 1)});}],
		["Bias levels using 1/N curve", {arg wtInd; d.wtAmps[wtInd] = d.wtAmps[wtInd].collect({arg item, i;
			item.blend(item / (i + 1), 0.5)}).normalize;}],
		["Bias levels using 1/N.squared curve", {arg wtInd; d.wtAmps[wtInd] = d.wtAmps[wtInd].collect({arg item, i;
			item.blend(item / (i + 1).squared, 0.5)}).normalize;}],
		["Zero levels on even harmonics", {arg wtInd; d.wtAmps[wtInd] = d.wtAmps[wtInd].collect({arg item, i;
			if (i.odd, 0, item)});}],
		["Zero odd harmonics ignoring first one", {arg wtInd; d.wtAmps[wtInd] = d.wtAmps[wtInd].collect({arg item, i;
			if (i > 0 and: {i.even}, 0, item)});}],
		["Copy first harmonic to all levels", {arg wtInd;
			d.wtAmps[wtInd] = d.wtAmps[wtInd][0] ! d.numHarmonics;}],
		["Normalise levels", {arg wtInd;
			d.wtAmps[wtInd] = d.wtAmps[wtInd].normalize;}],
		["1/N curve (N = number harmonic number)", {arg wtInd;
			d.wtAmps[wtInd] = d.wtAmps[wtInd].size.collect({arg i; (i + 1).reciprocal});}],
		["1/N.squared curve (N = number harmonic number)", {arg wtInd;
			d.wtAmps[wtInd] = d.wtAmps[wtInd].size.collect({arg i; (i + 1).squared.reciprocal});}],
		["Swap Wavetables 1 + 2",  {
			var new0 = d.wtAmps[1];
			var new1 = d.wtAmps[0];
			d.wtAmps[0] = new0;
			d.wtAmps[1] = new1;
		}],
		["Swap Wavetables 1 + 3",  {
			var new0 = d.wtAmps[2];
			var new2 = d.wtAmps[0];
			d.wtAmps[0] = new0;
			d.wtAmps[2] = new2;
		}],
		["Swap Wavetables 2 + 3",  {
			var new1 = d.wtAmps[2];
			var new2 = d.wtAmps[1];
			d.wtAmps[1] = new1;
			d.wtAmps[2] = new2;
		}],
		["Rotate Wavetables 1-3",  {
			var new0 = d.wtAmps[1];
			var new1 = d.wtAmps[2];
			var new2 = d.wtAmps[0];
			d.wtAmps[0] = new0;
			d.wtAmps[1] = new1;
			d.wtAmps[2] = new2;
		}],
	];
	d.fRunHarmonicAction = {arg event, actionIndex, wavetableIndex;
		d.arrWavetableActions.flop.slice(1).[actionIndex].value(wavetableIndex);
	};
	// other funcs
	d.fBuildArrPitchShifts = {
		d.arrPitchShifts = d.arrNormPitchShifts.linlin(0, 1, d.maxShift.neg, d.maxShift);
	};
	d.fQuantisePitchShifts = {
		var clipMax = d.maxShift.asInteger;
		d.arrPitchShifts = d.arrPitchShifts.clip2(clipMax).round(1.0);
		d.arrNormPitchShifts = d.arrPitchShifts.linlin(d.maxShift.neg, d.maxShift, 0, 1);
		d.fAddToCurveHistory('arrNormPitchShifts');
	};
	d.fCopyDelayL2DelayR = {
		d.delayR = d.delayL;
		d.decayTimeR = d.decayTimeL;
		if (d.imageSynth.notNil, {
			d.imageSynth.set('delayR', d.delayR, 'decayTimeR', d.decayTimeR);
		});
	};
	d.fUpdateBPM = {
		d.playBPM = 60 * d.playLengthBeats / d.playLength;
	};

	// Project
	d.fileActions = [
		["File Actions", {}],
		["Open Project File", {d.fOpenProject}],
		["Save Project File", {d.fSaveProject}],
		["Import Image File", {d.fImportImage}],
		["Export Image File", {d.fExportImage}],
	];
	d.fSaveProject = {
		{
			var okFunc, pathName, tempDict, saveData;
			okFunc = {arg path;
				pathName = PathName(path);
				// save settings to path
				if (pathName.notNil, {
					tempDict = ();
					[d.imageSettingsKeys, d.soundSettingsKeys, d.toolSettingsKeys, d.delaySettingsKeys,
						d.reverbSettingsKeys, d.timeStretchSettingsKeys, d.pitchShiftSettingsKeys,
					].do({arg item;
						item.do({arg key; tempDict[key] = d[key];});
					});
					tempDict.arrPixels = d.arrImages[0].pixels;
					tempDict.arrPixels2 = d.arrImages[1].pixels;
					pathName.extension = "txis";
					saveData = ["TXImageSynthProject", tempDict].asCompileString;
					// write file
					File.use(pathName.fullPath, "w", { |f| f.write(saveData) });
					"=== Saved project to file: ".postln;
					pathName.fullPath.postln;
					d.fUpdateWindowName(pathName.fullPath);
				});
			};
			Dialog.savePanel(okFunc);
		}.defer;
	};
	d.fOpenProject = {
		{
			var okFunc = ({arg path;
				var tempDict, newData;
				var pathName = PathName(path);
				if (pathName.extension == "txis", {
					// load default settings first
					d.fLoadAllDefaultSettings;
					// read new data & interpret
					newData = File.readAllString(path);
					newData = newData.interpret;
					// check validity
					if (newData.isArray and: {newData[0] == "TXImageSynthProject"}, {
						tempDict = newData[1];
						[d.imageSettingsKeys, d.soundSettingsKeys, d.toolSettingsKeys, d.delaySettingsKeys,
							d.reverbSettingsKeys, d.timeStretchSettingsKeys, d.pitchShiftSettingsKeys,
						].do({arg item;
							item.do({arg key;
								var val = tempDict[key];
								if (val.notNil, {
									d[key] = val;
								});
							});
						});
						d.fUpdateScaleData(true); // true - update options only
						d.fUpdateBPM;
						d.fBuildArrFreqs;
						d.fBuildImageSynthDef;
						d.fResizeImages;
						d.arrImages[0].pixels = tempDict.arrPixels;
						if (tempDict.arrPixels2.notNil, {
							d.arrImages[1].pixels = tempDict.arrPixels2;
						}, {
							d.arrImages[1].pixels = Image.color(d.imageWidth, d.imageHeight, Color.black).pixels;
						});
						if (d.displayTab == \settings, {
							d.displayTab = \imageTools;
						});
						d.fSetPlayPosition(0);
						d.fAddToAllCurveHistories;
						d.rebuildWindow;
						"--- Opened project file:".postln;
						pathName.fullPath.postln;
						d.fUpdateWindowName(pathName.fullPath);
					},{
						d.fShowError("Error: Unable to load. Invalid data in file: "
							++ pathName.fileName);
					});
				},{
					d.fShowError("Error: Unable to load. Extension must be '.txir'.  File : "
						++ pathName.fileName);
				});
			});
			Dialog.openPanel(okFunc, multipleSelection: false);
		}.defer;
	};

	// images
	d.fCreateImages = {
		{
			if (d.arrImages.notNil, {
				d.arrImages.do({arg image; image.free});
			});
			d.arrImages = 2.collect({Image.color(d.imageWidth, d.imageHeight, Color.black)});
		}.defer;
	};
	d.fResizeImages = {
		{
			var tempImage;
			// if size has changed, resize image
			if (d.arrImages[0].width != d.imageWidth or: {d.arrImages[0].height != d.imageHeight}, {
				2.do({arg i;
					tempImage = d.arrImages[i].copy;
					d.arrImages[i].free;
					d.arrImages[i] = Image.color(d.imageWidth, d.imageHeight, Color.black);
					if (d.stretchImageOnResize, {
						d.arrImages[i].draw({arg image;
							Pen.drawImage( Rect(0, 0, d.imageWidth, d.imageHeight), tempImage,
								operation: 'sourceOver', opacity: 1);
						});
					}, {
						d.arrImages[i].draw({arg image;
							Pen.use {
								Pen.smoothing_(false);
								tempImage.smooth = false;
								Pen.drawImage( Point(0, 0), tempImage,
									operation: 'sourceOver', opacity: 1);
							};
						});
					});
					tempImage.free;
				});
			});
		}.defer;
	};
	d.fClearImage = {
		{
			d.arrImages[d.imageIndex].fill(Color.black);
			d.guiData.sonogramView.refresh;
		}.defer;
	};
	d.fImportImage = {
		{
			var okFunc = {arg fileName;
				var tempImage = Image.open(fileName);
				if (tempImage.notNil and: {tempImage.isValid}
					and: {(tempImage.width + tempImage.height) > 0}, {
						d.arrImages[d.imageIndex].draw({arg image;
							Pen.use {
								Pen.smoothing_(false);
								Pen.drawImage(Rect(0, 0, d.imageWidth, d.imageHeight), tempImage,
									operation: 'sourceOver', opacity: 1);
							};
						});
						d.guiData.sonogramView.refresh;
				});
				tempImage.free;
			};
			Dialog.openPanel(okFunc, multipleSelection: false);
		}.defer;
	};
	d.fExportImage = {
		{
			var okFunc = {arg path;
				var pathName = PathName(path);
				// save settings to path
				if (pathName.notNil, {
					pathName.extension = "png";
					d.arrImages[d.imageIndex].write(pathName.fullPath);
					"=== Saved image to file: ".postln;
					pathName.fullPath.postln;
				});
			};
			Dialog.savePanel(okFunc);
		}.defer;
	};
	// Snapshot functions
	d.maxSnapshotsAllowed = 20;
	d.snapshotHistory = [];
	d.snapshotIndex = nil;
	d.fStoreSnapshot = {
		var tempImage;
		d.snapshotHistory = d.snapshotHistory.add(d.arrImages[d.imageIndex].copy);
		// remove first image if history too big
		if (d.snapshotHistory.size > d.maxSnapshotsAllowed, {
			tempImage = d.snapshotHistory.removeAt(0);
			tempImage.free;
			tempImage = nil;
		});
		d.snapshotIndex = d.snapshotHistory.size - 1;
	};
	d.fLoadSnapshot = {
		var tempImage;
		if (d.snapshotHistory.size > 0, {
			tempImage = d.snapshotHistory.clipAt(d.snapshotIndex);
			d.arrImages[d.imageIndex].fill(Color.black);
			d.arrImages[d.imageIndex].draw({arg image;
				Pen.use {
					Pen.smoothing_(false);
					Pen.drawImage( Rect(0, 0, d.imageWidth, d.imageHeight), tempImage,
						operation: 'sourceOver', opacity: 1);
				};
			});
			d.guiData.sonogramView.refresh;
		});
	};
	d.fDeleteSnapshot = {
		if (d.snapshotHistory.size > 0, {
			d.snapshotHistory.removeAt(d.snapshotIndex);
			if (d.snapshotHistory.size > 0, {
				d.snapshotIndex = d.snapshotIndex.min(d.snapshotHistory.size - 1);
			}, {
				d.snapshotIndex = nil;
			});
		});
	};

	// sound
	d.makeChordScales = { // only run once at start
		d.chordSpecs = [
			// Chord name, degrees
			["-Chord: Major", [ 0, 4, 7 ]],
			["-Chord: Major 7", [ 0, 4, 7, 11 ]],
			["-Chord: Major 7 9", [ 0, 4, 7, 11, 2 ]],
			["-Chord: Major 7 11", [ 0, 4, 7, 11, 5 ]],
			["-Chord: Major 7 +11", [ 0, 4, 7, 11, 6 ]],
			["-Chord: Major 7 13", [ 0, 4, 7, 11, 9 ]],
			["-Chord: Major 9", [ 0, 4, 7, 2 ]],
			["-Chord: Major 11", [ 0, 4, 7, 5 ]],
			["-Chord: Major +11", [ 0, 4, 7, 6 ]],
			["-Chord: Major 13", [ 0, 4, 7, 9 ]],
			["-Chord: Minor", [ 0, 3, 7 ]],
			["-Chord: Minor 7", [ 0, 3, 7, 10 ]],
			["-Chord: Minor 7 9", [ 0, 3, 7, 10, 2 ]],
			["-Chord: Minor 7 11", [ 0, 3, 7, 10, 5 ]],
			["-Chord: Minor 7 13", [ 0, 3, 7, 10, 9 ]],
			["-Chord: Minor 7 b9", [ 0, 3, 7, 10, 1 ]],
			["-Chord: Minor 7 b13", [ 0, 3, 7, 10, 8 ]],
			["-Chord: Minor 9", [ 0, 3, 7, 2 ]],
			["-Chord: Minor 11", [ 0, 3, 7, 5 ]],
			["-Chord: Minor 13", [ 0, 3, 7, 9 ]],
			["-Chord: Minor b9", [ 0, 3, 7, 1 ]],
			["-Chord: Minor b13", [ 0, 3, 7, 8 ]],
			["-Chord: Major Dominant 7", [ 0, 4, 7, 10 ]],
			["-Chord: Half-Diminished - Minor b5", [ 0, 3, 6 ]],
			["-Chord: Half-Diminished - Minor b5 7", [ 0, 3, 6, 10 ]],
			["-Chord: Half-Diminished - Minor b5 7 b9", [ 0, 3, 6, 10, 1 ]],
			["-Chord: Half-Diminished - Minor b5 7 11", [ 0, 3, 6, 10, 5 ]],
			["-Chord: Half-Diminished - Minor b5 7 b13", [ 0, 3, 6, 10, 8 ]],
			["-Chord: Half-Diminished - Minor b5 b9", [ 0, 3, 6, 1 ]],
			["-Chord: Half-Diminished - Minor b5 11", [ 0, 3, 6, 5 ]],
			["-Chord: Half-Diminished - Minor b5 b13", [ 0, 3, 6, 8 ]],
			["-Chord: Minor Major 7", [ 0, 3, 7, 11 ]],
			["-Chord: Half-Diminished - Minor 13", [ 0, 3, 6, 9 ]],
			["-Chord: Major +5", [ 0, 4, 8 ]],
			["-Chord: Major +5 7", [ 0, 4, 8, 11 ]],
			["-Chord: Major +5 9", [ 0, 4, 8, 2 ]],
			["-Chord: Major +5 11", [ 0, 4, 8, 5 ]],
			["-Chord: Major +5 13", [ 0, 4, 8, 9 ]],
			["-Chord: Minor +11", [ 0, 3, 7, 6 ]],
			["-Chord: Major b9", [ 0, 4, 7, 1 ]],
			["-Chord: Major b13", [ 0, 4, 7, 8 ]],
			["-Chord: Major +9", [ 0, 4, 7, 3 ]],
			["-Chord: Diminished b11", [ 0, 3, 6, 4 ]],
			["-Chord: Major +5 +11", [ 0, 4, 8, 6 ]],
			["-Chord: Half-Diminished - Minor b5 9", [ 0, 3, 6, 2 ]],
			["-Chord: Half-Diminished - Minor b5 7 9", [ 0, 3, 6, 10, 2 ]],
			["-Chord: Suspended 2", [ 0, 2, 7 ]],
			["-Chord: Suspended 4", [ 0, 5, 7 ]],
			["-Interval: 1 Semitone - Minor 2nd", [0, 1]],
			["-Interval: 2 Semitones - Major 2nd", [0, 2]],
			["-Interval: 3 Semitones - Minor 3rd", [0, 3]],
			["-Interval: 4 Semitones - Major 3rd", [0, 4]],
			["-Interval: 5 Semitones - Perfect 4th", [0, 5]],
			["-Interval: 6 Semitones - Tritone", [0, 6]],
			["-Interval: 7 Semitones - Perfect 5th", [0, 7]],
			["-Interval: 8 Semitones - Minor 6th", [0, 8]],
			["-Interval: 9 Semitones - Major 6th", [0, 9]],
			["-Interval: 10 Semitones - Minor 7th", [0, 10]],
			["-Interval: 11 Semitones - Major 7th", [0, 11]],
			["-Interval: 12 Semitones - Octave", [0]],
		];
		d.chordScales = d.chordSpecs.collect({arg spec, i;
			Scale(spec[1].sort, 12, name: spec[0].asSymbol);
		});
	};
	d.fPrepareScaleData = {  // only run once at start
		var validPitchesPerOct;
		var missingSizes = [];
		var chordData;
		d.makeChordScales;
		d.allTunings = Dictionary.new;
		d.allScales = Dictionary.new;
		Tuning.names.do({arg key;
			var tuning = Tuning.at(key).deepCopy;
			if (tuning.name.keep(2) == "ET", {
				tuning.name = "Equal Temperament" + tuning.size;
			});
			tuning.name = tuning.name ++ ", " + tuning.size + "PPO";
			d.allTunings.put(key, tuning);
			if ([12, 24].indexOfEqual(tuning.size).isNil, {
				missingSizes = missingSizes.add(tuning.size)
			});
		});
		missingSizes.do({arg size;
			var tuning = Tuning.et(size).name_("Equal Temperament" + size);
			var scale = Scale(Array.iota(size), size, tuning,
				"Chromatic" + size);
			d.allTunings.put(("et" ++ size).asSymbol, tuning);
			d.allScales.put(("chromatic" ++ size).asSymbol, scale);
		});
		Scale.names.do({arg key;
			var scale = Scale.at(key).deepCopy;
			scale.name = scale.name;
			d.allScales.put(key, scale);
		});
		validPitchesPerOct = Tuning.names.collect({arg key, i;
			Tuning.at(key).size;
		}).as(Set).as(Array).sort;
		// pitches per octave
		d.midiPitchesPerOctOptions = [["-All-", 'all']]
		++ validPitchesPerOct.collect({arg item;
			[item.asString, item]
		});
		d.chordScales.do({arg scale;
			d.allScales.put(scale.name, scale);
		});
	};

	d.fUpdateScaleData = {arg event, updateOptionsOnly = false;
		var validScaleKeys = [];
		var validTuningKeys = [];
		// scale
		d.allScales.keysValuesDo({arg key, scale;
			if (d.midiPitchesPerOct == 'all' or: {scale.pitchesPerOctave == d.midiPitchesPerOct}, {
				validScaleKeys = validScaleKeys.add(key);
			});
		});
		validScaleKeys.sort;
		d.midiScaleOptions = validScaleKeys.collect({arg key;
			var scale = d.allScales.at(key);
			[scale.name ++ ", " + scale.size ++ "/" ++ scale.pitchesPerOctave + "PPO", key]
		});
		if (updateOptionsOnly.not and: {validScaleKeys.indexOfEqual(d.midiScale).isNil}, {
			var ind;
			ind = d.midiScaleOptions.flop.slice(0).selectIndices({arg item, i;
				item.keep(9)== "Chromatic";
			})[0];
			// d.midiScale = validScaleKeys[0];
			d.midiScale = validScaleKeys[ind];
		});
		// tuning
		d.allTunings.keysValuesDo({arg key, tuning;
			if (d.allScales[d.midiScale].checkTuningForMismatch(tuning), {
				validTuningKeys = validTuningKeys.add(key);
			});
		});
		validTuningKeys.sort;
		d.midiTuningOptions = validTuningKeys.collect({arg key;
			var tuning = d.allTunings.at(key);
			[tuning.name, key.asSymbol]
		});
		if (updateOptionsOnly.not, {
			// select default tuning for scale
			d.midiTuning = d.allTunings.findKeyForValue(d.allScales[d.midiScale].tuning);
		});
	};

	d.fOctaveDown = {arg event, key;
		if (d[key] >= 32, {
			d[key] = d[key] - 12;
			d.fBuildArrFreqs;
			d.rebuildWindow;
		});
	};

	d.fOctaveUp = {arg event, key;
		if (d[key] <= 116, {
			d[key] = d[key] + 12;
			d.fBuildArrFreqs;
			d.rebuildWindow;
		});
	};

	d.fBuildArrFreqs = {
		var numFreqs = d.imageHeight;
		var errorInd, funcSetArrBWRs;
		thisThread.randSeed = d.randSeed;
		d.pitchesPerOctave = nil; // default
		// func to set filter bandwidth ratios
		funcSetArrBWRs = {arg arrFreqs, copies = 0;
			var numFreqs = arrFreqs.size;
			/*  V1. TOO WIDE:
			d.arrBWRs = numFreqs.collect({arg i;
			var val;
			if (i == 0, {
			val = abs(arrFreqs[1] - arrFreqs[0]) * 2 / arrFreqs[i];
			}, {
			if (i == (numFreqs - 1), {
			val = abs(arrFreqs[numFreqs - 1] - arrFreqs[numFreqs - 2]) * 2 / arrFreqs[i];
			}, {
			val = abs(arrFreqs[i + 1] - arrFreqs[i - 1]) / arrFreqs[i];
			});
			});
			val ! (1 + copies);
			}).flat;
			*/
			d.arrBWRs = numFreqs.collect({arg i;
				var val;
				if (i == 0, {
					val = abs(arrFreqs[1] - arrFreqs[0])/ arrFreqs[i];
				}, {
					if (i == (numFreqs - 1), {
						val = abs(arrFreqs[numFreqs - 1] - arrFreqs[numFreqs - 2]) / arrFreqs[i];
					}, {
						val = abs(arrFreqs[i + 1] - arrFreqs[i - 1]) * 0.5 / arrFreqs[i];
					});
				});
				val ! (1 + copies);
			}).flat;
		};
		case
		{d.freqMode == 'exp'} {
			d.arrFreqs = Array.interpolation(numFreqs, d.minFreq, d.maxFreq)
			.linexp(d.minFreq, d.maxFreq, d.minFreq, d.maxFreq);
			funcSetArrBWRs.value(d.arrFreqs);
		}
		{d.freqMode == 'lin'} {
			d.arrFreqs = Array.interpolation(numFreqs, d.minFreq, d.maxFreq);
			funcSetArrBWRs.value(d.arrFreqs);
		}
		{d.freqMode == 'harm'} {
			var holdFreqsSize = numFreqs div: (d.detunedCopies + 1);
			var baseFreqMult, arrMults, holdFreqs;
			arrMults = (1..holdFreqsSize);
			holdFreqs = arrMults * (d.midiNoteLowest + (d.globalDetuneCents * 0.01)).midicps;
			d.arrFreqs = holdFreqs.collect({arg freq;
				if (d.detuneFirstVoice, {
					baseFreqMult = 1 + (d.copyRandDetuneCents * 0.01).rand2;
				}, {
					baseFreqMult = 1;
				});
				[freq * baseFreqMult] ++ Array.fill(d.detunedCopies,
					{freq * (1 + (d.copyRandDetuneCents * 0.01).rand2)});
			}).flat;
			funcSetArrBWRs.value(d.arrFreqs);
		}
		{d.freqMode == 'harmEven'} {
			var holdFreqsSize = numFreqs div: (d.detunedCopies + 1);
			var baseFreqMult, arrMults, holdFreqs;
			arrMults = [1] ++ (2, 4..(holdFreqsSize - 1 * 2));
			holdFreqs = arrMults * (d.midiNoteLowest + (d.globalDetuneCents * 0.01)).midicps;
			d.arrFreqs = holdFreqs.collect({arg freq;
				if (d.detuneFirstVoice, {
					baseFreqMult = 1 + (d.copyRandDetuneCents * 0.01).rand2;
				}, {
					baseFreqMult = 1;
				});
				[freq * baseFreqMult] ++ Array.fill(d.detunedCopies,
					{freq * (1 + (d.copyRandDetuneCents * 0.01).rand2)});
			}).flat;
			funcSetArrBWRs.value(d.arrFreqs);
		}
		{d.freqMode == 'harmOdd'} {
			var holdFreqsSize = numFreqs div: (d.detunedCopies + 1);
			var baseFreqMult, arrMults, holdFreqs;
			arrMults = [1] ++ (3, 5..(holdFreqsSize - 1 * 2 + 1));
			holdFreqs = arrMults * (d.midiNoteLowest + (d.globalDetuneCents * 0.01)).midicps;
			d.arrFreqs = holdFreqs.collect({arg freq;
				if (d.detuneFirstVoice, {
					baseFreqMult = 1 + (d.copyRandDetuneCents * 0.01).rand2;
				}, {
					baseFreqMult = 1;
				});
				[freq * baseFreqMult] ++ Array.fill(d.detunedCopies,
					{freq * (1 + (d.copyRandDetuneCents * 0.01).rand2)});
			}).flat;
			funcSetArrBWRs.value(d.arrFreqs);
		}
		{d.freqMode == 'midiQuarter'} {
			var holdFreqsSize = numFreqs div: (d.detunedCopies + 1);
			var holdFreqs = Array.series(holdFreqsSize,
				d.midiNoteLowest + (d.globalDetuneCents * 0.01), 0.5).midicps;
			var baseFreqMult;
			d.arrFreqs = holdFreqs.collect({arg freq;
				if (d.detuneFirstVoice, {
					baseFreqMult = 1 + (d.copyRandDetuneCents * 0.01).rand2;
				}, {
					baseFreqMult = 1;
				});
				[freq * baseFreqMult] ++ Array.fill(d.detunedCopies,
					{freq * (1 + (d.copyRandDetuneCents * 0.01).rand2)});
			}).flat;
			funcSetArrBWRs.value(holdFreqs, d.detunedCopies);
			d.pitchesPerOctave = 24;
		}
		{d.freqMode == 'midiSemi'} {
			var holdFreqsSize = numFreqs div: (d.detunedCopies + 1);
			var holdFreqs = Array.series(holdFreqsSize,
				d.midiNoteLowest + (d.globalDetuneCents * 0.01), 1).midicps;
			var baseFreqMult;
			d.arrFreqs = holdFreqs.collect({arg freq;
				if (d.detuneFirstVoice, {
					baseFreqMult = 1 + (d.copyRandDetuneCents * 0.01).rand2;
				}, {
					baseFreqMult = 1;
				});
				[freq * baseFreqMult] ++ Array.fill(d.detunedCopies,
					{freq * (1 + (d.copyRandDetuneCents * 0.01).rand2)});
			}).flat;
			funcSetArrBWRs.value(holdFreqs, d.detunedCopies);
			d.pitchesPerOctave = 12;
		}
		{d.freqMode == 'midiScale'} {
			var baseFreq = (d.midiNoteLowest + (d.globalDetuneCents * 0.01)).midicps;
			var scale = d.allScales[d.midiScale];
			var holdFreqsSize = numFreqs div: (d.detunedCopies + 1);
			var holdFreqs = holdFreqsSize.collect({arg i;
				var oct = i div: scale.size;
				scale.degreeToFreq(i % scale.size, baseFreq, oct);
			});
			var baseFreqMult;
			d.arrFreqs = holdFreqs.collect({arg freq;
				if (d.detuneFirstVoice, {
					baseFreqMult = 1 + (d.copyRandDetuneCents * 0.01).rand2;
				}, {
					baseFreqMult = 1;
				});
				[freq * baseFreqMult] ++ Array.fill(d.detunedCopies,
					{freq * (1 + (d.copyRandDetuneCents * 0.01).rand2)});
			}).flat;
			funcSetArrBWRs.value(holdFreqs, d.detunedCopies);
			d.pitchesPerOctave = scale.pitchesPerOctave;
		};
		d.arrFreqs = d.arrFreqs.sort; // ascending order
		// keep only valid freqs
		errorInd = d.arrFreqs.indexOfGreaterThan(20000);
		if (errorInd.notNil, {
			d.arrFreqs = d.arrFreqs.keep(errorInd);
			d.flagFreqLimitError = true;
			d.freqLimitErrorString = "Warning: Only" + errorInd
			+ "freqs below 20kHz will play. Try reducing the image height, increasing the voices,"
			+ "or changing the scale.";
		}, {
			d.flagFreqLimitError = false;
			d.freqLimitErrorString = "";
		});
		// rebuild arrOutFreqs
		d.fBuildArrOutFreqs;
		// flag update
		d.synthSpecHasChanged = true;
		// keyboard refresh
		{
			if (d.guiData.keyboardView.notNil, {
				d.guiData.keyboardView.refresh;
			});
		}.defer;
	};  // end of d.fBuildArrFreqs

	d.fBuildArrOutFreqs = {
		var minFreq, maxFreq, maxFreqInd, maxWarpInd, ind, warp, freq;
		if (d.useWarp, {
			minFreq = d.arrFreqs.first;
			maxFreq = d.arrFreqs.last;
			maxFreqInd = d.arrFreqs.size - 1;
			maxWarpInd = d.warpCurve.size - 1;
			d.arrOutFreqWarps = Array.newClear(d.arrFreqs.size);
			d.arrOutFreqs = d.arrFreqs.size.collect({arg i;
				ind = i / maxFreqInd * maxWarpInd;
				warp = d.warpCurve.blendAt(ind);
				d.arrOutFreqWarps[i] = warp;
				if (d.freqMode == 'lin'
					or: {d.freqMode == 'harm'}
					or: {d.freqMode == 'harmEven'}
					or: {d.freqMode == 'harmOdd'},
					{
						freq = warp.linlin(0, 1, minFreq, maxFreq);
					}, {
						freq = warp.linexp(0, 1, minFreq, maxFreq);
				});
				freq;
			});
		}, {
			d.arrOutFreqWarps = Array.interpolation(d.arrFreqs.size, 0.0, 1.0);
			d.arrOutFreqs = d.arrFreqs;
		});
		if (d.imageSynth.notNil, {
			d.imageSynth.set(\outFreqs, d.arrOutFreqs);
		});
		// build linked arrays
		d.fBuildArrWarpedEQAmps;
	};
	d.fBuildArrWarpedEQAmps = {
		var maxInd = (d.arrEQAmps.size - 1);
		d.arrWarpedEQAmps = d.arrOutFreqWarps.collect({arg warp, i;
			d.arrEQAmps.blendAt(warp * maxInd);
		});
	};

	// SynthDef
	d.fCheckBuildSynthDef = {
		if (d.synthSpecHasChanged, {
			d.fBuildImageSynthDef;
			d.fAddRecordingSynthDef;
			d.fAddKeyboardSynthDef;
			d.fAddPhaseModSynthDef;
			d.fAddPhaseModSynthDef2;
			d.fAddWavetableSynthDef;
			d.synthSpecHasChanged = false; // reset
		});
	};

	d.fBuildImageSynthDef = {
		var synthDefFunc;
		// use same rand seed for consistency
		thisThread.randSeed = d.randSeed;
		synthDefFunc = { arg out, gate = 1, recordingBus, bufnum, amp, recordingLevel, lagTime,
			delayMix, delayL, delayR, decayTimeL, decayTimeR,
			reverbMix, reverbTime, reverbDamp, reverbSize, reverbEarlyRef, reverbModDepth, reverbModFreq,
			reverbLow, reverbMid, reverbHigh, reverbLoCutFreq, reverbHiCutFreq, useFX;
			var numFreqs = d.arrFreqs.size;
			var arrOutFreqs, arrAmps, arrSources, arrOuts, arrPanVals, arrModVals, arrModRatios;
			var arrNoiseVals, stepSize, switchTime, outEnv;
			var pitchShift = \pitchShift.kr(0.0).lag(lagTime);
			arrOutFreqs = \outFreqs.kr((100 ! numFreqs)) * pitchShift.midiratio;
			case {d.stereoMode == 'mono'} {
				arrPanVals = 0 ! numFreqs;
			}
			{d.stereoMode == 'stereoColor'} {
				arrPanVals = \pans.kr(0 ! numFreqs).lag(lagTime);  // pans as controls
			}
			{d.stereoMode == 'stereoLCRC'} {
				arrPanVals = numFreqs.collect({arg i; [0, -1, 0, 1].wrapAt(i)});
			}
			{d.stereoMode == 'stereoLCR'} {
				arrPanVals = numFreqs.collect({arg i; [-1, 0, 1].wrapAt(i)});
			}
			{d.stereoMode == 'stereoLR'} {
				arrPanVals = numFreqs.collect({arg i; [-1, 1].wrapAt(i)});
			}
			{d.stereoMode == 'stereoRandFreq' or: {d.stereoMode == 'stereoRandPixel'}} {
				// note: stereoRandPixel is no longer used
				arrPanVals = {rrand(-1, 1)} ! numFreqs;
			}
			{d.stereoMode == 'stereoVoiceSpread'} {
				if (d.detunedCopies == 0, { // if 1 voice, make stereo
					arrPanVals = numFreqs.collect({arg i; [-1, 1].wrapAt(i)});
				}, {
					arrPanVals = numFreqs.collect({arg i; ((i % (d.detunedCopies + 1)) / d.detunedCopies) * 2 - 1});
				});
			};
			arrAmps = \amps.kr(0 ! numFreqs).lag(lagTime);
			case
			{d.soundSource == 'sines'} {
				arrSources = numFreqs.collect({arg i;
					var amp = arrAmps[i] * d.ampCompFunc(arrOutFreqs[i]);
					Pan2.ar(SinOsc.ar(arrOutFreqs[i], mul: amp), arrPanVals[i]);
				});
			}
			{d.soundSource == 'phaseModSines'} {
				arrModVals = \mods.kr(0 ! numFreqs).lag(lagTime);
				arrSources = numFreqs.collect({arg i;
					var amp = arrAmps[i] * d.ampCompFunc(arrOutFreqs[i]);
					Pan2.ar(PMOsc.ar(arrOutFreqs[i], arrOutFreqs[i] * d.phaseModFreqRatio,
						arrModVals[i], mul: amp), arrPanVals[i]);
				});
			}
			{d.soundSource == 'phaseModSinesNoise'} {
				var noise = PinkNoise.ar * 120;
				arrNoiseVals = \noiseVals.kr(0 ! numFreqs).lag(lagTime);
				arrModVals = \mods.kr(0 ! numFreqs).lag(lagTime);
				arrSources = numFreqs.collect({arg i;
					var amp = arrAmps[i] * d.ampCompFunc(arrOutFreqs[i]);
					Pan2.ar(
						XFade2.ar(
							PMOsc.ar(arrOutFreqs[i], arrOutFreqs[i] * d.phaseModFreqRatio, arrModVals[i]),
							Resonz.ar(noise, arrOutFreqs[i], bwr: 0.004),
							pan: (arrNoiseVals[i] * 2) - 1,
							level:  amp,
						),
						arrPanVals[i]);
				});
			}
			{d.soundSource == 'phaseModSines2'} {
				stepSize = d.phaseModRatioStepOptions.flop.slice(2)
				[d.phaseModRatioStepOptions.flop.slice(1).indexOfEqual(d.phaseModRatioStep)];
				arrModVals = \mods.kr(0 ! numFreqs).lag(lagTime);
				arrModRatios = \modRatios.kr(1 ! numFreqs);
				if (stepSize != 0, { // lag if not quantized
					arrModRatios = arrModRatios.lag(lagTime);
				});
				arrSources = numFreqs.collect({arg i;
					var amp = arrAmps[i] * d.ampCompFunc(arrOutFreqs[i]);
					Pan2.ar(PMOsc.ar(arrOutFreqs[i], arrOutFreqs[i] * arrModRatios[i].round(stepSize),
						arrModVals[i], mul: amp), arrPanVals[i]);
				});
			}
			{d.soundSource == 'wavetables'} {
				arrModVals = \mods.kr(0 ! numFreqs).lag(lagTime);
				arrSources = numFreqs.collect({arg i;
					var amp = arrAmps[i] * d.ampCompFunc(arrOutFreqs[i]);
					Pan2.ar(VOsc.ar(arrModVals[i] + bufnum, arrOutFreqs[i],
						mul: amp), arrPanVals[i]);
				});
			}
			{d.soundSource == 'wavetablesNoise'} {
				var noise = PinkNoise.ar * 120;
				arrNoiseVals = \noiseVals.kr(0 ! numFreqs).lag(lagTime);
				arrModVals = \mods.kr(0 ! numFreqs).lag(lagTime);
				arrSources = numFreqs.collect({arg i;
					var amp = arrAmps[i] * d.ampCompFunc(arrOutFreqs[i]);
					Pan2.ar(
						XFade2.ar(
							VOsc.ar(arrModVals[i] + bufnum, arrOutFreqs[i]),
							Resonz.ar(noise, arrOutFreqs[i], bwr: 0.004),
							pan: (arrNoiseVals[i] * 2) - 1,
							level:  amp,
						),
						arrPanVals[i]);
				});
			}
			{d.soundSource == 'filteredNoise'} {
				var noise = PinkNoise.ar * 120;
				arrSources = numFreqs.collect({arg i;
					var amp = arrAmps[i] * d.ampCompFunc(arrOutFreqs[i]);
					Pan2.ar(
						Resonz.ar(noise, arrOutFreqs[i], bwr: 0.004, mul: amp),
						arrPanVals[i]);
				});
			};
			arrOuts = [arrSources.flop.slice(0).sum, arrSources.flop.slice(1).sum];
			// stereo delay
			arrOuts = CombC.ar(arrOuts, 5, [delayL, delayR], [decayTimeL, decayTimeR],
				(delayMix * useFX), (1 - (delayMix * useFX)) * arrOuts);
			// stereo reverb
			arrOuts = ((reverbMix * useFX) *
				JPverb.ar(arrOuts, t60: reverbTime, damp: reverbDamp, size: reverbSize,
					earlyDiff: reverbEarlyRef, modDepth: reverbModDepth, modFreq: reverbModFreq,
					low: reverbLow, mid: reverbMid, high: reverbHigh,
					lowcut: reverbLoCutFreq, highcut: reverbHiCutFreq))
			+ (arrOuts * (1 - (reverbMix * useFX)));
			// gated env
			switchTime = 0.01; // to stop clicks
			outEnv = EnvGen.kr(
				Env.new([0,1,1,0],[switchTime, 1, switchTime],'lin', 2),
				gate,
				doneAction: 2
			);
			arrOuts = outEnv * arrOuts;
			// send arrOuts to out bus and recording bus
			Out.ar(out, amp * arrOuts);
			Out.ar(recordingBus, recordingLevel * arrOuts);
		}; // end of synthDefFunc
		d.imageSynthDef = SynthDef(\imageSynth, synthDefFunc).add;
	}; // end of d.fBuildImageSynthDef

	// Play and Record
	d.fStopSound = {
		if (d.imageSynth.notNil or: {d.imageSynth.isPlaying}, {
			// d.imageSynth.free;
			d.imageSynth.set(\gate, 0);
			d.imageSynth = nil;
		});
		if (d.playRoutine.notNil, {
			d.playRoutine.stop;
			d.playRoutine = nil;
		});
	};
	d.fPlaySound = {arg event, startPlayAction = {}, fromStart = false;
		var numFreqs = d.arrFreqs.size;
		var lastFreqIndex = d.imageHeight - 1;
		var freqIndOffset = d.imageHeight - numFreqs;  // offset if some freqs out of range
		var lastTimeDomainIndex = d.imageWidth - 1;
		var timeStep = d.playLength / d.imageWidth;
		var timeStretchesSize = d.arrTimeStretches.size;
		var arrSpectrumData, waitTime, stretchIndex, envIndex, pitchShift, pitchShiftIndex;
		d.fStopSound;  // stop any older synth
		if (fromStart, {
			d.fSetPlayPosition(0);
		});
		// prepare image data
		arrSpectrumData = (0..lastTimeDomainIndex).collect ({ |indexTimeDomain|
			// freqs in reverse order because image y-axis is top down
			(lastFreqIndex..freqIndOffset).collect ({ |indexFreq|
				var pixelColor = Image.pixelToColor(d.arrImages[d.imageIndex].getPixel(indexTimeDomain, indexFreq));
				[pixelColor.red, pixelColor.green, pixelColor.blue, pixelColor.alpha]
			})
		});
		d.playRoutine = fork   // routine
		{
			// make synth and register
			d.imageSynth = Synth(\imageSynth, args: [\out, d.audioOutBus, \gate, 1, \recordingBus, d.recordingBus,
				\bufnum, d.arrWTBuffers[0].bufnum, \outFreqs, d.arrOutFreqs,
				\amp, 0, \recordingLevel, d.recordingLevel, \lagTime, timeStep,
				'delayMix', d.delayMix, 'delayL', d.delayL, 'delayR', d.delayR,
				'decayTimeL', d.decayTimeL, 'decayTimeR', d.decayTimeR,
				'reverbMix', d.reverbMix, 'reverbTime', d.reverbTime, 'reverbDamp', d.reverbDamp,
				'reverbSize', d.reverbSize, 'reverbEarlyRef', d.reverbEarlyRef,
				'reverbModDepth',  d.reverbModDepth, 'reverbModFreq', d.reverbModFreq,
				'reverbLow', d.reverbLow, 'reverbMid', d.reverbMid, 'reverbHigh', d.reverbHigh,
				'reverbLoCutFreq', d.reverbLoCutFreq, 'reverbHiCutFreq', d.reverbHiCutFreq,
				'useFX', d.useFX,
			]);
			d.imageSynth.register;
			// wait until synth built
			s.sync;
			// run any passed function
			startPlayAction.value;
			// set spectrum at intervals
			while {d.playPosition < arrSpectrumData.size} {
				var thisSpectrum, vol, arrPanVals, arrModVals, arrNoiseVals, arrModRatios, ampScale;
				if (d.imageSynth.notNil, {
					if (d.stereoMode == 'stereoColor', {
						arrPanVals = Array.newClear(numFreqs);
					});
					if (d.soundSource == 'wavetablesNoise' or: {d.soundSource == 'phaseModSinesNoise'}, {
						arrModVals = Array.newClear(numFreqs);
						arrNoiseVals = Array.newClear(numFreqs);
					});
					if (d.soundSource == 'phaseModSines' or: {d.soundSource == 'wavetables'}, {
						arrModVals = Array.newClear(numFreqs);
					});
					if (d.soundSource == 'phaseModSines2', {
						arrModVals = Array.newClear(numFreqs);
						arrModRatios = Array.newClear(numFreqs);
					});
					thisSpectrum = arrSpectrumData[d.playPosition]
					.collect({ |thisSpectrumAmps, i|
						var colArray = thisSpectrumAmps[0..2];
						var normCols;
						// set pans if needed
						if (d.stereoMode == 'stereoColor', {
							normCols = colArray.normalize;
							arrPanVals[i] = normCols[0] - normCols[1];
						});
						// set modulation
						case {d.soundSource == 'phaseModSines'}  {
							arrModVals[i] = colArray[2] * d.phaseModMaxModulation;
						}
						{d.soundSource == 'phaseModSinesNoise'}  {
							arrModVals[i] = colArray[2] * d.phaseModMaxModulation;
							arrNoiseVals[i] = colArray[0];
						}
						{d.soundSource == 'phaseModSines2'}  {
							arrModVals[i] = colArray[2] * d.phaseModMaxModulation;
							arrModRatios[i] = colArray[0].linlin(0, 1,
								d.phaseModMinRatio, d.phaseModMaxRatio);
						}
						{d.soundSource == 'wavetables'} {
							arrModVals[i] = colArray[2] * 1.99; // for 3 wavetables
						}
						{d.soundSource == 'wavetablesNoise'} {
							arrModVals[i] = colArray[2] * 1.99; // for 3 wavetables
							arrNoiseVals[i] = colArray[0];
						};
						// colArray.sum / 3 * thisSpectrumAmps[3];
						colArray.maxItem * thisSpectrumAmps[3];
					});
					// set lag
					timeStep = d.playLength / d.imageWidth;
					if (d.useTimeStretch, {
						stretchIndex = (d.playPosition / d.imageWidth
							* timeStretchesSize * d.timeStretchRateMulti).asInteger;
						waitTime = timeStep * d.arrTimeStretches.wrapAt(stretchIndex);
					}, {
						waitTime = timeStep;
					});
					d.imageSynth.set(\lagTime, waitTime);
					// set pitchShift
					if (d.usePitchShift, {
						pitchShiftIndex = (d.playPosition / d.imageWidth * d.arrPitchShifts.size).asInteger;
						pitchShift = d.arrPitchShifts.wrapAt(pitchShiftIndex);
					}, {
						pitchShift = 0.0;
					});
					d.imageSynth.set(\pitchShift, pitchShift);
					// compress the output level by blending between real and normalised levels
					ampScale = blend(numFreqs, thisSpectrum.sum.max(1), d.masterCompress).reciprocal;
					// apply EQ
					if (d.useEQ, {
						if (d.useWarp, {
							ampScale = ampScale * d.arrWarpedEQAmps;
						}, {
							ampScale = ampScale * d.arrEQAmps;
						});
					});
					// apply Env
					if (d.useEnv, {
						envIndex = d.envCurve.size * d.playPosition / d.imageWidth;
						ampScale = ampScale * (d.envCurve.blendAt(envIndex) * 2).squared;
					});
					// set volume
					vol = d.volume * 5; // boost level
					d.imageSynth.set(\amp, vol, \amps, thisSpectrum * ampScale);
					// set pans if needed
					if (d.stereoMode == 'stereoColor', {
						d.imageSynth.set(\pans, arrPanVals);
					});
					// set modulation
					case {d.soundSource == 'phaseModSines' or: {d.soundSource == 'wavetables'}} {
						d.imageSynth.set(\mods, arrModVals);
					}
					{d.soundSource == 'phaseModSines2'} {
						d.imageSynth.set(\mods, arrModVals, \modRatios, arrModRatios);
					}
					{d.soundSource == 'wavetablesNoise' or: {d.soundSource == 'phaseModSinesNoise'}} {
						d.imageSynth.set(\mods, arrModVals, \noiseVals, arrNoiseVals);
					}
				});
				waitTime.wait;
				d.playPosition = d.playPosition + 1;
				// return to start if looping
				if (d.playLooped and: {d.playPosition >= arrSpectrumData.size}, {
					d.playPosition = 0;
				});
				d.fSetPlayPosition(d.playPosition);
			};
			d.imageSynth.set(\amps, 0 ! numFreqs);
			timeStep.wait;
			d.fSetPlayPosition(0);
			// allow time for reverb tail to decay
			if ((d.reverbMix * d.useFX.binaryValue) > 0 or: {(d.delayMix * d.useFX.binaryValue) > 0}, {
				[d.reverbTime, d.decayTimeL, d.decayTimeR].maxItem.wait;
			});
			d.fStopSound;
		}; // end of fork
	};  // end of d.fPlaySound
	// Record funcs
	d.fOpenRecordFile = {
		if (d.recordBuffer.notNil, {
			d.recordBuffer.close;
		},{
			d.recordBuffer = Buffer.alloc(s, 65536, 2);
		});
		case
		{d.recordFormat == 'aiff16'} {
			d.recHeaderFormat = "aiff";
			d.recSampleFormat = "int16";
		}
		{d.recordFormat == 'aiff24'} {
			d.recHeaderFormat = "aiff";
			d.recSampleFormat = "int24";
		}
		{d.recordFormat == 'aiff32'} {
			d.recHeaderFormat = "aiff";
			d.recSampleFormat =  "float32";
		}
		{d.recordFormat == 'wav16'} {
			d.recHeaderFormat = "wav";
			d.recSampleFormat = "int16";
		}
		{d.recordFormat == 'wav24'} {
			d.recHeaderFormat = "wav";
			d.recSampleFormat = "int24";
		}
		{d.recordFormat == 'wav32'} {
			d.recHeaderFormat = "wav";
			d.recSampleFormat =  "float32";
		};
		Dialog.savePanel({ arg path;
			var pathName;
			// path.postln;
			pathName = PathName(path);
			pathName.extension = d.recHeaderFormat;
			d.fUpdateRecordFilenames(pathName.fullPath);
			d.recordBuffer.write(d.currentRecFileName, d.recHeaderFormat, d.recSampleFormat, 0, 0, true);
			d.fUpdateRecordClockTime(0.0);
			d.fUpdateRecordingStatus(" Ready to Record");
			d.rebuildWindow;
		},{
			// "cancelled".postln;
		});
	};
	d.fStartRecording = {
		if (d.recordingStatus == " Ready to Record", {
			d.isRecording = true;
			d.fUpdateRecordingStatus(" RECORDING IN PROGRESS...");
			d.fSetPlayPosition(0); // rewind first
			d.fPlaySound({
				// make synth and register
				d.recordingSynth = Synth.tail(nil, "imageSynthRecord",
					["bufnum", d.recordBuffer, "recordTime", d.recordTime]);
				d.recordingSynth.register;
				// routine to update record time
				d.recordClockRoutine = Routine {
					s.latency.wait;
					loop {
						0.1.wait;
						d.fUpdateRecordClockTime(d.recordClockTime + 0.1);
					}
				}.play;
			});
			if (d.recordEndFunc.notNil, {
				d.recordEndFunc.remove;    // remove old
			});
			// OSC responder if synth stops when recordTime reached
			d.recordEndFunc = OSCFunc(
				{ |msg|
					d.recordingSynth = nil;
					d.fStopSound;
					{d.rebuildWindow}.defer(0.01);
					d.fStopRecording;
				},
				'/imageRecordSynthEnded'
			).oneShot;
			d.rebuildWindow;
		}, {
			d.fShowError(" Warning: Unable to record. Open a record file first.");
		});
	};
	d.fStopRecording = {
		if (d.recordEndFunc.notNil, {
			d.recordEndFunc.remove;    // remove old func
			d.recordEndFunc = nil;
		});
		if (d.isRecording, {
			d.isRecording = false;
			if (d.recordingSynth.notNil, {
				// d.recordingSynth.free;
				d.recordingSynth.set(\gate, 0);
				d.recordingSynth = nil;
			});
			d.fUpdateRecordingStatus(" Recording finished.  Open a new record file before next recording.");
			// close buffer and output file and free
			d.recordBuffer.close;
			d.fUpdateRecordFilenames("");
			{
				d.recordClockRoutine.stop;
				d.fUpdateRecordClockTime(0.0);
			}.defer;
		});
	};
	d.fUpdateRecordingStatus = {arg event, string;
		d.recordingStatus = string;
		{
			d.guiData.recordingStatusView.string = d.recordingStatus;
			if (d.isRecording, {
				d.guiData.recordingStatusView.background_(d.colRecordTint);
			}, {
				d.guiData.recordingStatusView.background_(Color.white);
			});
		}.defer;
	};
	d.fUpdateRecordClockTime = {arg event, newTime;
		d.recordClockTime = newTime;
		{
			if (d.guiData.recordClockView.notNil, {
				if (d.guiData.recordClockView.notClosed, {
					d.guiData.recordClockView.string = d.recordClockTime.asString;
					if (d.recordClockTime > 0, {
						d.guiData.recordClockView.background_(d.colRecordTint);
					}, {
						d.guiData.recordClockView.background_(Color.white);
					});
				});
			});
		}.defer;
	};
	d.fUpdateRecordFilenames = { arg event, argName;
		if (d.currentRecFileName.size > 0, {
			d.previousRecFileName = d.currentRecFileName;
		});
		d.currentRecFileName = argName;
		{
			if (d.guiData.previousFileView.notNil, {
				if (d.guiData.previousFileView.notClosed, {
					d.guiData.previousFileView.string = d.previousRecFileName;
				});
			});
			if (d.guiData.currentFileView.notNil, {
				if (d.guiData.currentFileView.notClosed, {
					d.guiData.currentFileView.string = d.currentRecFileName;
				});
			});
		}.defer;
	};

};  // end of d.fDefineFunctions

d.fDefineFunctions; // run function

// more funcs  ===========

d.fDefineFunctions2 = {
	// drawing
	d.drawPoints = ();
	d.fUpdateToolRandVals = {
		d.toolRandWidthVal = (d.toolWidth * (1 + 0.95.rand2)).max(1);
		d.toolRandHeightVal = (d.toolHeight * (1 + 0.95.rand2)).max(1);
		d.toolRandRotationVal = 180.rand2;
		if (d.toolMode == 'paintSpray', {
			if (d.sprayMode.asString.keep(3) == "box", {
				d.toolRandSprayCount = d.toolWidth * d.toolHeight * d.sprayDensity * 0.01;
				d.toolRandSprayLefts = {d.toolWidth.rand} ! d.toolRandSprayCount;
				d.toolRandSprayTops = {d.toolHeight.rand} ! d.toolRandSprayCount;
			}, {
				d.toolRandSprayCount = d.sprayRadius.squared * d.sprayDensity * 0.01;
				d.toolRandSprayProps = {1.0.rand.linexp(0, 1, 0.00001, 1)} ! d.toolRandSprayCount;
				// d.toolRandSprayProps = {0.00001.exprand(1.0)} ! d.toolRandSprayCount;
				d.toolRandSprayAngles = {2pi.rand} ! d.toolRandSprayCount;
			});
		});
	};

	d.fDrawShape = {arg event, drawOutline = false;
		var drawSingleShape;
		drawSingleShape = { arg color1, color2, indentX, indentY;
			var pt, fillAction;
			var mouseDownPoint = d.drawPoints.mouseDownPoint;
			var mouseCurrentPoint = d.drawPoints.mouseCurrentPoint;
			color1 = color1 ? d.drawColor1;
			color2 = color2 ? d.drawColor2;
			indentX = indentX ? 0;
			indentY = indentY ? 0;
			fillAction = {arg rect;
				var fadeCols;
				var getFadeColors = {
					case
					{d.fadeMode == 'fadeInTransparent'} {fadeCols = [Color.clear, color1]; }
					{d.fadeMode == 'fadeInBlack'} {fadeCols = [Color.black, color1]; }
					{d.fadeMode == 'fadeOutTransparent'} {fadeCols = [color1, Color.clear]; }
					{d.fadeMode == 'fadeOutBlack'} {fadeCols = [color1, Color.black]; }
					{d.fadeMode == 'crossFade'} {fadeCols = [color1, color2]; }
				};
				case
				{d.fillMode == 'outline'} {
					Pen.color = color1;
					Pen.stroke;
				}
				{d.fillMode == 'fillFlat'} {
					Pen.color = color1;
					Pen.fill;
				}
				{d.fillMode == 'fillCircularFade'} {
					var rad = dist(rect.leftTop, rect.center).max(2) * 0.7;
					getFadeColors.value;
					Pen.fillRadialGradient(rect.center, rect.center, 0, rad, fadeCols[0], fadeCols[1]);
				}
				{d.fillMode == 'fillHorizontalFade'} {
					getFadeColors.value;
					Pen.fillAxialGradient(rect.leftTop, rect.rightTop, fadeCols[0], fadeCols[1]);
				}
				{d.fillMode == 'fillVerticalFade'} {
					getFadeColors.value;
					Pen.fillAxialGradient(rect.leftTop, rect.leftBottom, fadeCols[1], fadeCols[0]);
				}
				{d.fillMode == 'fillSlopeUpFade'} {
					getFadeColors.value;
					Pen.fillAxialGradient(rect.leftBottom, rect.rightTop, fadeCols[0], fadeCols[1]);
				}
				{d.fillMode == 'fillSlopeDownFade'} {
					getFadeColors.value;
					Pen.fillAxialGradient(rect.leftTop, rect.rightBottom, fadeCols[0], fadeCols[1]);
				}
			};  // end of fillAction{}
			Pen.use {
				Pen.smoothing_(false);
				Pen.translate(indentX, indentY); // apply indents
				case  // check tool mode
				{d.toolMode == 'dragDrawLine'} {
					var controlPt, midPt, curvePt;
					Pen.moveTo(mouseDownPoint);
					case   // check line mode
					{d.lineMode == 'straight'} {
						Pen.lineTo(mouseCurrentPoint);
					}
					{d.lineMode == 'horizontal'} {
						Pen.lineTo(Point(mouseCurrentPoint.x, mouseDownPoint.y));
					}
					{d.lineMode == 'vertical'} {
						Pen.lineTo(Point(mouseDownPoint.x, mouseCurrentPoint.y));
					}
					{d.lineMode == 'curve'} {
						midPt = mouseCurrentPoint + mouseDownPoint * 0.5;
						if (mouseDownPoint.x < mouseCurrentPoint.x, {
							if (mouseDownPoint.y < mouseCurrentPoint.y, {
								controlPt = Point(mouseDownPoint.x, mouseCurrentPoint.y);
							}, {
								controlPt = Point(mouseCurrentPoint.x, mouseDownPoint.y);
							});
						}, {
							if (mouseDownPoint.y < mouseCurrentPoint.y, {
								controlPt = Point(mouseCurrentPoint.x, mouseDownPoint.y);
							}, {
								controlPt = Point(mouseDownPoint.x, mouseCurrentPoint.y);
							});
						});
						curvePt = midPt + ((controlPt - midPt) * d.lineCurve);
						Pen.quadCurveTo(Point(mouseCurrentPoint.x, mouseCurrentPoint.y), curvePt);
					};
					Pen.color = color1;
					Pen.stroke;
				}
				{drawOutline and: {d.toolMode == 'blurDragBox' or: {d.toolMode == 'colorizeDragBox'}}} {
					var left = min(mouseCurrentPoint.x, mouseDownPoint.x);
					var top = min(mouseCurrentPoint.y, mouseDownPoint.y);
					var width = abs(mouseCurrentPoint.x - mouseDownPoint.x);
					var height = abs (mouseCurrentPoint.y - mouseDownPoint.y);
					var rect1 = Rect(left, top, width, height);
					var rect2 = rect1.insetBy(1);
					Pen.color = Color.white;
					Pen.addRect(rect1);
					Pen.stroke;
					Pen.color = Color.black;
					Pen.addRect(rect2);
					Pen.stroke;
				}
				{d.toolMode == 'dragDrawBox'} {
					var left = min(mouseCurrentPoint.x, mouseDownPoint.x);
					var top = min(mouseCurrentPoint.y, mouseDownPoint.y);
					var width = abs(mouseCurrentPoint.x - mouseDownPoint.x);
					var height = abs (mouseCurrentPoint.y - mouseDownPoint.y);
					var rect = Rect(left, top, width, height);
					Pen.addRect(rect);
					fillAction.value(rect);
				}
				{d.toolMode == 'dragDrawOval'} {
					var left = min(mouseCurrentPoint.x, mouseDownPoint.x);
					var top = min(mouseCurrentPoint.y, mouseDownPoint.y);
					var width = abs(mouseCurrentPoint.x - mouseDownPoint.x);
					var height = abs (mouseCurrentPoint.y - mouseDownPoint.y);
					var rect = Rect(left, top, width, height);
					Pen.addOval(rect);
					fillAction.value(rect);
				}
				{d.toolMode == 'dragDrawTriangle'} {
					var pt1, pt2, pt3, cpt1, rect, modeString;
					rect = Rect.fromPoints(mouseDownPoint, mouseCurrentPoint);
					case
					{d.triangleMode == 'equilateralTop' or: {d.triangleMode == 'curvedEquilateralTop'}} {
						pt1 = rect.leftTop;
						pt2 = rect.rightTop;
						pt3 = Point(rect.left + (rect.width div: 2), rect.bottom);
						cpt1 = Point(rect.left + (rect.width div: 2), rect.top);
					}
					{d.triangleMode == 'equilateralBottom' or: {d.triangleMode == 'curvedEquilateralBottom'}} {
						pt1 = rect.leftBottom;
						pt2 = rect.rightBottom;
						pt3 = Point(rect.left + (rect.width div: 2), rect.top);
						cpt1 = Point(rect.left + (rect.width div: 2), rect.bottom);
					}
					{d.triangleMode == 'equilateralLeft' or: {d.triangleMode == 'curvedEquilateralLeft'}} {
						pt1 = rect.leftBottom;
						pt2 = rect.leftTop;
						pt3 = Point(rect.right, rect.top + (rect.height div: 2));
						cpt1 = Point(rect.left, rect.top + (rect.height div: 2));
					}
					{d.triangleMode == 'equilateralRight' or: {d.triangleMode == 'curvedEquilateralRight'}} {
						pt1 = rect.rightBottom;
						pt2 = rect.rightTop;
						pt3 = Point(rect.left, rect.top + (rect.height div: 2));
						cpt1 = Point(rect.right, rect.top + (rect.height div: 2));
					}
					{d.triangleMode == 'rtAngledTopLeft' or: {d.triangleMode == 'curvedRtAngledTopLeft'}} {
						pt1 = rect.rightTop;
						pt2 = rect.leftTop;
						pt3 = rect.leftBottom;
						cpt1 = pt2;
					}
					{d.triangleMode == 'rtAngledTopRight' or: {d.triangleMode == 'curvedRtAngledTopRight'}} {
						pt1 = rect.leftTop;
						pt2 = rect.rightTop;
						pt3 = rect.rightBottom;
						cpt1 = pt2;
					}
					{d.triangleMode == 'rtAngledBottomLeft' or: {d.triangleMode == 'curvedRtAngledBottomLeft'}} {
						pt1 = rect.leftTop;
						pt2 = rect.leftBottom;
						pt3 = rect.rightBottom;
						cpt1 = pt2;
					}
					{d.triangleMode == 'rtAngledBottomRight' or: {d.triangleMode == 'curvedRtAngledBottomRight'}} {
						pt1 = rect.rightTop;
						pt2 = rect.rightBottom;
						pt3 = rect.leftBottom;
						cpt1 = pt2;
					};
					modeString = d.triangleMode.asString;
					Pen.moveTo(pt1);
					if (modeString.keep("curvedEquilateral".size) == "curvedEquilateral", {
						Pen.lineTo(pt2);
						Pen.quadCurveTo(pt3, cpt1);
						Pen.quadCurveTo(pt1, cpt1);
					}, {
						if (modeString.keep("curvedRtAngled".size) == "curvedRtAngled", {
							Pen.lineTo(pt2);
							Pen.lineTo(pt3);
							Pen.quadCurveTo(pt1, cpt1);
						}, {
							Pen.lineTo(pt2);
							Pen.lineTo(pt3);
							Pen.lineTo(pt1);
						});
					});
					fillAction.value(rect);
				}
				{d.toolMode == 'dragDrawHorizBar'} {
					var left = 0;
					var top = min(mouseCurrentPoint.y, mouseDownPoint.y);
					var width = d.imageWidth;
					var height = abs (mouseCurrentPoint.y - mouseDownPoint.y);
					var rect = Rect(left, top, width, height);
					Pen.addRect(rect);
					fillAction.value(rect);
				}
				{d.toolMode == 'dragDrawVertBar'} {
					var left = min(mouseCurrentPoint.x, mouseDownPoint.x);
					var top = 0;
					var width = abs(mouseCurrentPoint.x - mouseDownPoint.x);
					var height = d.imageHeight;
					var rect = Rect(left, top, width, height);
					Pen.addRect(rect);
					fillAction.value(rect);
				}
				{d.toolMode == 'paintBoxes'} {
					var width = (d.toolWidth.blend(d.toolRandWidthVal, d.toolRandWidthMix)).max(1);
					var height, rect, posX, posY;
					var rotation = d.toolRotation.blend(d.toolRandRotationVal, d.toolRandRotationMix);
					if (d.toolUseWidthForHeight, {
						height = width;
					}, {
						height = (d.toolHeight.blend(d.toolRandHeightVal, d.toolRandHeightMix)).max(1);
					});
					if (d.snapToTimeGrid, {
						posX = 0; // left align
					}, {
						posX = (width div: 2).neg;  // centre align
					});
					posY = (height div: 2).neg;  // centre align
					rect = Rect(posX, posY, width, height);
					Pen.use{
						Pen.translate(mouseCurrentPoint.x, mouseCurrentPoint.y);
						Pen.rotate(rotation.degrad);
						Pen.addRect(rect);
						fillAction.value(rect);
					};
				}
				{d.toolMode == 'paintOvals'} {
					var width = (d.toolWidth.blend(d.toolRandWidthVal, d.toolRandWidthMix)).max(1);
					var height, rect, posX, posY;
					var rotation = d.toolRotation.blend(d.toolRandRotationVal, d.toolRandRotationMix);
					if (d.toolUseWidthForHeight, {
						height = width;
					}, {
						height = (d.toolHeight.blend(d.toolRandHeightVal, d.toolRandHeightMix)).max(1);
					});
					if (d.snapToTimeGrid, {
						posX = 0; // left align
					}, {
						posX = (width div: 2).neg;  // centre align
					});
					posY = (height div: 2).neg;  // centre align
					rect = Rect(posX, posY, width, height);
					Pen.use{
						Pen.translate(mouseCurrentPoint.x, mouseCurrentPoint.y);
						Pen.rotate(rotation.degrad);
						Pen.addOval(rect);
						fillAction.value(rect);
					};
				}
				{d.toolMode == 'paintTriangles'} {
					var width = (d.toolWidth.blend(d.toolRandWidthVal, d.toolRandWidthMix)).max(1);
					var rotation = d.toolRotation.blend(d.toolRandRotationVal, d.toolRandRotationMix);
					var height, posX, posY;
					var pt1, pt2, pt3, cpt1, rect, modeString;
					if (d.toolUseWidthForHeight, {
						height = width;
					}, {
						height = (d.toolHeight.blend(d.toolRandHeightVal, d.toolRandHeightMix)).max(1);
					});
					if (d.snapToTimeGrid, {
						posX = 0; // left align
					}, {
						posX = (width div: 2).neg;  // centre align
					});
					posY = (height div: 2).neg;
					case
					{d.triangleMode == 'equilateralTop' or: {d.triangleMode == 'curvedEquilateralTop'}} {
						pt1 = Point(0, 0);
						pt2 = Point(width * 0.5, height);
						pt3 = Point(width, 0);
						cpt1 = Point(width * 0.5, 0);
					}
					{d.triangleMode == 'equilateralBottom' or: {d.triangleMode == 'curvedEquilateralBottom'}} {
						pt1 = Point(0, height);
						pt2 = Point(width * 0.5, 0);
						pt3 = Point(width, height);
						cpt1 = Point(width * 0.5, height);
					}
					{d.triangleMode == 'equilateralLeft' or: {d.triangleMode == 'curvedEquilateralLeft'}} {
						pt1 = Point(0, 0);
						pt2 = Point(width, height * 0.5);
						pt3 = Point(0, height);
						cpt1 = Point(0, height * 0.5);
					}
					{d.triangleMode == 'equilateralRight' or: {d.triangleMode == 'curvedEquilateralRight'}} {
						pt1 = Point(width, 0);
						pt2 = Point(0, height * 0.5);
						pt3 = Point(width, height);
						cpt1 = Point(width, height * 0.5);
					}
					{d.triangleMode == 'rtAngledTopLeft' or: {d.triangleMode == 'curvedRtAngledTopLeft'}} {
						pt1 = Point(width, 0);
						pt2 = Point(0, 0);
						pt3 = Point(0, height);
						cpt1 = pt2;
					}
					{d.triangleMode == 'rtAngledTopRight' or: {d.triangleMode == 'curvedRtAngledTopRight'}} {
						pt1 = Point(0, 0);
						pt2 = Point(width, 0);
						pt3 = Point(width, height);
						cpt1 = pt2;
					}
					{d.triangleMode == 'rtAngledBottomLeft' or: {d.triangleMode == 'curvedRtAngledBottomLeft'}} {
						pt1 = Point(0, 0);
						pt2 = Point(0, height);
						pt3 = Point(width, height);
						cpt1 = pt2;
					}
					{d.triangleMode == 'rtAngledBottomRight' or: {d.triangleMode == 'curvedRtAngledBottomRight'}} {
						pt1 = Point(width, 0);
						pt2 = Point(width, height);
						pt3 = Point(0, height);
						cpt1 = pt2;
					};
					modeString = d.triangleMode.asString;
					Pen.use{
						Pen.translate(mouseCurrentPoint.x, mouseCurrentPoint.y);
						Pen.rotate(rotation.degrad);
						Pen.translate(posX, posY);
						Pen.moveTo(pt1);
						if (modeString.keep("curvedEquilateral".size) == "curvedEquilateral", {
							Pen.quadCurveTo(pt2, cpt1);
							Pen.quadCurveTo(pt3, cpt1);
							Pen.lineTo(pt1, cpt1);
						}, {
							if (modeString.keep("curvedRtAngled".size) == "curvedRtAngled", {
								Pen.lineTo(pt2);
								Pen.lineTo(pt3);
								Pen.quadCurveTo(pt1, cpt1);
							}, {
								Pen.lineTo(pt2);
								Pen.lineTo(pt3);
								Pen.lineTo(pt1);
							});
						});
						rect = Rect.fromPoints(
							Point([pt1.x, pt2.x, pt3.x].minItem, [pt1.y, pt2.y, pt3.y].minItem),
							Point([pt1.x, pt2.x, pt3.x].maxItem, [pt1.y, pt2.y, pt3.y].maxItem),
						);
						fillAction.value(rect);
					};
				}
				{d.toolMode == 'paintLines'} {
					var width, widthRatio, posX, endPtHeight;
					var rotation = d.toolRotation.blend(d.toolRandRotationVal, d.toolRandRotationMix);
					Pen.use{
						Pen.translate(mouseCurrentPoint.x, mouseCurrentPoint.y);
						Pen.rotate(rotation.degrad);
						case   // check line mode
						{d.paintLineMode == 'straight'} {
							width = (d.toolWidth.blend(d.toolRandWidthVal, d.toolRandWidthMix)).max(1);
							if (d.snapToTimeGrid, {
								posX = 0; // left align
							}, {
								posX = (width div: 2).neg;  // centre align
							});
							Pen.moveTo(Point(posX, 0));
							Pen.lineTo(Point(posX + width, 0));
						}
						{d.paintLineMode == 'curve'} {
							width = (d.toolWidth.blend(d.toolRandWidthVal, d.toolRandWidthMix)).max(1);
							widthRatio = 1.0.blend(0.70710, d.lineCurve.abs);
							width = width * widthRatio;
							if (d.snapToTimeGrid, {
								posX = 0; // left align
							}, {
								posX = (width div: 2).neg;  // centre align
							});
							endPtHeight = width * d.lineCurve;
							Pen.moveTo(Point(posX, 0));
							Pen.quadCurveTo(Point(posX + width, endPtHeight.neg), Point(posX + width, 0));
						};
						Pen.color = color1;
						Pen.stroke;
					};
				}
				{d.toolMode == 'paintSpray'} {
					var count, width, height;
					if (d.sprayMode.asString.keep(3) == "box", {
						width = d.toolWidth.max(2);
						if (d.toolUseWidthForHeight, {
							height = width;
						}, {
							height = d.toolHeight.max(2);
						});
						// box spray
						count = width * height * d.sprayDensity * 0.01;
						d.toolRandSprayCount.do({arg i;
							Pen.use{
								var left = d.toolRandSprayLefts[i];
								var top = d.toolRandSprayTops[i];
								var halfW = width * 0.5;
								var halfH = height * 0.5;
								var getProp = {
									var propX, propY;
									propX = abs(left - halfW) / halfW;
									propY = abs(top - halfH) / halfH;
									[propX, propY].mean;
								};
								case
								{d.sprayMode == 'boxFadeOutTransparent'} {
									Pen.color = color1.blend(Color.clear, getProp.value);
								}
								{d.sprayMode == 'boxFadeOutBlack'} {
									Pen.color = color1.blend(Color.black, getProp.value);
								}
								{d.sprayMode == 'boxFlat'} {
									Pen.color = color1;
								};
								Pen.translate(mouseCurrentPoint.x, mouseCurrentPoint.y);
								Pen.translate(left - (width * 0.5), top - (height * 0.5));
								Pen.lineTo(Point(0, 1));
								Pen.stroke;
							};
						});
					}, {
						// circular spray
						count = d.sprayRadius.squared * d.sprayDensity * 0.01;
						d.toolRandSprayCount.do({arg i;
							Pen.use{
								var prop = d.toolRandSprayProps[i];
								var angle = d.toolRandSprayAngles[i];
								case
								{d.sprayMode == 'circularFadeOutTransparent'} {
									Pen.color = color1.blend(Color.clear, prop);
								}
								{d.sprayMode == 'circularFadeOutBlack'} {
									Pen.color = color1.blend(Color.black, prop);
								}
								{d.sprayMode == 'circularFlat'} {
									Pen.color = color1;
								};
								Pen.translate(mouseCurrentPoint.x, mouseCurrentPoint.y);
								Pen.rotate(angle);
								Pen.translate(prop * d.sprayRadius);
								Pen.lineTo(Point(0, 1));
								Pen.stroke;
							};
						});
					});
				}
				{d.toolMode == 'selectDragBox' or: {d.toolMode == 'scaleFilterDragBox'}
					or: {d.toolMode == 'perlinNoiseDragBox'}
					or: {d.toolMode == 'compressionDragBox'}
				} {
					var rect1, rect2, cols, widths, heights;
					if (d.selectionBox.notNil, {
						rect1 = d.selectionBox;
						rect2 = rect1.insetBy(1);
						cols = [Color(1, 1, 1, 0.7), Color(0, 0, 0, 0.7)];
						widths = [8 / d.pixelWidth, 6 / d.pixelWidth];
						heights = [8 / d.pixelHeight, 6 / d.pixelHeight];
						Pen.color = cols[0];
						Pen.addRect(rect1);
						Pen.stroke;
						Pen.color = cols[1];
						Pen.addRect(rect2);
						Pen.stroke;
						[d.selectionBox.leftBottom, d.selectionBox.leftTop,
							d.selectionBox.rightBottom, d.selectionBox.rightTop]
						.do({arg point;
							2.do({arg i;
								Pen.color = cols[i];
								Pen.addOval(Rect(0, 0, widths[i], heights[i]).center_(point));
								Pen.stroke;
							});
						});
					});
				}
				; // end of case
			};  // end of Pen.use {}
		};   // end of drawSingleShape
		// Draw once
		drawSingleShape.value;
		// draw repeats if needed
		if ((d.toolMode.asString.keep(5) == "paint"
			and: {d.paintMode == 'repeatsH' or: {d.paintMode == 'repeatsV'}}), {
			var darkenRatio = 1 - (d.repeatsDarken * 0.9);
			var dissolveRatio = 1 - (d.repeatsDissolve * 0.9);
			var count;
			if (d.paintMode == 'repeatsH', {
				count = d.repeatsCountH - 1;
			}, {
				count = d.repeatsCountV - 1;
			});
			count.do({arg i;
				var indentX, indentY, levelScale, alphaScale, color1, color2;
				var n = i + 1;
				if (d.paintMode == 'repeatsH', {
					indentX = n * d.repeatsSpacingH;
					indentY = 0;
				}, {
					indentX = 0;
					indentY = n * d.repeatsSpacingV.neg;
				});
				// check whether to draw
				if (indentX < d.imageWidth and: {indentY < d.imageHeight}, {
					levelScale = darkenRatio ** n;
					alphaScale = dissolveRatio ** n;
					color1 = (d.drawColor1.blend(Color.black, 1 - levelScale)
						.alpha_(alphaScale * d.drawColor1.alpha));
					color2 = (d.drawColor2.blend(Color.black, 1 - levelScale)
						.alpha_(alphaScale * d.drawColor2.alpha));
					drawSingleShape.value(color1, color2, indentX, indentY);
				});
			});
		});
	};
	// end of d.fDrawShape{}

	d.fDrawShapeInImage = {
		d.arrImages[d.imageIndex].draw({arg image;
			d.fDrawShape;
		});
	};

	d.fBaseColorize = {arg event, posX, posY, colorImage;
		var drawRect, copyImage, sourcePixels, colorPixels, newPixels;
		// copy rect from main image
		drawRect = Rect(posX, posY, colorImage.width, colorImage.height);
		copyImage = Image.new(drawRect.width.asInteger, drawRect.height.asInteger);
		copyImage.draw({arg image;
			Pen.drawImage(drawRect.left.neg @ drawRect.top.neg, d.arrImages[d.imageIndex],
				operation: 'sourceOver', opacity:1);
		});
		sourcePixels = copyImage.pixels;
		colorPixels = colorImage.pixels;
		newPixels = sourcePixels.collect({arg pixel, i;
			var level =  Image.pixelToColor(pixel).asArray.keep(3).maxItem;
			var tintCol = Image.pixelToColor(colorPixels[i]);
			var newCol = Color(tintCol.red * level, tintCol.green * level, tintCol.blue * level, 1);
			Image.colorToPixel(newCol);
		});
		newPixels = newPixels.as(Int32Array);
		colorImage.pixels = newPixels;
		d.arrImages[d.imageIndex].draw({arg image;
			Pen.use {
				Pen.smoothing_(false);
				colorImage.drawInRect(drawRect);
			};
		});
		copyImage.free;
		colorImage.free;
	};

	d.fApplyDragColorize = {
		var sourceRect, colorImage;
		sourceRect = Rect.fromPoints(d.drawPoints.mouseDownPoint, d.drawPoints.mouseCurrentPoint);
		sourceRect = sourceRect & Rect(0, 0, d.imageWidth, d.imageHeight); // keep within bounds
		// image to get colours from
		colorImage = Image.new(sourceRect.width.asInteger, sourceRect.height.asInteger);
		colorImage.draw({arg image;
			var drawRect = Rect(0, 0, sourceRect.width.asInteger, sourceRect.height.asInteger);
			Pen.addRect(drawRect);
			case {d.colorizeMode == 'colorizeFlat'} {
				Pen.color = d.colorizeColor1;
				Pen.fill;
			}
			{d.colorizeMode == 'colorizeCircularFade'} {
				var rad = dist(drawRect.leftTop, drawRect.center).max(2) * 0.7;
				Pen.fillRadialGradient(drawRect.center, drawRect.center, 0, rad,
					d.colorizeColor1, d.colorizeColor2);
			}
			{d.colorizeMode == 'colorizeHorizontalFade'} {
				Pen.fillAxialGradient(drawRect.leftTop, drawRect.rightTop,
					d.colorizeColor1, d.colorizeColor2);
			}
			{d.colorizeMode == 'colorizeVerticalFade'} {
				Pen.fillAxialGradient(drawRect.leftTop, drawRect.leftBottom,
					d.colorizeColor2, d.colorizeColor1);
			}
			{d.colorizeMode == 'colorizeSlopeUpFade'} {
				Pen.fillAxialGradient(drawRect.leftBottom, drawRect.rightTop,
					d.colorizeColor1, d.colorizeColor2);
			}
			{d.colorizeMode == 'colorizeSlopeDownFade'} {
				Pen.fillAxialGradient(drawRect.leftTop, drawRect.rightBottom,
					d.colorizeColor1, d.colorizeColor2);
			};
		});
		d.fBaseColorize(sourceRect.left, sourceRect.top, colorImage);
		colorImage.free;
	};
	d.fApplyPasteColorize = {
		var colorImage;
		colorImage = Image.new(d.selectionBox.width.asInteger, d.selectionBox.height.asInteger);
		colorImage.draw({arg image;
			d.copyImage.drawInRect(Rect(0, 0, d.selectionBox.width, d.selectionBox.height));
		});
		d.fBaseColorize(d.selectionBox.left, d.selectionBox.top, colorImage);
		colorImage.free;
	};

	d.fApplyBoxBlur = {
		var copyRect, copyImage;
		copyRect = Rect.fromPoints(d.drawPoints.mouseDownPoint, d.drawPoints.mouseCurrentPoint);
		copyRect = copyRect & Rect(0, 0, d.imageWidth, d.imageHeight); // keep within bounds
		copyImage = Image.new(copyRect.width.asInteger, copyRect.height.asInteger);
		copyImage.draw({arg image;
			Pen.drawImage(copyRect.left.neg @ copyRect.top.neg, d.arrImages[d.imageIndex],
				operation: 'sourceOver', opacity:1);
		});
		d.arrImages[d.imageIndex].draw({arg image;
			var offsetPoint = copyRect.left @ copyRect.top;
			d.blurSteps.do({arg i;
				var step = i + 1;
				var opacity = step.reciprocal * d.blurDepth;
				var drawPoints;
				case
				{d.blurMode == 'left'} {drawPoints = [step.neg @ 0]}
				{d.blurMode == 'right'} {drawPoints = [step @ 0]}
				{d.blurMode == 'left_right'} {drawPoints = [step @ 0, step.neg @ 0]}
				{d.blurMode == 'up'} {drawPoints = [0 @ step.neg]}
				{d.blurMode == 'down'} {drawPoints = [0 @ step]}
				{d.blurMode == 'up_down'} {drawPoints = [0 @ step, 0 @ step.neg]};
				drawPoints.do({arg point;
					Pen.drawImage(offsetPoint + point, copyImage,
						operation: d.blurCompositing, opacity: opacity);
				});
			});
		});
		copyImage.free;
	};

	d.fApplyWholeImageBlur = {
		var copyImage = d.arrImages[d.imageIndex].copy;
		d.arrImages[d.imageIndex].draw({arg image;
			d.blurSteps.do({arg i;
				var step = i + 1;
				var opacity = step.reciprocal * d.blurDepth;
				var drawPoints;
				case
				{d.blurMode == 'left'} {drawPoints = [step.neg @ 0]}
				{d.blurMode == 'right'} {drawPoints = [step @ 0]}
				{d.blurMode == 'left_right'} {drawPoints = [step @ 0, step.neg @ 0]}
				{d.blurMode == 'up'} {drawPoints = [0 @ step.neg]}
				{d.blurMode == 'down'} {drawPoints = [0 @ step]}
				{d.blurMode == 'up_down'} {drawPoints = [0 @ step, 0 @ step.neg]};
				drawPoints.do({arg point;
					Pen.drawImage(point, copyImage,
						operation: d.blurCompositing, opacity: opacity);
				});
			});
		});
		copyImage.free;
	};

	d.fApplyCompression = {
		var copyImage, sourcePixels, colorPixels, newPixels, colorImage;
		if (d.selectionBox.notNil, {
			colorImage = Image.new(d.selectionBox.width.asInteger, d.selectionBox.height.asInteger);
			// copy rect from main image
			copyImage = Image.new(d.selectionBox.width.asInteger, d.selectionBox.height.asInteger);
			copyImage.draw({arg image;
				Pen.drawImage(d.selectionBox.left.neg @ d.selectionBox.top.neg, d.arrImages[d.imageIndex],
					operation: 'sourceOver', opacity:1);
			});
			sourcePixels = copyImage.pixels;
			colorPixels = colorImage.pixels;
			newPixels = sourcePixels.collect({arg pixel, i;
				var col =  Image.pixelToColor(pixel);
				var rgbArray =  col.asArray.keep(3);
				var level =  rgbArray.maxItem;
				var outLevel = level;
				var newCol;
				if (d.useGate and: {outLevel < d.gateThreshold}, {
					outLevel = 0;
				});
				if (d.useCompression , {
					outLevel = outLevel.lincurve(0, 1, 0, 1, d.compressionCurve.neg);
				});
				if (d.useLimiter, {
					if (level > d.limitCeiling, {
						outLevel = d.limitCeiling;
					});
					if (d.autoGainCompensation, {
						outLevel = outLevel * d.limitCeiling.reciprocal;
					});
				});
				newCol = Color.hsv(*col.asHSV.keep(2).add(outLevel));
				Image.colorToPixel(newCol);
			});
			newPixels = newPixels.as(Int32Array);
			colorImage.pixels = newPixels;
			d.arrImages[d.imageIndex].draw({arg image;
				Pen.use {
					Pen.smoothing_(false);
					colorImage.drawInRect(d.selectionBox);
				};
			});
			copyImage.free;
			colorImage.free;
		});
	};

	d.fApplyScaleFilter = {
		var degrees = d.allScales[d.filterScale].degrees;
		if (d.selectionBox.notNil, {
			d.arrImages[d.imageIndex].draw({arg image;
				Pen.use {
					Pen.smoothing_(false);
					Pen.color = Color.black;
					d.selectionBox.height.do({arg i;
						var posY, scaleInd, offset, chosen;
						posY = i + d.selectionBox.top;
						offset = (d.imageHeight - 1 - posY) div: (d.detunedCopies + 1);
						scaleInd = (offset + d.midiNoteLowest + d.filterScaleRoot) % 12;
						if (d.filterScaleInvert, {
							chosen = degrees.indexOf(scaleInd).notNil;
						}, {
							chosen = degrees.indexOf(scaleInd).isNil;
						});
						if (chosen, {
							Pen.moveTo(d.selectionBox.left @ posY);
							Pen.lineTo((d.selectionBox.left + d.selectionBox.width) @ posY);
							Pen.stroke;
						});
					});
				};
			});
		});
	};

	d.fAnalyseSoundFile = {
		{
			var okFunc = {arg path;
				// var tempDict, newData;
				var soundFile;
				var isValid = false;
				var analysisData = [];
				var fileTime, soundBuf, cond, oscFunc, numFreqs, arrPixels, numTimePix, tempImage;
				// init
				d.fStopSound;
				d.fStopAnalysis;
				d.analysisStopped = false;
				d.fUpdateAnalysisInfo("Opening Sound File: " ++ path);
				soundFile = SoundFile.openRead(path);
				if (soundFile.notNil, {
					// check validity
					if (soundFile.numChannels == 1 or: {soundFile.numChannels == 2}, {
						isValid = true;
					},{
						d.fUpdateAnalysisInfo("Error: Unable to open. Sound file must be mono or stereo.");
						isValid = false;
					});
					if (isValid, {
						fileTime = soundFile.numFrames / soundFile.sampleRate;
						if (fileTime < 120, {
							isValid = true;
						},{
							d.fUpdateAnalysisInfo("Error: Unable to open. Sound file must be shorter than 120 secs.");
							isValid = false;
						});
					});
					if (isValid, {
						fork {
							d.fUpdateAnalysisInfo("Starting Analysis...");
							numFreqs = d.arrFreqs.size;
							cond = Condition.new;
							soundBuf = Buffer.read(s, path, action: {cond.unhang});
							cond.hang;
							// osc func
							oscFunc = OSCFunc({ |msg|
								var arrAmps = msg.keep(numFreqs.neg);
								arrAmps = arrAmps.reverse.clip(0, 1);  // clip data
								analysisData = analysisData.add(arrAmps);
							}, '/analysis');
							// load/play synth
							d.analysisSynth = SynthDef(\analysis, { arg out = 0, soundBuf, amp;
								var source = PlayBuf.ar(soundFile.numChannels, soundBuf, BufRateScale.kr(soundBuf),
									doneAction: 2);
								var arrAmps = Amplitude.kr(Resonz.ar(Mix.new(source), d.arrFreqs, bwr: d.arrBWRs),
									attackTime: 0.01, releaseTime: 0.01);
								var trigRate = (d.imageWidth / fileTime).min(100);
								var sendtrig = Impulse.kr(trigRate);
								// send amplitude values
								SendReply.kr(sendtrig, '/analysis', arrAmps);
								// monitor analysis
								Out.ar( out, source * amp * 0.2);
							}).play(s,[\soundBuf, soundBuf, \amp, d.volume]);
							s.sync;
							(fileTime + 1).wait; // wait for sound to finish
							// free osc listener
							oscFunc.free;
							if (d.analysisStopped.not, {
								d.fUpdateAnalysisInfo("Preparing data...");
								// adjust array size
								analysisData = analysisData.keep(d.imageWidth);
								numTimePix = analysisData.size;
								/* //   not needed
								if (analysisData.size < d.imageWidth, {  // add zeros to fill
								zeroSpectrum = 0 ! d.arrFreqs.size;
								(d.imageWidth - analysisData.size).do({
								analysisData = analysisData.add(zeroSpectrum);
								});
								});
								*/
								// prepare analysisData
								analysisData = analysisData.flop.flat;
								analysisData = analysisData.normalize;
								// compress / limit
								if (d.analysisCompLimit, {
									analysisData = analysisData.lincurve(0, d.analysisLimitCeiling, 0, 1,
										d.analysisCompressionCurve.neg);
								});
								{  // defer Image and gui to run on AppClock
									arrPixels = analysisData.collect({arg  val;
										Image.colorToPixel(Color(val * d.analysisColor.red,
											val * d.analysisColor.green,
											val * d.analysisColor.blue);
										);
									});
									arrPixels = arrPixels.as(Int32Array);
									tempImage = Image.color(numTimePix, numFreqs, Color.black);
									tempImage.pixels = arrPixels;
									if (d.analysisStopped.not, {
										d.arrImages[d.imageIndex].draw({arg image;
											Pen.use {
												Pen.smoothing_(false);
												Pen.drawImage( Rect(0, 0, d.imageWidth, d.imageHeight), tempImage,
													operation: 'sourceOver', opacity: 1);
											};
										});
									});
									// free resources
									tempImage.free;
									soundBuf.free;
									d.analysisSynth = nil;
									if (d.analysisStopped.not, {
										d.fUpdateAnalysisInfo("Finished Analysis.");
										if (d.analysisSetsPlayLength, {
											d.playLength = fileTime;
											d.fUpdateBPM
										});
										d.rebuildWindow;
									});
								}.defer;
							});
						};
					},{
						d.fUpdateAnalysisInfo("Error: Unable to open - not a valid Sound File.");
					});
				});
			};
			Dialog.openPanel(okFunc, multipleSelection: false);
		}.defer;
	};  // end of d.fAnalyseSoundFile
	d.fStopAnalysis = {
		d.analysisStopped = true;
		if (d.analysisSynth.notNil, {
			d.analysisSynth.free;
			d.analysisSynth = nil;
			d.fUpdateAnalysisInfo("Analysis stopped by user.");
		});
	};
	d.fUpdateAnalysisInfo = {arg event, string;
		{string.postln;}.defer;
	};

	d.fApplyPerlin = { arg event, mode = 'draw';   // 'draw' or 'colorize'
		// Skewing and unskewing factors
		var kF2 = 0.36602540378444; // 0.5*(sqrt(3.0)-1.0);
		var kG2 = 0.21132486540519; // (3.0-sqrt(3.0))/6.0;
		// var kF3 = 0.33333333333333; // 1.0/3.0;
		// var kG3 = 0.16666666666667; // 1.0/6.0;
		// var kF4 = 0.30901699437495; // (sqrt(5.0)-1.0)/4.0;
		// var kG4 = 0.13819660112501; // (5.0-sqrt(5.0))/20.0;
		var p = [
			151,160,137,91,90,15,
			131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
			190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
			88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
			77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
			102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
			135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
			5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
			223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
			129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
			251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
			49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
			138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
		];
		var grad3 = [
			[1,1,0], [-1,1,0], [1,-1,0], [-1,-1,0], [1,0,1], [-1,0,1],
			[1,0,-1], [-1,0,-1], [0,1,1], [0,-1,1], [0,1,-1], [0,-1,-1],
		];
		var perm = 0 ! 512;
		var permMod12 = 0 ! 512;
		var perlinImage, perlinImageWidth, perlinImageHeight, arrPixels, colorImage;
		var prfBm, fBm2, dot2, noise2, makeWindow;   // functions
		if (d.selectionBox.notNil, {
			perlinImageWidth = (d.selectionBox.width div: 4).max(1);
			perlinImageHeight = (d.selectionBox.height div: 4).max(1);
			perlinImage = Image.new(perlinImageWidth, perlinImageHeight);
			// To remove the need for index wrapping, double the permutation table length
			512.do{ arg i;
				perm[i] = p[i & 255];
				permMod12[i] = (perm[i] % 12);
			};
			prfBm = { arg vec, oct = 3, method;
				var sum = 0;
				var weight = 1.0;
				oct.do {
					sum = sum + (noise2.(vec[0], vec[1],) * weight);
					vec = vec * 2;
					weight = weight / 2;
				};
				sum;
			};
			fBm2 = { arg xin, yin, oct = 3;
				prfBm.([xin, yin], oct);
			};
			dot2 = {arg arr1, arr2;
				(arr1[0] * arr2[0]) + (arr1[1] * arr2[1]);
			};
			noise2 = { arg xin, yin;
				var n0, n1, n2; // Noise contributions from the three corners
				// Skew the input space to determine which simplex cell we're in
				var s = (xin+yin)*kF2; // Hairy factor for 2D
				var i = floor(xin+s).asInteger;
				var j = floor(yin+s).asInteger;
				var t = (i+j)*kG2;
				var uX0 = i-t; // Unskew the cell origin back to (x,y) space
				var uY0 = j-t;
				var x0 = xin-uX0; // The x,y distances from the cell origin
				var y0 = yin-uY0;
				// For the 2D case, the simplex shape is an equilateral triangle.
				// Determine which simplex we are in.
				var i1, j1; // Offsets for second (middle) corner of simplex in (i,j) coords
				var x1, y1, x2, y2;
				var ii, jj, gi0, gi1, gi2;
				var t0, t1, t2;
				if (x0>y0) {
					// lower triangle, XY order: (0,0)->(1,0)->(1,1)
					i1=1; j1=0;
				} {
					// upper triangle, YX order: (0,0)->(0,1)->(1,1)
					i1=0; j1=1;
				};
				// A step of (1,0) in (i,j) means a step of (1-c,-c) in (x,y), and
				// a step of (0,1) in (i,j) means a step of (-c,1-c) in (x,y), where
				// c = (3-sqrt(3))/6
				x1 = x0 - i1 + kG2; // Offsets for middle corner in (x,y) unskewed coords
				y1 = y0 - j1 + kG2;
				x2 = x0 - 1.0 + (2.0 * kG2); // Offsets for last corner in (x,y) unskewed coords
				y2 = y0 - 1.0 + (2.0 * kG2);
				// Work out the hashed gradient indices of the three simplex corners
				ii = i & 255;
				jj = j & 255;
				gi0 = permMod12[ii+perm[jj]];
				gi1 = permMod12[ii+i1+perm[jj+j1]];
				gi2 = permMod12[ii+1+perm[jj+1]];
				// Calculate the contribution from the three corners
				t0 = 0.5 - (x0*x0)-(y0*y0);
				if (t0<0) {
					n0 = 0.0;
				} {
					t0 = t0 * t0;
					n0 = t0 * t0 * dot2.(grad3[gi0], [x0, y0]);  // (x,y) of grad3 used for 2D gradient
				};
				t1 = 0.5 - (x1*x1)-(y1*y1);
				if (t1<0) {
					n1 = 0.0;
				} {
					t1 = t1 * t1;
					n1 = t1 * t1 * dot2.(grad3[gi1], [x1, y1]);
				};
				t2 = 0.5 - (x2*x2)-(y2*y2);
				if (t2<0) {
					n2 = 0.0;
				} {
					t2 = t2 * t2;
					n2 = t2 * t2 * dot2.(grad3[gi2], [x2, y2]);
				};
				// Add contributions from each corner to get the final noise value.
				// The result is scaled to return values in the interval [-1,1].
				70.0 * (n0 + n1 + n2);
			};
			arrPixels = perlinImageHeight.collect({arg y;
				var perlinColorArray  = d.perlinColor.asArray;
				perlinImageWidth.collect({arg x;
					//   convert noise to color and then to pixel
					var noise, level, color, colArray;
					if (d.perlinTripleNoise, {
						// multicolor noise
						colArray = [0, 3572, 8317].collect({arg colOffset, i;
							noise = fBm2.(
								x / d.imageWidth * d.perlinScaleX * 3 + d.perlinRandSeed + colOffset,
								y / d.imageHeight * d.perlinScaleY * 3 + d.perlinRandSeed + colOffset,
								d.perlinOctaves
							);
							level = (noise.linlin(-1, 1, 0, 1) + d.perlinOffset).clip(0.0, 1.0)
							* perlinColorArray[i];
							level = level.round(d.perlinQuantize);
						});
						color = Color(*colArray);
					}, {
						// single color noise
						noise = fBm2.(
							x / d.imageWidth * d.perlinScaleX * 3 + d.perlinRandSeed,
							y / d.imageHeight * d.perlinScaleY * 3 + d.perlinRandSeed,
							d.perlinOctaves
						);
						level = (noise.linlin(-1, 1, 0, 1) + d.perlinOffset).clip(0.0, 1.0);
						level = level.round(d.perlinQuantize);
						color = Color(d.perlinColor.red * level, d.perlinColor.green * level,
							d.perlinColor.blue * level);
					});
					Image.colorToPixel(color);  // convert
				});
			});
			arrPixels = arrPixels.flat;
			arrPixels = arrPixels.as(Int32Array);
			perlinImage.pixels = arrPixels;
			case {mode == 'draw'} {
				d.arrImages[d.imageIndex].draw({arg image;
					Pen.use {
						Pen.smoothing_(false);
						Pen.drawImage(d.selectionBox, perlinImage);
					};
				});
			}
			{mode == 'colorize'} {
				colorImage = Image.new(d.selectionBox.width.asInteger, d.selectionBox.height.asInteger);
				colorImage.draw({arg image;
					Pen.use {
						Pen.smoothing_(false);
						perlinImage.drawInRect(Rect(0, 0, d.selectionBox.width, d.selectionBox.height));
					};
				});
				d.fBaseColorize(d.selectionBox.left, d.selectionBox.top, colorImage);
				colorImage.free;
			};
			perlinImage.free;
		});
	};
	// end of d.fApplyPerlin

	// selection box funcs
	d.fClipCurrentPoint = {
		d.drawPoints.mouseCurrentPoint.x = d.drawPoints.mouseCurrentPoint.x.clip(0, d.imageWidth);
		d.drawPoints.mouseCurrentPoint.y = d.drawPoints.mouseCurrentPoint.y.clip(0, d.imageHeight);
	};
	d.fClipSelectionBox = {
		var clipBox = Rect(0, 0, d.imageWidth, d.imageHeight);
		if (d.selectionBox.notNil, {
			d.selectionBox = d.selectionBox & clipBox;
		});
	};
	d.fValidateSelectionBox = {
		d.fClipSelectionBox;
		if (d.selectionBox.notNil, {
			if (d.selectionBox.width == 0 or: {d.selectionBox.height == 0}, {
				d.selectionBox = nil;
			});
		});
	};
	d.fMakeSelectionBox = {
		var posX, posY;
		d.selectionBox = nil;
		case
		{d.toolMode == 'paintLines'} {
			if (d.snapToTimeGrid, {
				posX = d.drawPoints.mouseCurrentPoint.x + (d.toolWidth div: 2); // left align
			}, {
				posX = d.drawPoints.mouseCurrentPoint.x;  // centre align
			});
			posY = d.drawPoints.mouseCurrentPoint.y;  // centre align
			// d.selectionBox = Rect(0, 0, d.toolWidth, 1).center_(d.drawPoints.mouseCurrentPoint);
			d.selectionBox = Rect(0, 0, d.toolWidth, 1).center_(Point(posX, posY));
		}
		{d.toolMode == 'paintSpray'} {
			d.selectionBox = Rect(0, 0, d.toolWidth, d.toolHeight).center_(d.drawPoints.mouseCurrentPoint);
		}
		{d.toolMode.asString.keep(5) == "paint"} {
			if (d.snapToTimeGrid, {
				posX = d.drawPoints.mouseCurrentPoint.x + (d.toolWidth div: 2); // left align
			}, {
				posX = d.drawPoints.mouseCurrentPoint.x;  // centre align
			});
			posY = d.drawPoints.mouseCurrentPoint.y;  // centre align
			// d.selectionBox = Rect(0, 0, d.toolWidth, d.toolHeight).center_(d.drawPoints.mouseCurrentPoint);
			d.selectionBox = Rect(0, 0, d.toolWidth, d.toolHeight).center_(Point(posX, posY));
		}
		{d.toolMode.asString.contains("HorizBar")} {
			d.selectionBox = Rect.fromPoints(
				0 @ d.drawPoints.mouseDownPoint.y,
				d.imageWidth @ d.drawPoints.mouseCurrentPoint.y
			);
		}
		{d.toolMode.asString.contains("VertBar")} {
			d.selectionBox = Rect.fromPoints(
				d.drawPoints.mouseDownPoint.x @ 0,
				d.drawPoints.mouseCurrentPoint.x @ d.imageHeight
			);
		};
		if (d.selectionBox.isNil,  {
			d.selectionBox = Rect.fromPoints(d.drawPoints.mouseDownPoint, d.drawPoints.mouseCurrentPoint);
		});
		d.fClipSelectionBox;
	};
	d.fUpdateSelectionInfo = {
		if (d.selectionBox.notNil and: d.guiData.selectionWidthView.notNil, {
			d.guiData.selectionWidthView.value_(d.selectionBox.width);
			d.guiData.selectionHeightView.value_(d.selectionBox.height);
			d.guiData.selectionLeftView.value_(d.selectionBox.left);
			d.guiData.selectionTopView.value_(d.selectionBox.top);
			d.guiData.selectionBarLeft.refresh;
			d.guiData.selectionBarBottom.refresh;
		});
	};
	d.fMoveSelectionBox = {arg event, xShift = 0, yShift = 0;
		var newBox;
		if (d.selectionBox.notNil, {
			newBox = d.selectionBox.copy;
			newBox.left = (newBox.left + xShift).max(0).min(d.arrImages[d.imageIndex].width - 1);
			newBox.top = (newBox.top + yShift).max(0).min(d.arrImages[d.imageIndex].height - 1);
			if (Rect(0, 0, d.imageWidth, d.imageHeight).contains(newBox), {
				d.selectionBox = newBox;
				d.fUpdateSelectionInfo;
				d.guiData.sonogramEditView.refresh;
			});
		});
	};
	d.fCopySelection = {
		if (d.selectionBox.notNil, {
			d.copyImage = Image.color(d.selectionBox.width.asInteger, d.selectionBox.height.asInteger, Color.black);
			d.copyImage.draw({arg image;
				Pen.use {
					Pen.smoothing_(false);
					Pen.drawImage(d.selectionBox.left.neg @ d.selectionBox.top.neg, d.arrImages[d.imageIndex],
						operation: 'sourceOver', opacity:1);
				};
			});
		});
	};
	d.fCutSelection = {
		var blackImage;
		if (d.selectionBox.notNil, {
			blackImage = Image.color(d.selectionBox.width.asInteger, d.selectionBox.height.asInteger, Color.black);
			d.fCopySelection; // copy before cut
			d.arrImages[d.imageIndex].draw({arg image;
				Pen.use {
					Pen.smoothing_(false);
					Pen.drawImage(d.selectionBox.left @ d.selectionBox.top, blackImage);
				};
			});
			blackImage.free;
		});
	};
	d.fInvertSelection = {
		var pixels, tempImage;
		if (d.selectionBox.notNil, {
			tempImage = Image(d.selectionBox.width.asInteger, d.selectionBox.height.asInteger);
			tempImage.draw({arg image;
				Pen.use {
					Pen.smoothing_(false);
					Pen.drawImage(d.selectionBox.left.neg @ d.selectionBox.top.neg, d.arrImages[d.imageIndex],
						operation: 'sourceOver', opacity:1);
				};
			});
			pixels = tempImage.pixels;
			pixels = pixels.reshape(d.selectionBox.height, d.selectionBox.width);
			pixels = pixels.reverse;
			pixels = pixels.flat.as(Int32Array);
			tempImage.pixels = pixels;
			d.arrImages[d.imageIndex].draw({arg image;
				Pen.use {
					Pen.smoothing_(false);
					Pen.drawImage(d.selectionBox.left @ d.selectionBox.top, tempImage);
				};
			});
			tempImage.free;
		});
	};
	d.fReverseSelection = {
		var pixels, tempImage;
		if (d.selectionBox.notNil, {
			tempImage = Image(d.selectionBox.width.asInteger, d.selectionBox.height.asInteger);
			tempImage.draw({arg image;
				Pen.use {
					Pen.smoothing_(false);
					Pen.drawImage(d.selectionBox.left.neg @ d.selectionBox.top.neg, d.arrImages[d.imageIndex],
						operation: 'sourceOver', opacity:1);
				};
			});
			pixels = tempImage.pixels;
			pixels = pixels.reshape(d.selectionBox.height, d.selectionBox.width);
			pixels = pixels.collect({arg item; item.reverse});
			pixels = pixels.flat.as(Int32Array);
			tempImage.pixels = pixels;
			d.arrImages[d.imageIndex].draw({arg image;
				Pen.use {
					Pen.smoothing_(false);
					Pen.drawImage(d.selectionBox.left @ d.selectionBox.top, tempImage);
				};
			});
			tempImage.free;
		});
	};
	d.fPasteSelection = {
		var tempImage, dissolveRatio, pasteSingleImage;
		if (d.selectionBox.notNil and: d.copyImage.notNil, {
			pasteSingleImage = {arg opacityScale = 1, indentX = 0, indentY = 0;
				var opacity = d.pasteOpacity * opacityScale;
				var drawRect;
				case
				{d.pasteMode == 'stretchToFit'} {
					d.arrImages[d.imageIndex].draw({arg image;
						Pen.use {
							Pen.smoothing_(false);
							drawRect = Rect(d.selectionBox.left + indentX,
								d.selectionBox.top + indentY,
								d.selectionBox.width, d.selectionBox.height
							);
							d.copyImage.drawInRect(drawRect, operation: d.pasteCompositing, fraction: opacity);
						};
					});
				}
				{d.pasteMode == 'colorizeStretchToFit'} {
					d.fApplyPasteColorize;
				}
				{d.pasteMode == 'scaleToFit'} {
					var scaleX = d.selectionBox.width / d.copyImage.width;
					var scaleY = d.selectionBox.height / d.copyImage.height;
					var scaleXY = min(scaleX, scaleY);
					var scaledImageWidth = d.copyImage.width * scaleXY;
					var scaledImageHeight = d.copyImage.height * scaleXY;
					var borderX = (d.selectionBox.width - scaledImageWidth) * 0.5;
					var borderY = (d.selectionBox.height - scaledImageHeight) * 0.5;
					drawRect = Rect(d.selectionBox.left + borderX + indentX,
						d.selectionBox.top + borderY + indentY, scaledImageWidth, scaledImageHeight);
					d.arrImages[d.imageIndex].draw({arg image;
						Pen.use {
							Pen.smoothing_(false);
							d.copyImage.drawInRect(drawRect, operation: d.pasteCompositing, fraction: opacity);
						};
					});
				}
				{d.pasteMode == 'scaleToFill'} {
					var targetWidth, targetHeight, borderX, borderY, fromRect;
					var ratioOrig = d.copyImage.width / d.copyImage.height;
					var ratioTarget = d.selectionBox.width / d.selectionBox.height;
					if (ratioOrig > ratioTarget, {
						targetWidth = d.copyImage.height * ratioTarget;
						targetHeight = d.copyImage.height;
						borderX =  (d.copyImage.width - targetWidth ) * 0.5;
						borderY = 0;
					}, {
						targetWidth = d.copyImage.width;
						targetHeight = d.copyImage.width / ratioTarget;
						borderX = 0;
						borderY = (d.copyImage.height - targetHeight ) * 0.5;
					});
					fromRect = Rect(borderX, borderY, targetWidth, targetHeight);
					drawRect = Rect(d.selectionBox.left + indentX,
						d.selectionBox.top + indentY,
						d.selectionBox.width, d.selectionBox.height
					);
					d.arrImages[d.imageIndex].draw({arg image;
						Pen.use {
							Pen.smoothing_(false);
							d.copyImage.drawInRect(drawRect, fromRect,
								operation: d.pasteCompositing, fraction: opacity);
						};
					});
				}
				{d.pasteMode == 'tileToFill'} {
					drawRect = Rect(d.selectionBox.left + indentX,
						d.selectionBox.top + indentY,
						d.selectionBox.width, d.selectionBox.height
					);
					d.arrImages[d.imageIndex].draw({arg image;
						Pen.use {
							Pen.smoothing_(false);
							d.copyImage.tileInRect(drawRect, operation: d.pasteCompositing, opacity: opacity);
						};
					});
				}
				{d.pasteMode == 'originalScale'} {
					tempImage = Image.color(d.selectionBox.width.asInteger, d.selectionBox.height.asInteger,
						Color.clear);
					tempImage.draw({arg image;
						Pen.use {
							Pen.smoothing_(false);
							Pen.drawImage(0 @ 0, d.copyImage, operation: d.pasteCompositing, opacity: opacity);
						};
					});
					drawRect = Rect(d.selectionBox.left + indentX,
						d.selectionBox.top + indentY,
						d.selectionBox.width, d.selectionBox.height
					);
					d.arrImages[d.imageIndex].draw({arg image;
						Pen.use {
							Pen.smoothing_(false);
							tempImage.drawInRect(drawRect, operation: d.pasteCompositing, fraction: opacity);
						};
					});
					tempImage.free;
				}
				;
			}; // end of pasteSingleImage
			// Draw once
			pasteSingleImage.value;
			// draw repeats if needed
			if (d.pasteRepeatMode == 'repeatsH' or: {d.pasteRepeatMode == 'repeatsV'}, {
				var count;
				if (d.paintMode == 'repeatsH', {
					count = d.repeatsCountH;
				}, {
					count = d.repeatsCountV;
				});
				dissolveRatio = 1 - (d.repeatsDissolve * 0.9);
				count.do({arg i;
					var spacing, indentX, indentY, opacity;
					var n = i + 1;
					if (d.pasteRepeatMode == 'repeatsH', {
						indentX = n * d.repeatsSpacingH;
						indentY = 0;
					}, {
						indentX = 0;
						indentY = n * d.repeatsSpacingV.neg;
					});
					// check whether to draw
					if (indentX < (d.imageWidth * 2) and: {indentY < (d.imageHeight * 2)}, {
						opacity = dissolveRatio ** n;
						pasteSingleImage.value(opacity, indentX, indentY);
					});
				});
			});
		});
	};  // end of d.fPasteSelection

	// curve history functions
	d.fInitCurveHistory = {arg event, dataKey;
		var historyKey = (dataKey.asString ++ "History").asSymbol;
		var historyIndexKey = (historyKey.asString ++ "Index").asSymbol;
		if (d[historyKey].isNil, {
			d[historyKey] = [];
			d[historyIndexKey] = 0;
		});
	};
	d.fAddToCurveHistory = {arg event, dataKey;
		var maxHistorySize = 30;
		var historyKey = (dataKey.asString ++ "History").asSymbol;
		var historyIndexKey = (historyKey.asString ++ "Index").asSymbol;
		// if data is different add to history
		if (d[historyKey][d[historyIndexKey]] != d[dataKey], {
			// truncate hist at current index
			d[historyKey] = d[historyKey].keep(d[historyIndexKey] + 1);
			d[historyKey] = d[historyKey].add(d[dataKey].deepCopy);
			d[historyKey] = d[historyKey].keep(0 - maxHistorySize);
			d[historyIndexKey] = d[historyKey].size - 1;
		});
	};
	d.fAddToAllCurveHistories = {
		d.fAddToCurveHistory('arrEQAmps');
		d.fAddToCurveHistory('envCurve');
		d.fAddToCurveHistory('warpCurve');
		d.fAddToCurveHistory('arrNormTimeStretches');
		d.fAddToCurveHistory('arrNormPitchShifts');
	};
	d.fInitAllCurveHistories = {
		d.fInitCurveHistory('arrEQAmps');
		d.fInitCurveHistory('envCurve');
		d.fInitCurveHistory('warpCurve');
		d.fInitCurveHistory('arrNormTimeStretches');
		d.fInitCurveHistory('arrNormPitchShifts');
		// store default settings as first history
		d.fAddToAllCurveHistories;
	};
	d.fLoadPrevCurveHistory = {arg event, dataKey, actionFunc = {};
		var historyKey = (dataKey.asString ++ "History").asSymbol;
		var historyIndexKey = (historyKey.asString ++ "Index").asSymbol;
		var size = d[dataKey].size;
		var tempArr;
		if (d[historyIndexKey] > 0, {
			d[historyIndexKey] = d[historyIndexKey] - 1;
			tempArr = d[historyKey][d[historyIndexKey]].resamp1(size);
			d[dataKey] = tempArr;
			actionFunc.value;
		});
	};
	d.fLoadNextCurveHistory = {arg event, dataKey, actionFunc = {};
		var historyKey = (dataKey.asString ++ "History").asSymbol;
		var historyIndexKey = (historyKey.asString ++ "Index").asSymbol;
		var size = d[dataKey].size;
		var tempArr;
		if (d[historyIndexKey] < (d[historyKey].size - 1), {
			d[historyIndexKey] = d[historyIndexKey] + 1;
			tempArr = d[historyKey][d[historyIndexKey]].resamp1(size);
			d[dataKey] = tempArr;
			actionFunc.value;
		});
	};

};  // end of d.fDefineFunctions2

d.fDefineFunctions2; // run function

// gui funcs ================

d.fDefineGUIFunctions = {

	d.fUpdateWindowName = {arg event, infoString;
		var name = "TX Image Synth App";
		infoString = infoString ? "";
		if (infoString.size > 0, {
			name = name ++ ":  " ++ infoString;
		});
		d.guiData.window.name = name;
	};

	d.fResetWindowSize = {
		var rect = d.guiData.window.bounds;
		rect.width = d.windowWidth;
		rect.height = d.windowHeight;
		{
			d.guiData.window.bounds = rect;
		}.defer(0.2);
	};

	d.fSetImageSynthVal = {arg event, key, val;
		if (d.imageSynth.notNil, {
			d.imageSynth.set(key.asString, val);
		});
	};
	d.fSetPlayPosition = {arg event, pos;
		d.playPosition = pos;
		{
			if (d.guiData.timelineView.notNil, {
				d.guiData.timelineView.refresh;
			});
		}.defer;
	};

	d.fEZWavetable = {arg event, name, key, tableIndex, width = 256, height = 180, actionFunc = {arg arrVals; };
		var waveformView, staticText, sliderView, popup;
		var colWidth = width / d.numHarmonics;
		waveformView = UserView()
		.fixedSize_(width @ height)
		.background_(Color.white)
		.drawFunc_({arg view;
			var arrVals = Signal.sineFill(width, d[key][tableIndex]).as(Array).normalize;
			Pen.color = Color(0.2, 0.2, 0.4);
			arrVals.do({arg val, i;
				Pen.line(Point(i, 0.5 * (height - 21) + 20), Point(i, val * (height - 49) + 24));
				Pen.stroke;
			});
			Pen.color = Color.black;
			d.numHarmonics.do({arg i;
				Pen.stringCenteredIn((i + 1).asString,
					Rect((colWidth * i), height - 46, colWidth, 24), color:Color.black);
				Pen.stroke;
			});
		});
		staticText = StaticText(waveformView, Rect(0, 0, width, 22))
		.background_(Color.white).stringColor_(d.colButton)
		.string_(name).align_(\center);
		sliderView = MultiSliderView(waveformView, Rect(0, 22, width, height - 44))
		.size_(16).indexThumbSize_(28).elasticMode_(1).isFilled_(true)
		.background_(Color(1, 1, 1, 0)).fillColor_(Color(0.8, 0.92, 1, 0.5))
		.value_(d[key][tableIndex])
		.action_({arg view;
			d[key][tableIndex] = view.value;
			waveformView.refresh;
		})
		.mouseUpAction_({arg view; actionFunc.value(view.value)});
		popup = PopUpMenu(waveformView, Rect(0, height - 23, width, 22))
		.items_(d.arrWavetableActions.flop.slice(0).collect({arg item; item }))
		.action_({arg view;
			if (view.value > 0, {
				d.fRunHarmonicAction(view.value, tableIndex);
			});
			d.rebuildWindow;
		});
		// return waveformView
		waveformView;
	};
	d.fEZSlider = {arg event, spec, key, nameString, sliderWidth = 160, nameWidth = 90,
		numberWidth = 50, actionFunc = {arg val; }, mouseUpFunc = {arg val; };
		var sliderView, numBox;
		// slider & numbox
		sliderView = Slider().thumbSize_(8).orientation_(\horizontal)
		.fixedSize_(sliderWidth @ 22)
		.background_(Color.white).knobColor_(d.colButton)
		.action_({arg view;
			d[key] = spec.map(view.value);
			numBox.value_(d[key]);
			actionFunc.value(d[key]);
		}).mouseUpAction_({arg view;
			d[key] = spec.map(view.value);
			numBox.value_(d[key]);
			mouseUpFunc.value(d[key]);
		})
		.value_(spec.unmap(d[key]));
		numBox = NumberBox().maxDecimals_(3)
		.fixedSize_(numberWidth @ 22)
		.action_({arg view;
			view.value = spec.constrain(view.value);
			d[key] = view.value;
			sliderView.value = spec.unmap(d[key]);
			actionFunc.value(d[key]);
			mouseUpFunc.value(d[key]);
		})
		.value_(d[key]);
		// return layout
		HLayout(
			// label
			[StaticText().string_(nameString).align_(\center)
				.fixedSize_(nameWidth @ 22)
				.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
			[sliderView, align: \top],
			[numBox, align: \top],
		).spacing_(2)
	};
	d.fEZRangeSlider = {arg event, spec, keyMin, keyMax, nameString, sliderWidth = 160, nameWidth = 90,
		numberWidth = 50, actionFunc = {arg minVal, maxVal; }, mouseUpFunc = {arg minVal, maxVal; };
		var sliderView, numBox, numBox2;
		// slider & numboxes
		sliderView = RangeSlider().orientation_(\horizontal)
		.fixedSize_(sliderWidth @ 22)
		.background_(Color.white).knobColor_(d.colButton)
		.action_({arg view;
			d[keyMin] = spec.map(view.lo);
			d[keyMax] = spec.map(view.hi);
			numBox.value_(d[keyMin]);
			numBox2.value_(d[keyMax]);
			actionFunc.value(d[keyMin], d[keyMax]);
		})
		.mouseUpAction_({arg view;
			d[keyMin] = spec.map(view.lo);
			d[keyMax] = spec.map(view.hi);
			numBox.value_(d[keyMin]);
			numBox2.value_(d[keyMax]);
			mouseUpFunc.value(d[keyMin], d[keyMax]);
		})
		.lo_(spec.unmap(d[keyMin]))
		.hi_(spec.unmap(d[keyMax]));
		numBox = NumberBox().maxDecimals_(3)
		.fixedSize_(numberWidth @ 22)
		.action_({arg view;
			view.value = spec.constrain(view.value);
			d[keyMin] = view.value;
			sliderView.lo = spec.unmap(d[keyMin]);
			actionFunc.value(d[keyMin], d[keyMax]);
			mouseUpFunc.value(d[keyMin], d[keyMax]);
		})
		.value_(d[keyMin]);
		numBox2 = NumberBox().maxDecimals_(3)
		.fixedSize_(numberWidth @ 22)
		.action_({arg view;
			view.value = spec.constrain(view.value);
			d[keyMax] = view.value;
			sliderView.hi = spec.unmap(d[keyMax]);
			actionFunc.value(d[keyMin], d[keyMax]);
			mouseUpFunc.value(d[keyMin], d[keyMax]);
		})
		.value_(d[keyMax]);
		// return layout
		HLayout(
			// label
			[StaticText().string_(nameString).align_(\center)
				.fixedSize_(nameWidth @ 22)
				.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
			[sliderView, align: \top],
			[numBox, align: \top],
			[numBox2, align: \top],
		).spacing_(2)
	};
	d.fEZNumBox = {arg event, spec, key, nameString, nameWidth = 90, numberWidth = 40,
		actionFunc = {arg val; };
		var numBox;
		// numbox
		numBox = NumberBox().maxDecimals_(3)
		.fixedSize_(numberWidth @ 22)
		.action_({arg view;
			view.value = spec.constrain(view.value);
			d[key] = view.value;
			actionFunc.value(d[key]);
		})
		.value_(d[key]);
		// return layout
		HLayout(
			// label
			[StaticText().string_(nameString).align_(\center)
				.fixedSize_(nameWidth @ 22)
				.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
			[numBox, align: \top],
		).spacing_(2)
	};

	d.fEZColor = {arg event, colkey, nameString, sliderWidth = 100, nameWidth = 60,
		numberWidth = 34, showAlpha = true;
		var colorSampleView, colorPresetsPopup, red_slider, red_numBox, green_slider, green_numBox;
		var blue_slider, blue_numBox, alpha_slider, alpha_numBox, colorPresets, guiLayout;
		var numSpec = ControlSpec(0, 1);
		var colors = ();  // local colors
		colors.redTint = Color.red.blend(Color.white, 0.8);
		colors.blueTint = Color(0.8, 0.85, 1);
		colors.greenTint = Color.green.blend(Color.white, 0.8);
		if (showAlpha, {
			colorPresets = d.colorPresets;
		}, {
			colorPresets = d.colorPresetsNoAlpha;
		});
		// color sample
		colorSampleView = UserView()
		.fixedSize_(26 @ 26)
		.background_(d[colkey].copy.alpha_(1).blend(Color.black, (1 - d[colkey].alpha)));
		// presets
		colorPresetsPopup = PopUpMenu()
		.fixedSize_(70 @ 22)
		.items_(colorPresets.flop.slice(0))
		.stringColor_(Color.black).background_(d.colLabel)
		.value_(0)
		.action_({arg view;
			if (view.value > 0, {
				d[colkey] = colorPresets.flop.slice(1)[view.value].copy;
			});
			d.rebuildWindow;
		});
		// red
		red_slider = Slider().thumbSize_(8).orientation_(\horizontal)
		.fixedSize_(sliderWidth @ 22)
		.background_(Color.white).knobColor_(d.colButton)
		.action_({arg view;
			view.value = numSpec.constrain(view.value);
			d[colkey].red = view.value;
			red_numBox.value_(d[colkey].red);
			colorSampleView.background_(d[colkey].copy.alpha_(1).blend(Color.black, (1 - d[colkey].alpha)));
		})
		.value_(d[colkey].red);
		red_numBox = NumberBox().maxDecimals_(2)
		.fixedSize_(numberWidth @ 22)
		.action_({arg view;
			view.value = numSpec.constrain(view.value);
			d[colkey].red = view.value;
			red_slider.value = d[colkey].red;
			colorSampleView.background_(d[colkey].copy.alpha_(1).blend(Color.black, (1 - d[colkey].alpha)));
		})
		.value_(d[colkey].red);
		// green
		green_slider = Slider().thumbSize_(8).orientation_(\horizontal)
		.fixedSize_(sliderWidth @ 22)
		.background_(Color.white).knobColor_(d.colButton)
		.action_({arg view;
			view.value = numSpec.constrain(view.value);
			d[colkey].green = view.value;
			green_numBox.value_(d[colkey].green);
			colorSampleView.background_(d[colkey].copy.alpha_(1).blend(Color.black, (1 - d[colkey].alpha)));
		})
		.value_(d[colkey].green);
		green_numBox = NumberBox().maxDecimals_(2)
		.fixedSize_(numberWidth @ 22)
		.action_({arg view;
			view.value = numSpec.constrain(view.value);
			d[colkey].green = view.value;
			green_slider.value = d[colkey].green;
			colorSampleView.background_(d[colkey].copy.alpha_(1).blend(Color.black, (1 - d[colkey].alpha)));
		})
		.value_(d[colkey].green);
		// blue
		blue_slider = Slider().thumbSize_(8).orientation_(\horizontal)
		.fixedSize_(sliderWidth @ 22)
		.background_(Color.white).knobColor_(d.colButton)
		.action_({arg view;
			d[colkey].blue = view.value;
			blue_numBox.value_(d[colkey].blue);
			colorSampleView.background_(d[colkey].copy.alpha_(1).blend(Color.black, (1 - d[colkey].alpha)));
		})
		.value_(d[colkey].blue);
		blue_numBox = NumberBox().maxDecimals_(2)
		.fixedSize_(numberWidth @ 22)
		.action_({arg view;
			d[colkey].blue = view.value;
			blue_slider.value = d[colkey].blue;
			colorSampleView.background_(d[colkey].copy.alpha_(1).blend(Color.black, (1 - d[colkey].alpha)));
		})
		.value_(d[colkey].blue);
		// alpha
		if (showAlpha, {
			alpha_slider = Slider().thumbSize_(8).orientation_(\horizontal)
			.fixedSize_(sliderWidth @ 22)
			.background_(Color.white).knobColor_(d.colButton)
			.action_({arg view;
				d[colkey].alpha = view.value;
				alpha_numBox.value_(d[colkey].alpha);
				colorSampleView.background_(d[colkey].copy.alpha_(1).blend(Color.black, (1 - d[colkey].alpha)));
			})
			.value_(d[colkey].alpha);
			alpha_numBox = NumberBox().maxDecimals_(2)
			.fixedSize_(numberWidth @ 22)
			.action_({arg view;
				d[colkey].alpha = view.value;
				alpha_slider.value = d[colkey].alpha;
				colorSampleView.background_(d[colkey].copy.alpha_(1).blend(Color.black, (1 - d[colkey].alpha)));
			})
			.value_(d[colkey].alpha);
		});
		guiLayout = HLayout(
			StaticText().string_(nameString).align_(\center)
			.fixedSize_(nameWidth @ 22)
			.stringColor_(d.colLabelString).background_(d.colLabel),
			colorSampleView,
			colorPresetsPopup,
			6,
			StaticText().string_("R").align_(\center)
			.fixedSize_(24 @ 22)
			.stringColor_(d.colLabelString).background_(colors.redTint),
			red_slider,
			red_numBox,
			6,
			StaticText().string_("G").align_(\center)
			.fixedSize_(24 @ 22)
			.stringColor_(d.colLabelString).background_(colors.greenTint),
			green_slider,
			green_numBox,
			6,
			StaticText().string_("B").align_(\center)
			.fixedSize_(24 @ 22)
			.stringColor_(d.colLabelString).background_(colors.blueTint),
			blue_slider,
			blue_numBox,
			6,
		).spacing_(2);
		if (showAlpha, {
			guiLayout = guiLayout.add(
				StaticText().string_("A").align_(\center)
				.fixedSize_(24 @ 22)
				.stringColor_(d.colLabelString).background_(d.colLabel)
			);
			guiLayout = guiLayout.add(
				alpha_slider,
			);
			guiLayout = guiLayout.add(
				alpha_numBox,
			);
		});
		// return layout
		guiLayout;
	};
	// end of d.fEZColor
	d.fEZColorize = {arg event, colkey, nameString, sliderWidth = 200, nameWidth = 60,
		numberWidth = 34;
		var colorSampleView, colorPresetsPopup, hue_slider, hue_numBox, saturation_slider, saturation_numBox;
		var blue_slider, blue_numBox, alpha_slider, alpha_numBox, guiLayout;
		var numSpec = ControlSpec(0, 1);
		// color sample
		colorSampleView = UserView()
		.fixedSize_(26 @ 26)
		.background_(d[colkey].copy.alpha_(1).blend(Color.black, (1 - d[colkey].alpha)));
		// presets
		colorPresetsPopup = PopUpMenu()
		.fixedSize_(70 @ 22)
		.items_(d.colorizePresets.flop.slice(0))
		.stringColor_(Color.black).background_(d.colLabel)
		.value_(0)
		.action_({arg view;
			if (view.value > 0, {
				d[colkey] = d.colorizePresets.flop.slice(1)[view.value].copy;
			});
			d.rebuildWindow;
		});
		// hue
		hue_slider = Slider().thumbSize_(8).orientation_(\horizontal)
		.fixedSize_(sliderWidth @ 22)
		.background_(Color.white).knobColor_(d.colButton)
		.action_({arg view;
			view.value = numSpec.constrain(view.value);
			d[colkey] = Color.hsv(view.value.min(0.999), d[colkey].asHSV[1], 1, 1);
			hue_numBox.value_(view.value);
			colorSampleView.background_(d[colkey]);
		})
		.value_(d[colkey].asHSV[0]);
		hue_numBox = NumberBox().maxDecimals_(2)
		.fixedSize_(numberWidth @ 22)
		.action_({arg view;
			view.value = numSpec.constrain(view.value);
			d[colkey] = Color.hsv(view.value.min(0.999), d[colkey].asHSV[1], 1, 1);
			hue_slider.value_(view.value);
			colorSampleView.background_(d[colkey]);
		})
		.value_(d[colkey].asHSV[0]);
		// saturation
		saturation_slider = Slider().thumbSize_(8).orientation_(\horizontal)
		.fixedSize_(sliderWidth @ 22)
		.background_(Color.white).knobColor_(d.colButton)
		.action_({arg view;
			view.value = numSpec.constrain(view.value);
			d[colkey] = Color.hsv(d[colkey].asHSV[0].min(0.999), view.value.max(0.001), 1, 1);
			saturation_numBox.value_(view.value);
			colorSampleView.background_(d[colkey]);
		})
		.value_(d[colkey].asHSV[1]);
		saturation_numBox = NumberBox().maxDecimals_(2)
		.fixedSize_(numberWidth @ 22)
		.action_({arg view;
			view.value = numSpec.constrain(view.value);
			d[colkey] = Color.hsv(d[colkey].asHSV[0].min(0.999), view.value.max(0.001), 1, 1);
			saturation_slider.value_(view.value);
			colorSampleView.background_(d[colkey]);
		})
		.value_(d[colkey].asHSV[1]);
		guiLayout = HLayout(
			StaticText().string_(nameString).align_(\center)
			.fixedSize_(nameWidth @ 22)
			.stringColor_(d.colLabelString).background_(d.colLabel),
			colorSampleView,
			colorPresetsPopup,
			6,
			StaticText().string_("Hue").align_(\center)
			.fixedSize_(70 @ 22)
			.stringColor_(d.colLabelString).background_(Color.white),
			hue_slider,
			hue_numBox,
			6,
			StaticText().string_("Saturation").align_(\center)
			.fixedSize_(70 @ 22)
			.stringColor_(d.colLabelString).background_(Color.white),
			saturation_slider,
			saturation_numBox,
			nil,
		).spacing_(2);
		// return layout
		guiLayout;
	};
	// end of d.fEZColorize

	d.fUpdateTimeInfo = {
		if (d.guiData.timeInfoView.notNil, {
			d.guiData.timeInfoView.string_("  Pixels per sec:" + (d.imageWidth / d.playLength).round(0.01)
				+ "      Pixels per beat:" + (d.imageWidth / d.playLengthBeats).round(0.01));
		});
		if (d.guiData.timelineStringView.notNil, {
			d.guiData.timelineStringView.string_(
				"  Image Width (time pixels):" + d.imageWidth
				+ "  Image Height (freqs):" + d.imageHeight
				+ "     Freq Mode:"
				+ d.freqModeShortNames.flop.slice(0)[d.freqModeShortNames.flop.slice(1).indexOf(d.freqMode)]
				+ "     Pixels per Sec:" + (d.imageWidth / d.playLength).round(0.01)
				+ "  Pixels per Beat:" + (d.imageWidth / d.playLengthBeats).round(0.01)
			);
		});
		if (d.guiData.timeStretchBackView.notNil and: {d.guiData.timeStretchBackView.notClosed}, {
			d.guiData.timeStretchBackView.refresh;
		});
	};

	d.makeSettingsLayout = {
		d.makePlayLengthRow;
		// imageWidth numbox
		d.guiData.imageWidthNumbox = NumberBox().maxDecimals_(0)
		.fixedSize_(40 @ 22)
		.action_({arg view;
			view.value = d.imageWidthSpec.constrain(view.value);
			d.imageWidth = view.value.asInteger;
			d.fResizeImages;
			d.rebuildWindow;
		})
		.value_(d.imageWidth);
		// imageHeight numbox
		d.guiData.imageHeightNumbox = NumberBox().maxDecimals_(0)
		.fixedSize_(40 @ 22)
		.action_({arg view;
			view.value = d.imageHeightSpec.constrain(view.value);
			d.imageHeight = view.value.asInteger;
			d.fResizeImages;
			d.fBuildArrFreqs;
			d.rebuildWindow;
		})
		.value_(d.imageHeight);
		// stretchImageOnResize checkbox
		d.guiData.stretchImageCheckbox = Button().states_([
			["[ ] Stretch current image to fit when size changes", d.colButton, Color.white],
			["[X] Stretch current image to fit when size changes", Color.white, d.colButton]])
		.fixedSize_(280 @ 22)
		.action_({arg view;
			var val = view.value.asBoolean;
			d.stretchImageOnResize = val;
			d.rebuildSynth;
		})
		.value_(d.stretchImageOnResize.binaryValue);
		// keyboardView
		d.guiData.keyboardView = UserView()
		.fixedSize_(840 @ 22)
		.background_(Color.black)
		.drawFunc_({arg view;
			var numVoices = d.detunedCopies + 1;
			var width = 840 / d.arrFreqs.size;
			var octaveNotes;
			case {d.freqMode ==  'midiSemi'} {octaveNotes = 12 * numVoices}
			{d.freqMode ==  'midiQuarter'} {octaveNotes = 24 * numVoices}
			{d.freqMode ==  'midiScale'} {octaveNotes = d.allScales[d.midiScale].size * numVoices};
			d.arrFreqs.size.do({arg i;
				var colInd = i div: numVoices;
				// show octaves if relevant
				if (octaveNotes.notNil and: {(i % octaveNotes) <= d.detunedCopies}, {
					Pen.color = Color.green;
				},{
					if (d.freqMode == 'harm' and: {(colInd + 1).isPowerOfTwo}
						and: {(i % numVoices) == 0},
						{
							Pen.color = Color.green;
						},{
							if (d.freqMode == 'harmEven' and: {(colInd.max(1) * 2).isPowerOfTwo}
								and: {(i % numVoices) == 0},
								{
									Pen.color = Color.green;
								},{
									Pen.color = [Color.grey(0.4), Color.grey(0.97)].wrapAt(colInd);
							});
					});
				});
				Pen.fillRect(Rect((i * width), 0, width - 1, 22));
			});
		})
		.mouseDownAction_({arg view, x, y, mod;
			var width = view.bounds.width / d.arrFreqs.size;
			var freqIndex = (x div: width).asInteger;
			var freq = d.arrFreqs[freqIndex];
			d.fPlayKeyboardNote(freq);
		})
		.mouseMoveAction_({arg view, x, y, mod;
			var width = view.bounds.width / d.arrFreqs.size;
			var freqIndex = (x div: width).asInteger;
			var freq = d.arrFreqs[freqIndex];
			if (d.lastFreqPlayed != freq, {
				d.fPlayKeyboardNote(freq);
			});
		});
		if (d.flagFreqLimitError, {
			d.guiData.freqInfoView = StaticText()
			.string_("  " ++ d.freqLimitErrorString).align_(\left)
			.fixedSize_(680 @ 22)
			.stringColor_(d.colLabelString).background_(d.colWarning);
		}, {
			d.guiData.freqInfoView = StaticText()
			.string_("  Min. Freq:" + d.arrFreqs.first.round.asInteger
				+ "      Max. Freq:" + d.arrFreqs.last.round.asInteger
			).align_(\left)
			.fixedSize_(290 @ 22)
			.stringColor_(d.colLabelString).background_(d.colButton.blend(Color.white, 0.9));
		});
		d.guiData.timeInfoView = StaticText().align_(\left)
		.fixedSize_(290 @ 22)
		.stringColor_(d.colLabelString).background_(d.colButton.blend(Color.white, 0.9));
		d.fUpdateTimeInfo; // run function now
		// settings top row
		d.guiData.settingsTopRow = HLayout (
			d.guiData.playLengthRow,
			35,
			d.fEZNumBox(ControlSpec(1, 99999, step: 1), 'randSeed', "Random Seed", 90, 60),
			StaticText().string_("Rand").align_(\center)
			.fixedSize_(40 @ 22)
			.stringColor_(Color.white).background_(d.colButton)
			.mouseDownAction_({
				d.randSeed = rrand(1, 99999);
				d.fBuildArrFreqs;
				d.rebuildWindow;
			}),
			35,
			StaticText().string_("Load Default Image Settings").align_(\center)
			.fixedSize_(170 @ 22)
			.stringColor_(Color.white).background_(d.colButton)
			.mouseDownAction_({
				d.fLoadDefaultImageSettings;
				d.rebuildWindow;
			}),
			20,
			StaticText().string_("Load Default Settings Everywhere").align_(\center)
			.fixedSize_(200 @ 22)
			.stringColor_(Color.white).background_(d.colButton.blend(Color.black, 0.2))
			.mouseDownAction_({
				d.fLoadAllDefaultSettings;
				d.rebuildWindow;
			}),
			nil,
		);
		// settings Layout
		d.guiData.settingsLayout = VLayout(
			d.guiData.settingsTopRow,
			6,
			HLayout(
				HLayout(
					// label
					StaticText().string_("Image Width / Number of Time Pixels").align_(\center)
					.fixedSize_(240 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel),
					// numbox
					d.guiData.imageWidthNumbox,
					PopUpMenu()
					.fixedSize_(60 @ 22)
					.items_(["..."] ++ [48, 60, 72, 84, 96, 108, 120, 144, 168, 192, 216, 240, 384, 480, 768, 960, 1200]
						.collect({arg item; item.asString}))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(0)
					.action_({arg view;
						if (view.value != 0, {
							d.guiData.imageWidthNumbox.valueAction_(
								[48, 60, 72, 84, 96, 108, 120, 144, 168, 192, 216, 240, 384, 480, 768, 960, 1200]
								[view.value - 1]);
						});
					}),
				).spacing_(2),
				16,
				d.guiData.timeInfoView,
				16,
				d.guiData.stretchImageCheckbox,
				nil,
			),
			6,
			HLayout(
				HLayout(
					// label
					StaticText().string_("Image Height / Number of Frequencies").align_(\center)
					.fixedSize_(240 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel),
					// numbox
					d.guiData.imageHeightNumbox,
					PopUpMenu()
					.fixedSize_(60 @ 22)
					.items_(["..."] ++ [12, 16, 24, 32, 36, 48, 60, 64, 72, 84, 96, 108, 120, 128, 132,
						144, 156, 168, 180, 192, 204, 216, 228, 240].collect({arg item; item.asString}))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(0)
					.action_({arg view;
						if (view.value != 0, {
							d.guiData.imageHeightNumbox.valueAction_(
								[12, 16, 24, 32, 36, 48, 60, 64, 72, 84, 96, 108, 120, 128, 132,
									144, 156, 168, 180, 192, 204, 216, 228, 240].at(view.value - 1)
							);
						});
						view.value = 0;
					}),
				).spacing_(2),
				16,
				d.guiData.freqInfoView,
				nil,
			),
			6,
			HLayout(
				// Keyboard
				[StaticText().string_("Freq Keyboard").align_(\center)
					.fixedSize_(100 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				[d.guiData.keyboardView, align: \top],
				nil,
			),
			6,
			HLayout(
				// Frequency Mode label
				[StaticText().string_("Frequency Mode").align_(\center)
					.fixedSize_(100 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				// Frequency Mode popup
				[ListView()
					.fixedSize_(340 @ 70)
					.items_(d.freqModeOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.freqModeOptions.flop.slice(1).indexOfEqual(d.freqMode))
					.action_({arg view;
						d.freqMode = d.freqModeOptions.flop.slice(1)[view.value];
						d.fBuildArrFreqs;
						d.rebuildWindow;
					}),
					align: \top],
				20,
				// Amp Compensation label
				[StaticText().string_("Amp Compensation").align_(\center)
					.fixedSize_(120 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				// Amp Compensation popup
				[ListView()
					.fixedSize_(330 @ 70)
					.items_(d.ampCompOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.ampCompOptions.flop.slice(1).indexOfEqual(d.ampComp))
					.action_({arg view;
						d.ampComp = d.ampCompOptions.flop.slice(1)[view.value];
						d.ampCompFunc = d.ampCompOptions.flop.slice(2)[view.value];
						d.fAddKeyboardSynthDef;
						d.synthSpecHasChanged = true;
					}),
					align: \top],
				nil,
			),
			10,
		);
		if (d.freqMode == 'exp' or: {d.freqMode == 'lin'}, {
			// Freq RangeSlider & numbox
			d.guiData.freqRangeSlider = RangeSlider().orientation_(\horizontal)
			.fixedSize_(800 @ 22)
			.background_(Color.white).knobColor_(d.colButton)
			.action_({arg view;
				d.minFreq = d.freqRangeSpec.map(view.lo);
				d.maxFreq = d.freqRangeSpec.map(view.hi);
				d.guiData.minFreqNumbox.value_(d.minFreq);
				d.guiData.maxFreqNumbox.value_(d.maxFreq);
			})
			.mouseUpAction_({arg view;
				d.fBuildArrFreqs;
				d.rebuildWindow;
			})
			.lo_(d.freqRangeSpec.unmap(d.minFreq))
			.hi_(d.freqRangeSpec.unmap(d.maxFreq));
			// minFreq numbox
			d.guiData.minFreqNumbox = NumberBox().maxDecimals_(2)
			.fixedSize_(40 @ 22)
			.action_({arg view;
				view.value = d.freqRangeSpec.constrain(view.value);
				d.guiData.freqRangeSlider.activeLo = d.freqRangeSpec.unmap(view.value);
				d.fBuildArrFreqs;
				d.rebuildWindow;
			})
			.value_(d.minFreq);
			// maxFreq numbox
			d.guiData.maxFreqNumbox = NumberBox().maxDecimals_(2)
			.fixedSize_(40 @ 22)
			.action_({arg view;
				view.value = d.freqRangeSpec.constrain(view.value);
				d.guiData.freqRangeSlider.activeHi = d.freqRangeSpec.unmap(view.value);
				d.fBuildArrFreqs;
				d.rebuildWindow;
			})
			.value_(d.maxFreq);
			d.guiData.settingsLayout.add(HLayout(
				HLayout(
					// Frequency Range label
					StaticText().string_("Frequency Range").align_(\center)
					.fixedSize_(100 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel),
					// range slider, numboxes
					d.guiData.freqRangeSlider,
					d.guiData.minFreqNumbox,
					d.guiData.maxFreqNumbox,
				).spacing_(2),
				nil,
			));
		}, {
			// else use midi note, scale and tuning
			// midiNoteLowest ListView
			d.guiData.midiNoteLowestListView = ListView()
			.fixedSize_(220 @ 140)
			.items_((24..128).collect({arg note;
				var octText = ((note div: 12) - 2).asString;
				var noteText;
				noteText =
				["C", "C#", "D", "D#", "E", "F", "F#", "G","G#", "A", "A#", "B"].at(note % 12)
				++ octText ++ ", freq: "++ note.midicps.round(0.01)
				++ ", midi note: "++ note.asString;
				noteText;
			}))
			.stringColor_(Color.black).background_(d.colLabel)
			.value_(d.midiNoteLowest - 24)
			.action_({arg view;
				d.midiNoteLowest = view.value + 24;
				d.fBuildArrFreqs;
				d.rebuildWindow;
			});
			// Global Detune Cents
			d.guiData.globalDetuneCentsSlider = Slider().thumbSize_(8).orientation_(\horizontal)
			.fixedSize_(350 @ 22)
			.background_(Color.white).knobColor_(d.colButton)
			.action_({arg view;
				d.globalDetuneCents = d.globalDetuneCentsSpec.map(view.value);
				d.guiData.globalDetuneCentsNumbox.value_(d.globalDetuneCents);
			})
			.mouseUpAction_({arg view;
				d.fBuildArrFreqs;
				d.rebuildWindow;
			})
			.value_(d.globalDetuneCentsSpec.unmap(d.globalDetuneCents));
			d.guiData.globalDetuneCentsNumbox = NumberBox().maxDecimals_(2)
			.fixedSize_(40 @ 22)
			.action_({arg view;
				view.value = d.globalDetuneCentsSpec.constrain(view.value);
				d.globalDetuneCents = view.value;
				d.guiData.globalDetuneCentsSlider.value = d.globalDetuneCentsSpec.unmap(d.globalDetuneCents);
				d.fBuildArrFreqs;
				d.rebuildWindow;
			})
			.value_(d.globalDetuneCents);
			d.guiData.globalDetuneCentsRow = HLayout(
				[StaticText().string_("Global Detune Cents").align_(\center)
					.fixedSize_(140 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				[d.guiData.globalDetuneCentsSlider, align: \top],
				[d.guiData.globalDetuneCentsNumbox, align: \top],
				// Set 0 button
				[StaticText().string_("Set 0").align_(\center)
					.fixedSize_(50 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({
						d.guiData.globalDetuneCentsNumbox.valueAction_(0)
				}), align: \top],
				nil,
			);
			// Detuned Copies
			d.guiData.detunedCopiesRow = HLayout(
				// Detuned Copies label
				[StaticText().string_("Voices Per Note").align_(\center)
					.fixedSize_(140 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				// [d.guiData.detunedCopiesNumbox, align: \top],
				// Detuned Copies ListView
				[ListView()
					.fixedSize_(40 @ 66)
					.items_(10.collect({arg i; (i + 1).asString}))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.detunedCopies)
					.action_({arg view;
						d.detunedCopies = view.value;
						d.fBuildArrFreqs;
						d.rebuildWindow;
				}), align: \top],
				20,
				// detuneFirstVoice checkbox
				[Button().states_([
					["[ ] Apply Random Detune To First Voice", d.colButton, Color.white],
					["[X] Apply Random Detune To First Voice", Color.white, d.colButton]])
				.fixedSize_(240 @ 22)
				.action_({arg view;
					var val = view.value.asBoolean;
					d.detuneFirstVoice = val;
					d.fBuildArrFreqs;
					d.rebuildWindow;
				})
				.value_(d.detuneFirstVoice.binaryValue), align: \top],
				nil,
			);
			// Copy Rand Detune Cents
			d.guiData.copyRandDetuneCentsSlider = Slider().thumbSize_(8).orientation_(\horizontal)
			.fixedSize_(400 @ 22)
			.background_(Color.white).knobColor_(d.colButton)
			.action_({arg view;
				d.copyRandDetuneCents = d.copyRandDetuneCentsSpec.map(view.value);
				d.guiData.copyRandDetuneCentsNumbox.value_(d.copyRandDetuneCents);
			})
			.mouseUpAction_({arg view;
				d.fBuildArrFreqs;
				d.rebuildWindow;
			})
			.value_(d.copyRandDetuneCentsSpec.unmap(d.copyRandDetuneCents));
			d.guiData.copyRandDetuneCentsNumbox = NumberBox().maxDecimals_(2)
			.fixedSize_(40 @ 22)
			.action_({arg view;
				view.value = d.copyRandDetuneCentsSpec.constrain(view.value);
				d.copyRandDetuneCents = view.value;
				d.guiData.copyRandDetuneCentsSlider.value = d.copyRandDetuneCentsSpec.unmap(d.copyRandDetuneCent);
				d.fBuildArrFreqs;
				d.rebuildWindow;
			})
			.value_(d.copyRandDetuneCents);
			d.guiData.copyRandDetuneCentsRow = HLayout(
				[StaticText().string_("Random Detune Cents").align_(\center)
					.fixedSize_(140 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				[d.guiData.copyRandDetuneCentsSlider, align: \top],
				[d.guiData.copyRandDetuneCentsNumbox, align: \top],
				nil,
			);
			d.guiData.settingsLayout.add(HLayout(
				// Lowest MIDI Note label
				VLayout(
					[StaticText().string_("Lowest Note").align_(\center)
						.fixedSize_(100 @ 22)
						.stringColor_(d.colLabelString).background_(d.colLabel),
						align: \center],
					6,
					[StaticText().string_("-1 Octave").align_(\center)
						.fixedSize_(74 @ 22)
						.stringColor_(Color.white).background_(d.colButton)
						.mouseDownAction_({d.fOctaveDown(\midiNoteLowest) }),
						align: \center],
					6,
					[StaticText().string_("+1 Octave").align_(\center)
						.fixedSize_(74 @ 22)
						.stringColor_(Color.white).background_(d.colButton)
						.mouseDownAction_({d.fOctaveUp(\midiNoteLowest) }),
						align: \center],
					nil,
				),
				// list
				[d.guiData.midiNoteLowestListView, align: \top],
				20,
				VLayout(
					d.guiData.globalDetuneCentsRow,
					6,
					d.guiData.copyRandDetuneCentsRow,
					6,
					d.guiData.detunedCopiesRow,
					nil,
				),
				nil,
			));
			if (d.freqMode == 'midiScale', {
				d.guiData.scaleLayout = HLayout(
					// Pitches Per Octave label
					[StaticText().string_("Pitches Per Octave").align_(\center)
						.fixedSize_(120 @ 22)
						.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
					// Pitches Per Octave ListView
					[ListView()
						.fixedSize_(40 @ 140)
						.items_(d.midiPitchesPerOctOptions.flop.slice(0))
						.stringColor_(Color.black).background_(d.colLabel)
						.value_(d.midiPitchesPerOctOptions.flop.slice(1).indexOfEqual(d.midiPitchesPerOct))
						.action_({arg view;
							d.midiPitchesPerOct = d.midiPitchesPerOctOptions.flop.slice(1)[view.value];
							d.fUpdateScaleData;
							d.fBuildArrFreqs;
							d.rebuildWindow;
					}), align: \top],
					20,
					// Scale label
					[StaticText().string_("Scale").align_(\center)
						.fixedSize_(50 @ 22)
						.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
					// Scale ListView
					[ListView()
						.fixedSize_(300 @ 140)
						.items_(d.midiScaleOptions.flop.slice(0))
						.stringColor_(Color.black).background_(d.colLabel)
						.value_(d.midiScaleOptions.flop.slice(1).indexOfEqual(d.midiScale))
						.action_({arg view;
							d.midiScale = d.midiScaleOptions.flop.slice(1)[view.value];
							d.fUpdateScaleData;
							d.fBuildArrFreqs;
							d.rebuildWindow;
					}), align: \top],
					20,
				);
				if (d.midiTuningOptions.size > 0, {
					d.guiData.scaleLayout.add(
						// Tuning label
						StaticText().string_("Tuning").align_(\center)
						.fixedSize_(60 @ 22)
						.stringColor_(d.colLabelString).background_(d.colLabel), align: \top
					);
					d.guiData.scaleLayout.add(
						// Tuning ListView
						ListView()
						.fixedSize_(290 @ 140)
						.items_(d.midiTuningOptions.flop.slice(0))
						.stringColor_(Color.black).background_(d.colLabel)
						.value_(d.midiTuningOptions.flop.slice(1).indexOfEqual(d.midiTuning))
						.action_({arg view;
							d.midiTuning = d.midiTuningOptions.flop.slice(1)[view.value];
							d.fBuildArrFreqs;
							d.rebuildWindow;
						}), align: \top
					);
				});
				d.guiData.scaleLayout.add(nil); // final spacer
				d.guiData.settingsLayout.add(6);
				d.guiData.settingsLayout.add(d.guiData.scaleLayout);
			});
		});
	};
	// end of d.makeSettingsLayout{}

	d.makeSoundLayout = {
		d.makePlayLengthRow;
		d.makeTestNoteRow;
		d.guiData.soundSourceLayout = nil;
		case {d.soundSource == 'filteredNoise'} {
			d.guiData.soundSourceLayout = VLayout(
				UserView().fixedHeight_(2).background_(Color.white),
				HLayout(
					d.guiData.testNoteRow,
					20,
					[StaticText().string_("Play test note").align_(\center)
						.fixedSize_(110 @ 22)
						.stringColor_(Color.white).background_(d.colButton)
						.mouseDownAction_({d.fPlayFilteredNoiseNote(d.midiPlayNote.midicps);}),
						align: \top],
					nil,
				),
				nil,
			).spacing_(10);
		}
		{d.soundSource == 'sines'} {
			d.guiData.soundSourceLayout = VLayout(
				UserView().fixedHeight_(2).background_(Color.white),
				HLayout(
					d.guiData.testNoteRow,
					20,
					[StaticText().string_("Play test note").align_(\center)
						.fixedSize_(110 @ 22)
						.stringColor_(Color.white).background_(d.colButton)
						.mouseDownAction_({d.fPlaySinesNote(d.midiPlayNote.midicps);}),
						align: \top],
					nil,
				),
				nil,
			).spacing_(10);
		}
		{d.soundSource == 'phaseModSines' or: {d.soundSource == 'phaseModSinesNoise'}} {
			var noiseRow = 0;
			if (d.soundSource == 'phaseModSinesNoise', {
				noiseRow = d.fEZSlider(ControlSpec(0, 1), 'playNoiseMix', "Test Noise Mix", 300).add(nil);
			});
			d.guiData.soundSourceLayout = VLayout(
				d.fEZSlider(ControlSpec(1, 20), 'phaseModMaxModulation', "Max. Modulation", 300, 180)
				.add(
					PopUpMenu().fixedSize_(70 @ 22)
					.items_(["presets"]
						++ ["1", "2 (default)", "3", "4", "5", "10", "15", "20",]
						.collect({arg item; item.asString}))
					.stringColor_(Color.black).background_(Color.white)
					.value_(0)
					.action_({arg view;
						if (view.value > 0, {
							d.phaseModMaxModulation = [1, 2, 3, 4, 5, 10, 15, 20].at(view.value - 1);
							d.rebuildWindow;
						});
					})
				)
				.add(nil),
				6,
				d.fEZSlider(ControlSpec(0.125, 8, \exp), 'phaseModFreqRatio', "Modulation Freq Ratio",
					300, 180, 50, {}, {d.synthSpecHasChanged = true;})
				.add(
					PopUpMenu().fixedSize_(70 @ 22)
					.items_(["presets"]
						++ ["0.125", "0.25", "0.5", "1", "1.5 (default)", "2", "3", "4", "5", "6", "7", "8",]
						.collect({arg item; item.asString}))
					.stringColor_(Color.black).background_(Color.white)
					.value_(0)
					.action_({arg view;
						if (view.value > 0, {
							d.phaseModFreqRatio = [0.125, 0.25, 0.5, 1, 1.5, 2, 3, 4, 5, 6, 7, 8,]
							.at(view.value - 1);
							d.rebuildWindow;
						});
					})
				)
				.add(nil),
				UserView().fixedHeight_(2).background_(Color.white),
				HLayout(
					d.guiData.testNoteRow,
					20,
					VLayout(
						noiseRow,
						HLayout(
							[StaticText().string_("Play test note with increasing modulation").align_(\center)
								.fixedSize_(250 @ 22)
								.stringColor_(Color.white).background_(d.colButton)
								.mouseDownAction_({
									var noiseMix;
									if (d.soundSource == 'phaseModSinesNoise', {
										noiseMix = d.playNoiseMix;
									}, {
										noiseMix = 0;
									});
									d.fPlayPhaseModNote(d.midiPlayNote.midicps, noiseMix);
								}),
								align: \top],
							nil,
						).spacing_(20),
						nil,
					).spacing_(14),
					nil,
				),
				nil,
			).spacing_(10);
		}
		{d.soundSource == 'phaseModSines2'} {
			d.guiData.soundSourceLayout = VLayout(
				d.fEZSlider(ControlSpec(1, 20), 'phaseModMaxModulation', "Max. Modulation", 300, 180)
				.add(
					PopUpMenu().fixedSize_(70 @ 22)
					.items_(["presets"]
						++ ["1", "2 (default)", "3", "4", "5", "10", "15", "20",]
						.collect({arg item; item.asString}))
					.stringColor_(Color.black).background_(Color.white)
					.value_(0)
					.action_({arg view;
						if (view.value > 0, {
							d.phaseModMaxModulation = [1, 2, 3, 4, 5, 10, 15, 20].at(view.value - 1);
							d.rebuildWindow;
						});
					})
				)
				.add(nil),
				6,
				d.fEZRangeSlider(ControlSpec(0.125, 8, 1), 'phaseModMinRatio', 'phaseModMaxRatio',
					"Modulation Freq Ratio: Range", 248, 180, 50, {}, {
						var stepSize;
						d.fAddPhaseModSynthDef2;
						d.synthSpecHasChanged = true;
						if (d.phaseModRatioStep != '0', {
							stepSize = d.phaseModRatioStepOptions.flop.slice(2)
							[d.phaseModRatioStepOptions.flop.slice(1).indexOfEqual(d.phaseModRatioStep)];
							d.phaseModMinRatio = d.phaseModMinRatio.round(stepSize);
							d.phaseModMaxRatio = d.phaseModMaxRatio.round(stepSize);
							d.rebuildWindow;
						});
				}).add(
					PopUpMenu().fixedSize_(70 @ 22)
					.items_(["presets"]
						++ ["0.125 - 1", "0.25 - 1", "0.5 - 2", "1 - 2", "1 - 3", "1 - 4 (default)", "1 - 8", ]
						.collect({arg item; item.asString}))
					.stringColor_(Color.black).background_(Color.white)
					.value_(0)
					.action_({arg view;
						var minMax;
						if (view.value > 0, {
							minMax = [[0.125,  1], [0.25,  1], [0.5,  2], [1,  2], [1,  3], [1,  4], [1,  8], ]
							.at(view.value - 1);
							d.phaseModMinRatio = minMax[0];
							d.phaseModMaxRatio = minMax[1];
							d.rebuildWindow;
						});
					})
				).add(nil),
				6,
				HLayout(
					// Mod.  Freq Ratio: Quantize label
					[StaticText().string_("Mod. Freq Ratio: Quantize").align_(\center)
						.fixedSize_(180 @ 22)
						.stringColor_(d.colLabelString).background_(d.colLabel),
						align: \top],
					// Mod.  Freq Ratio: Quantize popup
					[PopUpMenu()
						.fixedSize_(70 @ 22)
						.items_(d.phaseModRatioStepOptions.flop.slice(0))
						.stringColor_(Color.black).background_(d.colLabel)
						.value_(d.phaseModRatioStepOptions.flop.slice(1).indexOfEqual(d.phaseModRatioStep))
						.action_({arg view;
							var stepSize;
							d.phaseModRatioStep = d.phaseModRatioStepOptions.flop.slice(1)[view.value];
							if (view.value > 0, {
								stepSize = d.phaseModRatioStepOptions.flop.slice(2)
								[d.phaseModRatioStepOptions.flop.slice(1).indexOfEqual(d.phaseModRatioStep)];
								d.phaseModMinRatio = d.phaseModMinRatio.round(stepSize);
								d.phaseModMaxRatio = d.phaseModMaxRatio.round(stepSize);
								d.rebuildWindow;
							});
							d.fAddPhaseModSynthDef2;
							d.synthSpecHasChanged = true;
						}),
						align: \top],
					nil,
				).spacing_(2),
				UserView().fixedHeight_(2).background_(Color.white),
				HLayout(
					d.guiData.testNoteRow,
					20,
					[StaticText().string_("Play test note with increasing modulation and freq ratio").align_(\center)
						.fixedSize_(320 @ 22)
						.stringColor_(Color.white).background_(d.colButton)
						.mouseDownAction_({d.fPlayPhaseModNote2(d.midiPlayNote.midicps);}),
						align: \top],
					nil,
				),
				nil,
			).spacing_(10);
		}
		{d.soundSource == 'wavetables' or: {d.soundSource == 'wavetablesNoise'}} {
			var noiseRow = 0;
			if (d.soundSource == 'wavetablesNoise', {
				noiseRow = d.fEZSlider(ControlSpec(0, 1), 'playNoiseMix', "Test Noise Mix", 300).add(nil);
			});
			d.guiData.soundSourceLayout = VLayout(
				HLayout(
					d.fEZWavetable("Wavetable 1 Harmonics", 'wtAmps', 0, 300, 250, {d.fUpdateWTBuffer(0)}),
					d.fEZWavetable("Wavetable 2 Harmonics", 'wtAmps', 1, 300, 250, {d.fUpdateWTBuffer(1)}),
					d.fEZWavetable("Wavetable 3 Harmonics", 'wtAmps', 2, 300, 250, {d.fUpdateWTBuffer(2)}),
					nil,
				).spacing_(24),
				UserView().fixedHeight_(2).background_(Color.white),
				HLayout(
					d.guiData.testNoteRow,
					VLayout(
						noiseRow,
						HLayout(
							[StaticText().string_("Test Wavetable 1").align_(\center)
								.fixedSize_(110 @ 22)
								.stringColor_(Color.white).background_(d.colButton)
								.mouseDownAction_({d.fPlayWavetableNote(d.midiPlayNote.midicps, 0, 0, 1)}),
								align: \top],
							[StaticText().string_("Test Wavetable 2").align_(\center)
								.fixedSize_(110 @ 22)
								.stringColor_(Color.white).background_(d.colButton)
								.mouseDownAction_({d.fPlayWavetableNote(d.midiPlayNote.midicps, 1, 1, 1)}),
								align: \top],
							[StaticText().string_("Test Wavetable 3").align_(\center)
								.fixedSize_(110 @ 22)
								.stringColor_(Color.white).background_(d.colButton)
								.mouseDownAction_({d.fPlayWavetableNote(d.midiPlayNote.midicps, 1.99, 1.99, 1)}),
								align: \top],
							[StaticText().string_("Test Wavetables Morph 1-2-3").align_(\center)
								.fixedSize_(170 @ 22)
								.stringColor_(Color.white).background_(d.colButton)
								.mouseDownAction_({d.fPlayWavetableNote(d.midiPlayNote.midicps, 0, 1.99, 2)}),
								align: \top],
							nil,
						).spacing_(20),
						nil,
					).spacing_(14),
					nil,
				).spacing_(20),
			).spacing_(10);
		};
		d.guiData.settingsLayout = VLayout(
			HLayout (
				d.guiData.playLengthRow,
				35,
				StaticText().string_("Load Default Sound Settings").align_(\center)
				.fixedSize_(170 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({d.fLoadDefaultSoundSettings; d.rebuildWindow;}),
				nil,
			),
			6,
			HLayout(
				// Sound Source label
				[StaticText().string_("Sound Source").align_(\center)
					.fixedSize_(90 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				// Sound Source popup
				[ListView()
					.fixedSize_(400 @ 90)
					.items_(d.soundSourceOptions.flop.slice(0).collect({arg item; item }))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.soundSourceOptions.flop.slice(1).indexOfEqual(d.soundSource))
					.action_({arg view;
						d.soundSource = d.soundSourceOptions.flop.slice(1)[view.value];
						d.synthSpecHasChanged = true; // flag update
						d.fAddWavetableSynthDef;
						d.rebuildWindow;
					}),
					align: \top],
				20,
				// label
				[StaticText().string_("Stereo Mode").align_(\center)
					.fixedSize_(84 @ 20)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				// Color Stereo Mode popup
				[ListView()
					.fixedSize_(340 @ 90)
					.items_(d.stereoModeOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.stereoModeOptions.flop.slice(1).indexOfEqual(d.stereoMode))
					.action_({arg view;
						d.stereoMode = d.stereoModeOptions.flop.slice(1)[view.value];
						d.synthSpecHasChanged = true; // flag update
						d.rebuildWindow;
				}), align: \top],
				nil,
			),
			6,
			d.fEZSlider(ControlSpec(0.05, 0.95), 'masterCompress', "Compress/Normalize Levels", 400, 200)
			.add(10)
			.add(StaticText().string_("Default 0.7").align_(\center)
				.fixedSize_(80 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({d.masterCompress = 0.7; d.rebuildWindow;}),
			).add(nil),
			6,
			d.guiData.soundSourceLayout,
			nil,
		);
	};
	// end of d.makeSoundLayout{}

	d.makeSnapshotsRow = {
		d.guiData.snapshotsRow = HLayout (
			// // Snapshots text
			// [StaticText().string_("Snapshots:").align_(\center)
			// 	.fixedSize_(70 @ 22)
			// 	.stringColor_(d.colButton).background_(d.colLabel),
			// align: \top],
			// Store Snapshot
			StaticText().string_("Store Snapshot").align_(\center)
			.fixedSize_(90 @ 22)
			.stringColor_(Color.white).background_(d.colButton)
			.mouseDownAction_({
				d.fStoreSnapshot;
				d.rebuildWindow;
			}),
			// Snapshots popup
			PopUpMenu()
			.fixedSize_(100 @ 22)
			.items_(d.snapshotHistory.size.collect({arg i; "Shapshot" + (i + 1)}))
			.stringColor_(Color.black).background_(d.colLabel)
			.value_(d.snapshotIndex)
			.action_({arg view;
				d.snapshotIndex = view.value;
				d.rebuildWindow;
			}),
		).spacing_(2);
		if (d.snapshotHistory.size > 0, {
			d.guiData.snapshotsRow.add(
				// Load Snapshot
				StaticText()
				.string_("Load")
				.align_(\center)
				.fixedSize_(44 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.fLoadSnapshot;
					d.rebuildWindow;
				})
			);
			d.guiData.snapshotsRow.add(
				// Delete Snapshot
				StaticText()
				.string_("Delete")
				.align_(\center)
				.fixedSize_(50 @ 22)
				.stringColor_(Color.white).background_(d.colStop)
				.mouseDownAction_({
					d.fDeleteSnapshot;
					d.rebuildWindow;
				})
			);
		});
		d.guiData.snapshotsRow.add(nil);
	};
	// end of d.makeSnapshotsRow

	d.makeImageSelectRow = {
		// imageSelectRow
		d.guiData.imageSelectRow = UserView().background_(Color.gray(0.6))
		.fixedHeight_(34)
		.layout_(HLayout (
			[StaticText().string_("Image 1").align_(\center)
				.fixedSize_(52 @ 22)
				.stringColor_(Color.black).background_(d.fGetImageSelectCol(0))
				.mouseDownAction_({
					d.fCheckBuildSynthDef;
					d.imageIndex = 0;
					d.rebuildWindow;
			}), align: \top],
			[StaticText().string_("Image 2").align_(\center)
				.fixedSize_(52 @ 22)
				.stringColor_(Color.black).background_(d.fGetImageSelectCol(1))
				.mouseDownAction_({
					d.fCheckBuildSynthDef;
					d.imageIndex = 1;
					d.rebuildWindow;
			}), align: \top],
		).margins_(7).spacing_(5));
	};

	d.makePlayLengthRow = {
		// play length numbox
		d.guiData.playLengthNumbox = NumberBox().maxDecimals_(3)
		.fixedSize_(40 @ 22).background_(d.colHighlight)
		.value_(d.playLength)
		.action_({arg view;
			view.value = d.playLengthSpec.constrain(view.value);
			d.playLength = view.value;
			d.fUpdateBPM;
			d.guiData.playBPMNumbox.value = d.playBPM;
			d.rebuildWindow;
		});
		// play length beats numbox
		d.guiData.playLengthBeatsNumbox = NumberBox().maxDecimals_(3)
		.fixedSize_(40 @ 22)
		.value_(d.playLengthBeats)
		.action_({arg view;
			view.value = d.playLengthBeatsSpec.constrain(view.value);
			d.playLengthBeats = view.value;
			d.fUpdateBPM;
			d.guiData.playBPMNumbox.value = d.playBPM;
			d.rebuildWindow;
		});
		// play BPM numbox
		d.guiData.playBPMNumbox = NumberBox().maxDecimals_(3)
		.fixedSize_(40 @ 22)
		.value_(d.playBPM)
		.action_({arg view;
			view.value = d.playBPMSpec.constrain(view.value);
			d.playBPM = view.value;
			d.guiData.playLengthNumbox.valueAction_(60 * d.playLengthBeats / d.playBPM);
		});
		d.guiData.playLengthRow = HLayout(
			// label
			StaticText().string_("Play Length:").align_(\center)
			.fixedSize_(73 @ 22)
			.stringColor_(d.colLabelString).background_(d.colLabel),
			// d.guiData.playLengthSlider,
			d.guiData.playLengthNumbox,
			StaticText().string_("secs =").align_(\center)
			.fixedSize_(40 @ 22)
			.stringColor_(d.colLabelString).background_(d.colLabel),
			d.guiData.playLengthBeatsNumbox,
			StaticText().string_("beats at").align_(\center)
			.fixedSize_(50 @ 22)
			.stringColor_(d.colLabelString).background_(d.colLabel),
			d.guiData.playBPMNumbox,
			StaticText().string_("BPM").align_(\center)
			.fixedSize_(30 @ 22)
			.stringColor_(d.colLabelString).background_(d.colLabel),
		).spacing_(2);
	};
	// end of d.makePlayLengthRow

	d.makePlayRow = {
		d.makePlayLengthRow;
		d.guiData.playRow = HLayout (
			// Rewind button
			StaticText().string_("Rewind").align_(\center)
			.fixedSize_(50 @ 22)
			.stringColor_(Color.white).background_(d.colButton)
			.mouseDownAction_({
				d.fSetPlayPosition(0);
			}),
			2, // spacer
			// Play From Start button
			StaticText().string_("Play @ Start").align_(\center)
			.fixedSize_(80 @ 22)
			.stringColor_(Color.white).background_(d.colPlay)
			.mouseDownAction_({
				if (d.isRecording, {
					d.fShowError("Warning: Recording in progress. Cannot play now.");
				}, {
					// if (d.imageSynth.isPlaying.not, {
						d.fPlaySound({}, true);
					// });
				});
			}),
			2, // spacer
			// Play button
			StaticText().string_("Play").align_(\center)
			.fixedSize_(40 @ 22)
			.stringColor_(Color.white).background_(d.colPlay)
			.mouseDownAction_({
				if (d.isRecording, {
					d.fShowError("Warning: Recording in progress. Cannot play now.");
				}, {
					// if (d.imageSynth.isPlaying.not, {
						d.fPlaySound;
					// });
				});
			}),
			2, // spacer
			// Stop button
			StaticText().string_("Stop").align_(\center)
			.fixedSize_(40 @ 22)
			.stringColor_(Color.white).background_(d.colStop)
			.mouseDownAction_({
				d.fStopSound;
				d.fStopRecording;
			}),
			2, // spacer
			// Loop checkbox
			Button().states_([
				["[ ] Loop", d.colButton, Color.white],
				["[X] Loop", Color.white, d.colButton]])
			.fixedSize_(56 @ 22)
			.action_({arg view;
				d.playLooped = view.value.asBoolean;
			})
			.value_(d.playLooped.binaryValue),
			10, // spacer
			d.guiData.playLengthRow,
		);
	};
	// end of d.makePlayRow

	d.makeTestNoteRow = {
		d.guiData.testNoteRow = HLayout(
			VLayout(
				[StaticText().string_("Test Note").align_(\center)
					.fixedSize_(100 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel),
					align: \center],
				[StaticText().string_("- Octave").align_(\center)
					.fixedSize_(70 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({d.fOctaveDown(\midiPlayNote)}),
					align: \center],
				[StaticText().string_("+ Octave").align_(\center)
					.fixedSize_(70 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({d.fOctaveUp(\midiPlayNote)}),
					align: \center],
				nil,
			).spacing_(6),
			[ListView()
				.fixedSize_(220 @ 100)
				.items_((24..128).collect({arg note;
					var octText = ((note div: 12) - 2).asString;
					var noteText = ["C", "C#", "D", "D#", "E", "F", "F#",
						"G","G#", "A", "A#", "B"].at(note % 12)
					++ octText ++ ", freq: "++ note.midicps.round(0.01)
					++ ", midi note: "++ note.asString;
					noteText;
				}))
				.stringColor_(Color.black).background_(d.colLabel)
				.value_(d.midiPlayNote - 24)
				.action_({arg view;
					d.midiPlayNote = view.value + 24;
					d.fBuildArrFreqs;
					d.rebuildWindow;
			}), align: \top],
		).spacing_(2);
	};
	// end of d.makeTestNoteRow

	d.makeSelectionInfoRow = {
		// Selection info text
		if (d.selectionBox.isNil, {
			d.guiData.selectionInfoView = StaticText()
			.string_(" No Selection: Drag on image to select region.")
			.fixedSize_(350 @ 22)
			.background_(d.colHighlight).stringColor_(Color.black);
		}, {
			d.guiData.selectionLeftView = NumberBox().maxDecimals_(0).fixedSize_(40 @ 22)
			.value_(d.selectionBox.left)
			.action_({arg view;
				view.value = ControlSpec(0, d.imageWidth - 1, step: 1).constrain(view.value);
				d.selectionBox.left = view.value;
				d.fClipSelectionBox;
				d.rebuildWindow;
			});
			d.guiData.selectionTopView = NumberBox().maxDecimals_(0).fixedSize_(40 @ 22)
			.value_(d.selectionBox.top)
			.action_({arg view;
				view.value = ControlSpec(0, d.imageHeight - 1, step: 1).constrain(view.value);
				d.selectionBox.top = view.value;
				d.fClipSelectionBox;
				d.rebuildWindow;
			});
			d.guiData.selectionWidthView = NumberBox().maxDecimals_(0).fixedSize_(40 @ 22)
			.value_(d.selectionBox.width)
			.action_({arg view;
				view.value = ControlSpec(1, d.imageWidth, step: 1).constrain(view.value);
				d.selectionBox.width = view.value;
				d.fClipSelectionBox;
				d.rebuildWindow;
			});
			d.guiData.selectionHeightView = NumberBox().maxDecimals_(0).fixedSize_(40 @ 22)
			.value_(d.selectionBox.height)
			.action_({arg view;
				view.value = ControlSpec(1, d.imageHeight, step: 1).constrain(view.value);
				d.selectionBox.height = view.value;
				d.fClipSelectionBox;
				d.rebuildWindow;
			});
			d.guiData.selectionInfoView = HLayout(
				StaticText()
				.string_(" Selection:").align_(\center).fixedSize_(60 @ 22)
				.background_(d.colHighlight).stringColor_(Color.black),
				// left position
				StaticText().string_("From Left").align_(\center).fixedSize_(60 @ 22)
				.background_(d.colHighlight).stringColor_(Color.black),
				d.guiData.selectionLeftView,
				// top position
				StaticText().string_("From Top").align_(\center).fixedSize_(60 @ 22)
				.background_(d.colHighlight).stringColor_(Color.black),
				d.guiData.selectionTopView,
				// width
				StaticText().string_("Width").align_(\center).fixedSize_(50 @ 22)
				.background_(d.colHighlight).stringColor_(Color.black),
				d.guiData.selectionWidthView,
				// height
				StaticText().string_("Height").align_(\center).fixedSize_(50 @ 22)
				.background_(d.colHighlight).stringColor_(Color.black),
				d.guiData.selectionHeightView,
			).spacing_(2);
		});
		d.guiData.selectionInfoRow = HLayout(
			d.guiData.selectionInfoView,
			4,
			StaticText().string_("Select All").align_(\center)
			.fixedSize_(70 @ 22)
			.stringColor_(Color.white).background_(d.colButton)
			.mouseDownAction_({
				d.selectionBox = Rect(0, 0, d.imageWidth, d.imageHeight);
				d.rebuildWindow;
				d.fUpdateSelectionInfo;
			}),
			4,
			StaticText().string_("Maximum Width").align_(\center)
			.fixedSize_(110 @ 22)
			.stringColor_(Color.white).background_(d.colButton)
			.mouseDownAction_({
				if (d.selectionBox.notNil, {
					d.selectionBox = Rect(0, d.selectionBox.top, d.imageWidth, d.selectionBox.height);
					d.rebuildWindow;
					d.fUpdateSelectionInfo;
				});
			}),
			4,
			StaticText().string_("Maximum Height").align_(\center)
			.fixedSize_(110 @ 22)
			.stringColor_(Color.white).background_(d.colButton)
			.mouseDownAction_({
				if (d.selectionBox.notNil, {
					d.selectionBox = Rect(d.selectionBox.left, 0, d.selectionBox.width, d.imageHeight);
					d.rebuildWindow;
					d.fUpdateSelectionInfo;
				});
			}),
			nil,
		);
	};// end of d.makeSelectionInfoRow

	d.makeSelectionShiftRow = {
		d.guiData.selectionShiftRow = HLayout(
			// shift buttons
			StaticText().string_("Shift Selection").align_(\center)
			.fixedSize_(90 @ 22)
			.stringColor_(d.colLabelString).background_(d.colLabel),
			StaticText().string_("< Left").align_(\center)
			.fixedSize_(50 @ 22)
			.stringColor_(Color.white).background_(d.colButton.blend(Color.grey(0.5), 0.5))
			.mouseDownAction_({
				d.fMoveSelectionBox(-1, 0);
				d.guiData.sonogramView.refresh;
			}),
			StaticText().string_("> Right").align_(\center)
			.fixedSize_(50 @ 22)
			.stringColor_(Color.white).background_(d.colButton.blend(Color.grey(0.5), 0.5))
			.mouseDownAction_({
				d.fMoveSelectionBox(1, 0);
				d.guiData.sonogramView.refresh;
			}),
			StaticText().string_("^ Up").align_(\center)
			.fixedSize_(50 @ 22)
			.stringColor_(Color.white).background_(d.colButton.blend(Color.grey(0.5), 0.5))
			.mouseDownAction_({
				d.fMoveSelectionBox(0, -1);
				d.guiData.sonogramView.refresh;
			}),
			StaticText().string_("v Down").align_(\center)
			.fixedSize_(50 @ 22)
			.stringColor_(Color.white).background_(d.colButton.blend(Color.grey(0.5), 0.5))
			.mouseDownAction_({
				d.fMoveSelectionBox(0, 1);
				d.guiData.sonogramView.refresh;
			}),
			StaticText().string_("<< Time Div").align_(\center)
			.fixedSize_(80 @ 22)
			.stringColor_(Color.white).background_(d.colButton.blend(Color.grey(0.5), 0.5))
			.mouseDownAction_({
				var jump = d.imageWidth div: d.timeGridSteps;
				d.fMoveSelectionBox(jump.neg, 0);
				d.guiData.sonogramView.refresh;
			}),
			StaticText().string_(">> Time Div").align_(\center)
			.fixedSize_(80 @ 22)
			.stringColor_(Color.white).background_(d.colButton.blend(Color.grey(0.5), 0.5))
			.mouseDownAction_({
				var jump = d.imageWidth div: d.timeGridSteps;
				d.fMoveSelectionBox(jump, 0);
				d.guiData.sonogramView.refresh;
			}),
		).spacing_(10);
		// if showing octaves
		if (d.freqMode.asString.keep(4) == "midi", {
			d.guiData.selectionShiftRow.add(
				StaticText().string_("^^ Octave").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton.blend(Color.grey(0.5), 0.5))
				.mouseDownAction_({
					var oct;
					if (d.freqMode == 'midiScale', {
						oct = d.allScales[d.midiScale].size * (d.detunedCopies + 1);
					}, {
						oct = d.midiPitchesPerOct * (d.detunedCopies + 1);
					});
					d.fMoveSelectionBox(0, oct.neg);
					d.guiData.sonogramView.refresh;
			}));
			d.guiData.selectionShiftRow.add(
				StaticText().string_("vv Octave").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton.blend(Color.grey(0.5), 0.5))
				.mouseDownAction_({
					var oct;
					if (d.freqMode == 'midiScale', {
						oct = d.allScales[d.midiScale].size * (d.detunedCopies + 1);
					}, {
						oct = d.midiPitchesPerOct * (d.detunedCopies + 1);
					});
					d.fMoveSelectionBox(0, oct);
					d.guiData.sonogramView.refresh;
			}));
		});
		d.guiData.selectionShiftRow.add(nil);
	};// end of d.makeSelectionShiftRow

	d.makeSonogramRow = {arg event, usePixelHeight = true, showSelectionBars = false;
		var pixHeight;
		if (usePixelHeight, {
			pixHeight = d.pixelHeight;
		}, {
			pixHeight = 1;
		});
		// timeline
		d.guiData.timelineStringView = StaticText()
		.fixedSize_((d.imageWidth * d.pixelWidth).max(960) @ 20)
		.background_(d.colButton.blend(Color.white, 0.9)).stringColor_(d.colLabelString);
		d.fUpdateTimeInfo;  // run function now
		d.guiData.timelineView = UserView(d.guiData.timelineStringView).background_(Color.clear)
		.fixedSize_((d.imageWidth * d.pixelWidth) @ 20)
		.drawFunc_({arg view;
			Pen.use{
				// draw timeline
				Pen.color_(Color.red);
				Pen.line((d.playPosition * d.pixelWidth) @ 0,
					((d.playPosition * d.pixelWidth) @ view.bounds.height));
				Pen.line((d.playPosition * d.pixelWidth + 1) @ 0,
					((d.playPosition * d.pixelWidth + 1) @ view.bounds.height));
				Pen.stroke;
				Pen.color_(Color.gray);
				Pen.line((d.imageWidth * d.pixelWidth) @ 0,
					((d.imageWidth * d.pixelWidth) @ view.bounds.height));
				Pen.stroke;
			};
		})
		.mouseDownAction_({arg view, x, y, mod;
			d.playPosition = x.clip(0, view.bounds.width - 1) div: d.pixelWidth;
			view.refresh;
		})
		.mouseMoveAction_({arg view, x, y, mod;
			d.playPosition = x.clip(0, view.bounds.width - 1) div: d.pixelWidth;
			view.refresh;
		});
		// sonogram
		// d.guiData.sonogramScrollView = ScrollView(w)
		// .fixedSize_((d.imageWidth * d.pixelWidth + 20).min(1020) @ (d.imageHeight * pixHeight + 20).min(300))
		// .hasBorder_(true);
		// d.guiData.sonogramView = UserView(parent: d.guiData.sonogramScrollView).background_(Color.white)
		d.guiData.sonogramView = UserView().background_(Color.white)
		.fixedSize_((d.imageWidth * d.pixelWidth) @ (d.imageHeight * pixHeight))
		.drawFunc_({arg view;
			Pen.use {
				Pen.smoothing_(false);
				d.arrImages[d.imageIndex].smooth = false;
				Pen.drawImage(Rect(0, 0, d.imageWidth * d.pixelWidth, d.imageHeight * pixHeight),
					d.arrImages[d.imageIndex], operation: 'sourceOver', opacity:1);
			};
		});
		if (showSelectionBars, {
			d.guiData.selectionBarLeft = UserView().background_(Color.grey(0.4))
			.fixedSize_(4 @ (d.imageHeight * pixHeight))
			.drawFunc_({arg view;
				if (d.selectionBox.notNil, {
					Pen.color = Color.white;
					Pen.addRect (Rect(0, d.selectionBox.top * pixHeight, 4, d.selectionBox.height * pixHeight));
					Pen.fill;
				});
			});
			d.guiData.selectionBarBottom = UserView().background_(Color.grey(0.4))
			.fixedSize_((d.imageWidth * d.pixelWidth) @ 4)
			.drawFunc_({arg view;
				if (d.selectionBox.notNil, {
					Pen.color = Color.white;
					Pen.addRect (Rect(d.selectionBox.left * d.pixelWidth, 0, d.selectionBox.width * d.pixelWidth, 4));
					Pen.fill;
				});
			});
			d.guiData.sonogramRow = HLayout(  // Row of controls
				VLayout(
					HLayout(
						View().fixedSize_(4 @ 22),
						d.guiData.timelineStringView,
						nil
					).spacing_(2),
					// HLayout(d.guiData.selectionBarLeft, d.guiData.sonogramScrollView),
					HLayout(
						d.guiData.selectionBarLeft,
						d.guiData.sonogramView,
						nil
					).spacing_(2),
					HLayout(
						View().fixedSize_(4 @ 4),
						d.guiData.selectionBarBottom,
						nil
					).spacing_(2),
				).spacing_(2),
				nil
			);
		}, {
			// without selection bars
			d.guiData.sonogramRow = HLayout(  // Row of controls
				VLayout(
					d.guiData.timelineStringView,
					// d.guiData.sonogramScrollView,
					d.guiData.sonogramView,
				),
				nil
			);
		});
	};
	// end of d.makeSonogramRow
	d.makeTimeGridRow = {
		d.guiData.timeGridRow = HLayout(
			// showTimeGrid checkbox
			Button().states_([
				["[ ] Show Time Grid", d.colButton, Color.white],
				["[X] Show Time Grid", Color.white, d.colButton]])
			.fixedSize_(116 @ 22)
			.action_({arg view;
				d.showTimeGrid = view.value.asBoolean;
				d.rebuildWindow;
			})
			.value_(d.showTimeGrid.binaryValue),
		);
		d.guiData.timeGridRow.add(20);  // spacer
		d.guiData.timeGridRow.add(
			HLayout(
				// label
				StaticText().string_("Time Divisions").align_(\center)
				.fixedSize_(84 @ 22)
				.stringColor_(d.colLabelString).background_(d.colLabel),
				// numbox
				NumberBox().maxDecimals_(2)
				.fixedSize_(30 @ 22)
				.action_({arg view;
					view.value = d.timeGridStepsSpec.constrain(view.value);
					d.timeGridSteps = view.value.asInteger;
					d.rebuildWindow;
				})
				.value_(d.timeGridSteps),
			).spacing_(2),
		);
		if (d.displayTab == \imageTools and: {d.guiOptions.showSnapToTimeGrid == true}, {
			d.guiData.timeGridRow.add(20);  // spacer
			d.guiData.timeGridRow.add(
				// snapToTimeGrid checkbox
				Button().states_([
					["[ ] Snap To Time Grid", d.colButton, Color.white],
					["[X] Snap To Time Grid", Color.white, d.colButton]])
				.fixedSize_(128 @ 22)
				.action_({arg view;
					d.snapToTimeGrid = view.value.asBoolean;
				})
				.value_(d.snapToTimeGrid.binaryValue),
			);
		});
		d.guiData.timeGridRow.add(nil);  // end spacer
	};
	d.makeToolRepeatsLayout = {arg event, mode; // mode: 'repeatsH' or 'repeatsV'
		var repeatsCountView, spacingView;
		if (mode == 'repeatsH', {
			repeatsCountView = d.fEZNumBox(ControlSpec(1, 99, step: 1), 'repeatsCountH', "H Repeats", 80);
			spacingView = d.fEZNumBox(ControlSpec(-1000, 1000, step: 1), 'repeatsSpacingH', "H Spacing", 80);
		}, {
			repeatsCountView = d.fEZNumBox(ControlSpec(1, 99, step: 1), 'repeatsCountV', "V Repeats", 80);
			spacingView = d.fEZNumBox(ControlSpec(-100, 100, step: 1), 'repeatsSpacingV', "V Spacing", 80);
		});
		d.guiData.toolRepeatsLayout = VLayout(
			HLayout(
				repeatsCountView,
				10,
				spacingView,
				nil,
			),
			d.fEZSlider(ControlSpec(0, 1), 'repeatsDissolve', "Dissolving", 140, 80),
		);
		if (d.toolMode != 'selectDragBox', {
			d.guiData.toolRepeatsLayout.add(d.fEZSlider(ControlSpec(0, 1), 'repeatsDarken', "Darkening", 140, 80));
		});
		d.guiData.toolRepeatsLayout.add(nil);
	};
	// end of d.makeToolRepeatsLayout
	d.makePixelSizeRow = {
		d.pixelSizeRow =  HLayout(
			// Pixel Height
			[PopUpMenu()
				.fixedSize_(110 @ 22)
				.items_((1..4).collect({arg item; "Pixel Height: " + item.asString}))
				.stringColor_(Color.black).background_(d.colLabel)
				.value_(d.pixelHeight - 1)
				.action_({arg view;
					d.pixelHeight = view.value + 1;
					d.fResetWindowSize;
					d.rebuildWindow;
			}), align: \centre],
			4,
			// Pixel Width
			[PopUpMenu()
				.fixedSize_(110 @ 22)
				.items_((1..4).collect({arg item; "Pixel Width: " + item.asString}))
				.stringColor_(Color.black).background_(d.colLabel)
				.value_(d.pixelWidth - 1)
				.action_({arg view;
					d.pixelWidth = view.value + 1;
					d.fResetWindowSize;
					d.rebuildWindow;
			}), align: \centre],
		);
	};
	// end of d.makePixelSizeRow
	d.makeFilterScaleRow = {
		var validScaleKeys = [];
		var validTuningKeys = [];
		if (d.pitchesPerOctave != 12 or: {d.freqMode == 'midiScale' and: {d.midiScale != 'chromatic'}}, {
			d.guiData.filterScaleRow = HLayout (
				// filterScaleRoot label
				StaticText().string_(
					" Controls are hidden - Scale Filter only works with 12-semitone Chromatic MIDI scale - see Settings window."
				).align_(\left)
				.fixedSize_(600 @ 22)
				.stringColor_(d.colLabelString).background_(d.colHighlight),
				nil,
			);
		}, {
			// scale
			d.allScales.keysValuesDo({arg key, scale;
				if (scale.pitchesPerOctave == d.pitchesPerOctave, {
					validScaleKeys = validScaleKeys.add(key);
				});
			});
			validScaleKeys.sort;
			d.filterScaleOptions = validScaleKeys.collect({arg key;
				var scale = d.allScales.at(key);
				[scale.name ++ ", " + scale.size ++ "/" ++ scale.pitchesPerOctave + "PPO", key]
			});
			d.guiData.filterScaleRow = VLayout (
				HLayout (
					// filterScaleRoot label
					[StaticText().string_("Root Note").align_(\center)
						.fixedSize_(74 @ 22)
						.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
					// filterScaleRoot ListView
					[ListView()
						.fixedSize_(40 @ 150)
						.items_(["C", "C#", "D", "D#", "E", "F", "F#", "G","G#", "A", "A#", "B"])
						.stringColor_(Color.black).background_(d.colLabel)
						.value_(d.filterScaleRoot)
						.action_({arg view;
							d.filterScaleRoot = view.value;
						}),
						align: \top],
					20,
					// filterScale label
					[StaticText().string_("Scale").align_(\center)
						.fixedSize_(80 @ 22)
						.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
					// filterScale ListView
					[ListView()
						.fixedSize_(300 @ 150)
						.items_(d.filterScaleOptions.flop.slice(0))
						.stringColor_(Color.black).background_(d.colLabel)
						.value_(d.filterScaleOptions.flop.slice(1).indexOfEqual(d.filterScale))
						.action_({arg view;
							d.filterScale = d.filterScaleOptions.flop.slice(1)[view.value];
						}),
						align: \top],
					nil,
				),
				// filterScaleInvert checkbox
				HLayout (
					// apply scale filter
					StaticText().string_("Apply Scale Filter").align_(\center)
					.fixedSize_(120 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({
						d.fApplyScaleFilter;
						d.guiData.sonogramView.refresh;
					}),
					20,
					Button().states_([
						["[ ] Invert Scale - Scale freqs will be removed, not kept", d.colButton, Color.white],
						["[X] Invert Scale - Scale freqs will be removed, not kept", Color.white, d.colButton]])
					.fixedSize_(300 @ 24)
					.action_({arg view;
						var val = view.value.asBoolean;
						d.filterScaleInvert = val;
					})
					.value_(d.filterScaleInvert.binaryValue),
					nil,
				),
				nil,
			);
		});
	}; // end of d.makeFilterScaleRow
	d.makeImageToolsLayout = {
		// Choose optional views
		d.guiOptions.showAnalysisProperties = false;
		d.guiOptions.showBlurProperties = false;
		d.guiOptions.showColorizeMode = false;
		d.guiOptions.showCompressionProperties = false;
		d.guiOptions.showDrawCol1 = false;
		d.guiOptions.showDrawCol2 = false;
		d.guiOptions.showFadeMode = false;
		d.guiOptions.showFillMode = false;
		d.guiOptions.showLineMode = false;
		d.guiOptions.showPaintMode = false;
		d.guiOptions.showPaintLineMode = false;
		d.guiOptions.showPerlinProperties = false;
		d.guiOptions.showScaleFilterProperties = false;
		d.guiOptions.showSelectionBox = false;
		d.guiOptions.showSelectProperties = false;
		d.guiOptions.showSnapToTimeGrid = false;
		d.guiOptions.showSprayProperties = false;
		d.guiOptions.showSprayRadius = false;
		d.guiOptions.showToolHeightProperties = false;
		d.guiOptions.showToolRotationProperties = false;
		d.guiOptions.showToolWidthProperties = false;
		d.guiOptions.showTriangleMode = false;
		case
		{d.toolMode == 'blurWholeImage'} {
			d.guiOptions.showBlurProperties = true;
		}
		{d.toolMode == 'blurDragBox'} {
			d.guiOptions.showBlurProperties = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'colorizeDragBox'} {
			d.guiOptions.showColorizeMode = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'compressionDragBox'} {
			d.guiOptions.showSelectionBox = true;
			d.guiOptions.showCompressionProperties = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'dragDrawBox'} {
			d.guiOptions.showDrawCol1 = true;
			d.guiOptions.showFillMode = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'dragDrawOval'} {
			d.guiOptions.showDrawCol1 = true;
			d.guiOptions.showFillMode = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'dragDrawLine'} {
			d.guiOptions.showDrawCol1 = true;
			d.guiOptions.showLineMode = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'dragDrawTriangle'} {
			d.guiOptions.showDrawCol1 = true;
			d.guiOptions.showFillMode = true;
			d.guiOptions.showTriangleMode = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'dragDrawHorizBar'} {
			d.guiOptions.showDrawCol1 = true;
			d.guiOptions.showFillMode = true;
		}
		{d.toolMode == 'dragDrawVertBar'} {
			d.guiOptions.showDrawCol1 = true;
			d.guiOptions.showFillMode = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'paintBoxes'} {
			d.guiOptions.showDrawCol1 = true;
			d.guiOptions.showFillMode = true;
			d.guiOptions.showPaintMode = true;
			d.guiOptions.showToolWidthProperties = true;
			d.guiOptions.showToolHeightProperties = true;
			d.guiOptions.showToolRotationProperties = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'paintOvals'} {
			d.guiOptions.showDrawCol1 = true;
			d.guiOptions.showFillMode = true;
			d.guiOptions.showPaintMode = true;
			d.guiOptions.showToolWidthProperties = true;
			d.guiOptions.showToolHeightProperties = true;
			d.guiOptions.showToolRotationProperties = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'paintTriangles'} {
			d.guiOptions.showDrawCol1 = true;
			d.guiOptions.showFillMode = true;
			d.guiOptions.showPaintMode = true;
			d.guiOptions.showToolWidthProperties = true;
			d.guiOptions.showToolHeightProperties = true;
			d.guiOptions.showToolRotationProperties = true;
			d.guiOptions.showTriangleMode = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'paintLines'} {
			d.guiOptions.showDrawCol1 = true;
			d.guiOptions.showPaintMode = true;
			d.guiOptions.showPaintLineMode = true;
			d.guiOptions.showToolWidthProperties = true;
			d.guiOptions.showToolRotationProperties = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'paintSpray'} {
			d.guiOptions.showDrawCol1 = true;
			d.guiOptions.showPaintMode = true;
			d.guiOptions.showSprayProperties = true;
			d.guiOptions.showSnapToTimeGrid = true;
			if (d.sprayMode.asString.keep(3) == "box", {
				d.guiOptions.showToolWidthProperties = true;
				d.guiOptions.showToolHeightProperties = true;
			}, {
				d.guiOptions.showSprayRadius = true;
			});
		}
		{d.toolMode == 'perlinNoiseDragBox'} {
			d.guiOptions.showSelectionBox = true;
			d.guiOptions.showPerlinProperties = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'scaleFilterDragBox'} {
			d.guiOptions.showSelectionBox = true;
			d.guiOptions.showScaleFilterProperties = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'selectDragBox'} {
			d.guiOptions.showSelectionBox = true;
			d.guiOptions.showSelectProperties = true;
			d.guiOptions.showSnapToTimeGrid = true;
		}
		{d.toolMode == 'analysis'} {
			d.guiOptions.showAnalysisProperties = true;
		};
		// End of case
		// prepare views
		d.makeSonogramRow(true, true);  // true - show selection bars
		d.makeImageSelectRow;
		d.makePlayRow;
		d.makeSnapshotsRow;
		d.makePixelSizeRow;
		d.makeTimeGridRow;
		// put edit view on top of sonogram
		d.guiData.sonogramEditView = UserView(parent: d.guiData.sonogramView).background_(Color.clear)
		.fixedSize_((d.imageWidth * d.pixelWidth) @ (d.imageHeight * d.pixelHeight))
		.drawFunc_({arg view;
			Pen.use{
				Pen.smoothing_(false);
				Pen.scale(d.pixelWidth, d.pixelHeight);
				// draw grids
				if (d.pitchesPerOctave.notNil and: d.showOctaves, {
					var spacing, numLines;
					if (d.freqMode == 'midiScale', {
						spacing = d.allScales[d.midiScale].size * (1 + d.detunedCopies);
					}, {
						spacing = d.pitchesPerOctave * (1 + d.detunedCopies);
					});
					numLines = d.imageHeight div: spacing;
					Pen.color = Color(0.5, 0.3, 1, 1);
					(numLines + 1).do({arg i;
						var y = d.imageHeight - (i * spacing) - d.pixelHeight.reciprocal;
						Pen.color = Color(1, 1, 1, 0.3);
						Pen.line(Point(0, y), Point(d.imageWidth, y));
						Pen.stroke;
						Pen.color = Color(0, 0, 0, 0.3);
						Pen.line(Point(0, y+1), Point(d.imageWidth, y+1));
						Pen.line(Point(0, y-1), Point(d.imageWidth, y-1));
						Pen.stroke;
					});
					Pen.stroke;
				});
				if ((d.freqMode == 'harm' or: {d.freqMode == 'harmEven'}) and: d.showOctaves, {
					Pen.color = Color(0.5, 0.3, 1, 1);
					d.imageHeight.do({arg row;
						var numVoices = d.detunedCopies + 1;
						var colInd = row div: numVoices;
						var isOct = false;
						var y;
						if (d.freqMode == 'harm' and: {(colInd + 1).isPowerOfTwo}, {isOct = true});
						if (d.freqMode == 'harmEven' and: {(colInd.max(1) * 2).isPowerOfTwo}, {isOct = true});
						if (isOct and: {(row % numVoices) == 0}, {
							y = d.imageHeight - row - d.pixelHeight.reciprocal;
							Pen.color = Color(1, 1, 1, 0.3);
							Pen.line(Point(0, y), Point(d.imageWidth, y));
							Pen.stroke;
							Pen.color = Color(0, 0, 0, 0.3);
							Pen.line(Point(0, y+1), Point(d.imageWidth, y+1));
							Pen.line(Point(0, y-1), Point(d.imageWidth, y-1));
							Pen.stroke;
						});
					});
				});
				if (d.showTimeGrid, {
					var spacing = d.imageWidth / d.timeGridSteps;
					(d.timeGridSteps + 1).do({arg i;
						var x = i * spacing;
						Pen.color = Color(1, 1, 1, 0.3);
						Pen.line(Point(x, 0), Point(x, d.imageHeight));
						Pen.stroke;
						Pen.color = Color(0, 0, 0, 0.3);
						Pen.line(Point(x+1, 0), Point(x+1, d.imageHeight));
						Pen.line(Point(x-1, 0), Point(x-1, d.imageHeight));
						Pen.stroke;
					});
				});
				// draw dragged shapes
				if (d.isDragDraw or: d.isDragBlur or: d.isDragColorize or: d.guiOptions.showSelectionBox, {
					d.fDrawShape(true);  // true - shows outline if needed
				});
				// reset scale
				Pen.scale(1, 1);
				/*
				// draw mouse point
				*/
				if (d.drawPoints.actualMousePoint.notNil, {
					2.do({arg i;
						var b = [0, 1].asFloat[i];
						var h = [6, 8][i];
						var x = d.drawPoints.actualMousePoint.x div: d.pixelWidth;
						var y = d.drawPoints.actualMousePoint.y div: d.pixelHeight;
						Pen.color = Color(b, b, b, 1);
						Pen.addOval(Rect(0, 0, h / d.pixelWidth, h /  d.pixelHeight).center_(x @ y));
						Pen.stroke;
					});
				});
			};
		}) // end of drawFunc_
		.mouseDownAction_({arg view, x, y, mod;
			var imageX, imageY;
			d.drawPoints.actualMousePoint = Point(x, y);
			if (d.snapToTimeGrid, {
				x = x.round(view.bounds.width / d.timeGridSteps);
			});
			imageX = x.round(d.pixelWidth) div: d.pixelWidth;
			imageY = y.round(d.pixelHeight) div: d.pixelHeight;
			d.drawPoints.mouseDownPoint = Point(imageX, imageY);
			d.drawPoints.mouseCurrentPoint = d.drawPoints.mouseDownPoint.copy;
			d.isDragDraw = false;
			d.isDragCorner = false;
			d.isDragLeftBottom = false;
			d.isDragLeftTop = false;
			d.isDragRightBottom = false;
			d.isDragRightTop = false;
			d.isDragBlur = false;
			d.isDragColorize = false;
			d.isPainting = false;
			d.flagRebuild = false;
			d.fUpdateToolRandVals;
			case
			{d.toolMode == 'blurDragBox'} { d.isDragBlur = true; }
			{d.toolMode == 'colorizeDragBox'} { d.isDragColorize = true}
			{d.toolMode == 'dragDrawBox'} { d.isDragDraw = true}
			{d.toolMode == 'dragDrawOval'} { d.isDragDraw = true}
			{d.toolMode == 'dragDrawLine'} { d.isDragDraw = true}
			{d.toolMode == 'dragDrawTriangle'} { d.isDragDraw = true}
			{d.toolMode == 'dragDrawHorizBar'} { d.isDragDraw = true}
			{d.toolMode == 'dragDrawVertBar'} { d.isDragDraw = true}
			{d.toolMode == 'paintBoxes'} {
				if (d.paintMode == 'continuous', {d.isPainting = true}, {d.isDragDraw = true})
			}
			{d.toolMode == 'paintOvals'} {
				if (d.paintMode == 'continuous', {d.isPainting = true}, {d.isDragDraw = true})
			}
			{d.toolMode == 'paintTriangles'} {
				if (d.paintMode == 'continuous', {d.isPainting = true}, {d.isDragDraw = true})
			}
			{d.toolMode == 'paintLines'} {
				if (d.paintMode == 'continuous', {d.isPainting = true}, {d.isDragDraw = true})
			}
			{d.toolMode == 'paintSpray'} {
				if (d.paintMode == 'continuous', {d.isPainting = true}, {d.isDragDraw = true})
			}
			{d.guiOptions.showSelectionBox} {
				d.holdSectionBoxIsNil = d.selectionBox.isNil;
				if (d.selectionBox.notNil, {
					case
					{abs(imageX - d.selectionBox.leftBottom.x) < (5 / d.pixelWidth)
						and:(abs(imageY - d.selectionBox.leftBottom.y) < (5 / d.pixelHeight))} {
						d.isDragLeftBottom = true; d.isDragCorner = true}
					{abs(imageX - d.selectionBox.leftTop.x) < (5 / d.pixelWidth)
						and:(abs(imageY - d.selectionBox.leftTop.y) < (5 / d.pixelHeight))} {
						d.isDragLeftTop = true; d.isDragCorner = true}
					{abs(imageX - d.selectionBox.rightBottom.x) < (5 / d.pixelWidth)
						and:(abs(imageY - d.selectionBox.rightBottom.y) < (5 / d.pixelHeight))} {
						d.isDragRightBottom = true; d.isDragCorner = true}
					{abs(imageX - d.selectionBox.rightTop.x) < (5 / d.pixelWidth)
						and:(abs(imageY - d.selectionBox.rightTop.y) < (5 / d.pixelHeight))} {
						d.isDragRightTop = true; d.isDragCorner = true}
				});
			}
			; // end of case
			if (d.guiOptions.showSelectionBox.not or: d.isDragCorner.not, {
				d.selectionBox = nil;
			});
			if (d.isPainting, {
				d.fDrawShapeInImage;
				d.guiData.sonogramView.refresh;
			});
			view.refresh;
			d.fUpdateSelectionInfo;
		})
		.mouseMoveAction_({arg view, x, y, mod;
			d.drawPoints.actualMousePoint = Point(x, y);
			if (d.snapToTimeGrid, {
				x = x.round(view.bounds.width / d.timeGridSteps);
			});
			d.drawPoints.mousePreviousPoint = d.drawPoints.mouseCurrentPoint;
			d.drawPoints.mouseCurrentPoint = Point(x.round(d.pixelWidth) div: d.pixelWidth,
				y.round(d.pixelHeight) div: d.pixelHeight);
			if (d.isPainting and: {d.paintMode == 'continuous'}, {
				d.fUpdateToolRandVals;
				d.fDrawShapeInImage;
				d.guiData.sonogramView.refresh;
			});
			if (d.guiOptions.showSelectionBox, {
				d.fClipCurrentPoint;
				if (d.isDragCorner, {
					case {d.isDragLeftBottom} {
						d.selectionBox = Rect.fromPoints(
							(d.drawPoints.mouseCurrentPoint + (0@1)),
							d.selectionBox.rightTop);
					}
					{d.isDragLeftTop} {
						d.selectionBox = Rect.fromPoints(
							d.drawPoints.mouseCurrentPoint,
							d.selectionBox.rightBottom);
					}
					{d.isDragRightBottom} {
						d.selectionBox = Rect.fromPoints(
							(d.drawPoints.mouseCurrentPoint + (1@1)),
							d.selectionBox.leftTop);
					}
					{d.isDragRightTop} {
						d.selectionBox = Rect.fromPoints(
							(d.drawPoints.mouseCurrentPoint + (1@0)),
							d.selectionBox.leftBottom);
					};
				}, {
					d.selectionBox = Rect.fromPoints(d.drawPoints.mouseDownPoint, d.drawPoints.mouseCurrentPoint);
					d.selectionBox = d.selectionBox.resizeBy(1, 1);
				});
				d.fUpdateSelectionInfo;
			});
			view.refresh;
		})
		.mouseUpAction_({arg view, x, y, mod;
			if (d.snapToTimeGrid, {
				x = x.round(view.bounds.width / d.timeGridSteps);
			});
			d.drawPoints.mouseCurrentPoint = Point(x.round(d.pixelWidth) div: d.pixelWidth,
				y.round(d.pixelHeight) div: d.pixelHeight);
			if (d.guiOptions.showSelectionBox, {
				d.fClipCurrentPoint;
			});
			if (d.isDragCorner.not, {
				d.fMakeSelectionBox;
			});
			d.fValidateSelectionBox;
			d.fUpdateSelectionInfo;
			if (d.holdSectionBoxIsNil != d.selectionBox.isNil, {
				d.flagRebuild = true;
			});
			if (d.isDragDraw, {
				d.fDrawShapeInImage;
				d.guiData.sonogramView.refresh;
				d.isDragDraw = false;
			});
			if (d.isDragBlur, {
				d.fApplyBoxBlur;
				d.guiData.sonogramView.refresh;
				d.isDragBlur = false;
			});
			if (d.isDragColorize, {
				d.fApplyDragColorize;
				d.guiData.sonogramView.refresh;
				d.isDragColorize = false;
			});
			view.refresh;
			// reset
			d.isDragCorner = false;
			d.isDragLeftBottom = false;
			d.isDragLeftTop = false;
			d.isDragRightBottom = false;
			d.isDragRightTop = false;
			d.isPainting = false;
			d.drawPoints.actualMousePoint = nil;
			d.drawPoints.mouseDownPoint = nil;
			d.drawPoints.mouseCurrentPoint = nil;
			if (d.flagRebuild, {
				d.rebuildWindow;
			});
		});
		d.guiData.toolModeView = ListView()
		.fixedSize_(170 @ 230)
		.items_(d.toolModeOptions.flop.slice(0))
		.value_(d.toolModeOptions.flop.slice(1).indexOf(d.toolMode))
		.action_({arg view;
			d.toolMode = d.toolModeOptions[view.value][1];
			d.rebuildWindow;
		});
		d.guiData.imageControlsRow = HLayout(  // Row of controls
			d.pixelSizeRow,
			10,
		);
		if (d.freqMode != 'exp' and: {d.freqMode != 'lin'} and: {d.freqMode != 'harmOdd'}, {
			d.guiData.imageControlsRow.add(
				// showOctaves checkbox
				Button().states_([
					["[ ] Show Octaves", d.colButton, Color.white],
					["[X] Show Octaves", Color.white, d.colButton]])
				.fixedSize_(104 @ 22)
				.action_({arg view;
					d.showOctaves = view.value.asBoolean;
					d.guiData.sonogramEditView.refresh;
				})
				.value_(d.showOctaves.binaryValue)
			);
			d.guiData.imageControlsRow.add(10);  // spacer
		});
		d.guiData.imageControlsRow.add(d.guiData.timeGridRow);
		d.guiData.toolPropertiesLayout = VLayout(
			// // label
			// StaticText().string_("Properties").align_(\center)
			// .font_(d.guiData.titleFont)
			// .fixedSize_(220 @ 22)
			// .stringColor_(d.colLabelString).background_(d.colLabel),
			// 5, // spacer
			d.guiData.imageControlsRow,
			8, // spacer
		);

		// add showFadeMode if needed
		if (d.guiOptions.showFillMode and: {d.fillMode.asString.keep(-4) == "Fade"}, {
			d.guiOptions.showFadeMode = true;
			// add showDrawCol2 if needed
			if (d.fadeMode == 'crossFade', {
				d.guiOptions.showDrawCol2 = true;
			});
		});

		// add optional tool views
		if (d.guiOptions.showDrawCol1, {
			// d.guiData.toolPropertiesLayout.add(4);
			d.guiData.toolPropertiesLayout.add(HLayout(
				d.fEZColor('drawColor1', "Color 1"),
				nil
			));
		});
		if (d.guiOptions.showDrawCol2, {
			d.guiData.toolPropertiesLayout.add(HLayout(
				[d.fEZColor('drawColor2', "Color 2"),align: \top],
				[StaticText().string_("Swap Colors").align_(\center)
					.fixedSize_(80 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({arg view;
						var colorTemp = d.drawColor1.deepCopy;
						d.drawColor1 = d.drawColor2.deepCopy;
						d.drawColor2 = colorTemp.deepCopy;
						d.rebuildWindow;
					}),
					align: \top
				],
				nil,
			));
		});
		if (d.guiOptions.showFillMode, {
			var holdLayout = HLayout(
				// Fill Mode
				[StaticText().string_("Fill Mode").align_(\center)
					.fixedSize_(80 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				[ListView()
					.fixedSize_(280 @ (10 + (d.fillModeOptions.size * 16).min(80)))
					.items_(d.fillModeOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.fillModeOptions.flop.slice(1).indexOfEqual(d.fillMode))
					.action_({arg view;
						d.fillMode = d.fillModeOptions.flop.slice(1)[view.value];
						d.rebuildWindow;
				}), align: \top]
			);
			if (d.guiOptions.showFadeMode, {
				holdLayout.add(10);
				holdLayout.add(
					// Fade Mode
					StaticText().string_("Fade Mode").align_(\center)
					.fixedSize_(80 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel),
					align: \top
				);
				holdLayout.add(
					ListView()
					.fixedSize_(200 @ (10 + (d.fadeModeOptions.size * 16).min(80)))
					.items_(d.fadeModeOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.fadeModeOptions.flop.slice(1).indexOfEqual(d.fadeMode))
					.action_({arg view;
						d.fadeMode = d.fadeModeOptions.flop.slice(1)[view.value];
						d.rebuildWindow;
					}),
					align: \top
				);
			});
			holdLayout.add(nil);
			d.guiData.toolPropertiesLayout.add(4);
			d.guiData.toolPropertiesLayout.add(holdLayout);
		});
		if (d.guiOptions.showTriangleMode, {
			d.guiData.toolTriangleModeLayout = HLayout(
				// Triangle Mode
				[StaticText().string_("Triangle Mode").align_(\center)
					.fixedSize_(80 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				[ListView()
					.fixedSize_(210 @ ((d.triangleModeOptions.size * 16).min(60)))
					.items_(d.triangleModeOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.triangleModeOptions.flop.slice(1).indexOfEqual(d.triangleMode))
					.action_({arg view;
						d.triangleMode = d.triangleModeOptions.flop.slice(1)[view.value];
				}), align: \top],
				nil,
			);
		});
		if (d.guiOptions.showPaintMode, {
			d.guiData.toolPaintModeLayout = HLayout(
				[StaticText().string_("Paint Mode").align_(\center)
					.fixedSize_(80 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				[ListView()
					.fixedSize_(270 @ ((d.paintModeOptions.size * 16).min(70)))
					.items_(d.paintModeOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.paintModeOptions.flop.slice(1).indexOfEqual(d.paintMode))
					.action_({arg view;
						d.paintMode = d.paintModeOptions.flop.slice(1)[view.value];
						d.rebuildWindow;
				}), align: \top],
			);
			if (d.paintMode == 'repeatsH' or: {d.paintMode == 'repeatsV'}, {
				d.makeToolRepeatsLayout(d.paintMode);
				d.guiData.toolPaintModeLayout.add(10);
				d.guiData.toolPaintModeLayout.add(d.guiData.toolRepeatsLayout);
			});
			if (d.guiOptions.showTriangleMode, {
				d.guiData.toolPaintModeLayout.add(10);
				d.guiData.toolPaintModeLayout.add(d.guiData.toolTriangleModeLayout);
			});
			d.guiData.toolPaintModeLayout.add(nil);
			d.guiData.toolPropertiesLayout.add(d.guiData.toolPaintModeLayout);
		});
		if (d.guiOptions.showSprayProperties, {
			d.guiData.toolPropertiesLayout.add(4);
			d.guiData.toolPropertiesLayout.add(HLayout(
				// Spray Mode
				[StaticText().string_("Spray Mode").align_(\center)
					.fixedSize_(90 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				[ListView()
					.fixedSize_(240 @ (10 + (d.sprayModeOptions.size * 16).min(80)))
					.items_(d.sprayModeOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.sprayModeOptions.flop.slice(1).indexOfEqual(d.sprayMode))
					.action_({arg view;
						d.sprayMode = d.sprayModeOptions.flop.slice(1)[view.value];
						d.rebuildWindow;
				}), align: \top],
				6,
				[d.fEZSlider(d.sprayDensitySpec, 'sprayDensity', "Spray Density", 300), align: \top],
				nil,
			));
		});
		if (d.guiOptions.showSprayRadius, {
			d.guiData.toolPropertiesLayout.add(HLayout(
				[d.fEZSlider(d.sprayRadiusSpec, 'sprayRadius', "Spray Radius", 300), align: \top],
				nil,
			));
		});
		if (d.guiOptions.showToolWidthProperties, {
			d.guiData.toolPropertiesLayout.add(4);
			// width and height
			d.guiData.toolPropertiesLayout.add(HLayout(
				d.fEZSlider(ControlSpec(1, d.maxToolSize, warp: 2, step: 1),
					'toolWidth', "Tool Width", 300),
				4,
				d.fEZSlider(d.toolRandSpec, 'toolRandWidthMix', "Rand Width"),
				nil,
			));
			if (d.guiOptions.showToolHeightProperties, {
				d.guiData.toolPropertiesLayout.add(4);
				d.guiData.toolPropertiesLayout.add(HLayout(
					d.fEZSlider(ControlSpec(1, d.maxToolSize, warp: 2, step: 1),
						'toolHeight', "Tool Height", 300),
					4,
					d.fEZSlider(d.toolRandSpec, 'toolRandHeightMix', "Rand Height"),
					4,
					// toolUseWidthForHeight checkbox
					Button().states_([
						["[ ] Use Width for Height", d.colButton, Color.white],
						["[X] Use Width for Height", Color.white, d.colButton]])
					.fixedSize_(140 @ 22)
					.action_({arg view;
						var val = view.value.asBoolean;
						d.toolUseWidthForHeight = val;
					})
					.value_(d.toolUseWidthForHeight.binaryValue),
					nil,
				));
			});
		});
		if (d.guiOptions.showToolRotationProperties, {
			// rotation and skew
			d.guiData.toolPropertiesLayout.add(4);
			d.guiData.toolPropertiesLayout.add(
				HLayout(
					d.fEZSlider(d.toolRotationSpec, 'toolRotation', "Tool Rotation", 300),
					4,
					d.fEZSlider(d.toolRandSpec, 'toolRandRotationMix', "Rand Rotation"),
					nil,
				);
			);
		});
		if (d.guiOptions.showBlurProperties, {
			d.guiData.blurModeRow = HLayout(
				// Blur Mode label
				[StaticText().string_("Blur Mode").align_(\center)
					.fixedSize_(100 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				// Blur Mode popup
				[ListView()
					.fixedSize_(150 @ 80)
					.items_(d.blurModeOptions.flop.slice(0))
					.value_(d.blurModeOptions.flop.slice(1).indexOf(d.blurMode))
					.action_({arg view;
						d.blurMode = d.blurModeOptions[view.value][1];
					}),
					align: \top],
				20,
				// Blur Compositing label
				[StaticText().string_("Blur Compositing").align_(\center)
					.fixedSize_(100 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				// Blur Compositing popup
				[ListView()
					.fixedSize_(150 @ 80)
					.items_(d.blurCompositingOptions.flop.slice(0))
					.value_(d.blurCompositingOptions.flop.slice(1).indexOf(d.blurCompositing))
					.action_({arg view;
						d.blurCompositing = d.blurCompositingOptions[view.value][1];
					}),
					align: \top],
				nil,
			);
			d.guiData.toolPropertiesLayout.add(d.guiData.blurModeRow);
			d.guiData.toolPropertiesLayout.add(8);
			d.guiData.toolPropertiesLayout.add(
				d.fEZSlider(ControlSpec(0.01, 1), 'blurDepth', "Blur Depth", 300).add(nil));
			d.guiData.toolPropertiesLayout.add(8);
			d.guiData.toolPropertiesLayout.add(
				d.fEZSlider(ControlSpec(1, 10, step: 1), 'blurSteps', "Blur Steps", 80).add(nil));
			d.guiData.toolPropertiesLayout.add(8);
			if (d.toolMode == 'blurWholeImage', {
				d.guiData.toolPropertiesLayout.add(
					StaticText().string_("Apply Blur").align_(\center)
					.fixedSize_(90 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({
						d.fApplyWholeImageBlur;
						d.guiData.sonogramView.refresh;
					})
				);
			});
		});
		if (d.guiOptions.showSelectProperties, {
			d.makeSelectionInfoRow;
			d.makeSelectionShiftRow;
			d.guiData.toolPropertiesLayout.add(d.guiData.selectionInfoRow);
			d.guiData.toolPropertiesLayout.add(4);
			d.guiData.toolPropertiesLayout.add(d.guiData.selectionShiftRow);
			d.guiData.toolPropertiesLayout.add(4);
			d.guiData.pasteOptionsRow = HLayout(
				// Paste Scale Mode
				[StaticText().string_("Paste Mode").align_(\center)
					.fixedSize_(80 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				[ListView()
					.fixedSize_(180 @ (2 + (d.pasteModeOptions.size * 14)))
					.items_(d.pasteModeOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.pasteModeOptions.flop.slice(1).indexOfEqual(d.pasteMode))
					.action_({arg view;
						d.pasteMode = d.pasteModeOptions.flop.slice(1)[view.value];
						d.rebuildWindow;
				}), align: \top],
				6,
			);
			if (d.pasteMode != 'colorizeStretchToFit', {
				d.guiData.pasteOptionsRow.add(
					// Repeats Mode
					StaticText().string_("Paste Repeats").align_(\center)
					.fixedSize_(90 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top
				);
				d.guiData.pasteOptionsRow.add(
					ListView()
					.fixedSize_(120 @ (10 + (d.pasteRepeatModeOptions.size * 14).min(80)))
					.items_(d.pasteRepeatModeOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.pasteRepeatModeOptions.flop.slice(1).indexOfEqual(d.pasteRepeatMode))
					.action_({arg view;
						d.pasteRepeatMode = d.pasteRepeatModeOptions.flop.slice(1)[view.value];
						d.rebuildWindow;
					}), align: \top
				);
				if (d.pasteRepeatMode.asString.contains("repeats"), {
					d.makeToolRepeatsLayout(d.pasteRepeatMode);
					d.guiData.pasteOptionsRow.add(6);
					d.guiData.pasteOptionsRow.add(d.guiData.toolRepeatsLayout);
				});
			});
			d.guiData.pasteOptionsRow.add(nil);
			d.guiData.toolPropertiesLayout.add(d.guiData.pasteOptionsRow);
			if (d.pasteMode != 'colorizeStretchToFit', {
				d.guiData.toolPropertiesLayout.add(4);
				d.guiData.toolPropertiesLayout.add(HLayout(
					// Paste Compositing
					[StaticText().string_("Paste Compositing").align_(\center)
						.fixedSize_(110 @ 22)
						.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
					[PopUpMenu()
						.fixedSize_(150 @ (22))
						.items_(d.pasteCompositingOptions.flop.slice(0))
						.stringColor_(Color.black).background_(d.colLabel)
						.value_(d.pasteCompositingOptions.flop.slice(1).indexOfEqual(d.pasteCompositing))
						.action_({arg view;
							d.pasteCompositing = d.pasteCompositingOptions.flop.slice(1)[view.value];
					}), align: \top],
					10,
					[d.fEZSlider(ControlSpec(0,1), 'pasteOpacity', "Paste Opacity", 300), align: \top],
					nil,
				));
			});
			d.guiData.toolPropertiesLayout.add(4);
			// copy cut paste buttons
			d.guiData.toolPropertiesLayout.add(HLayout(
				StaticText().string_("Copy").align_(\center)
				.fixedSize_(60 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.fCopySelection;
					d.guiData.sonogramView.refresh;
				}),
				StaticText().string_("Cut").align_(\center)
				.fixedSize_(60 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.fCutSelection;
					d.guiData.sonogramView.refresh;
				}),
				StaticText().string_("Paste").align_(\center)
				.fixedSize_(60 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.fPasteSelection;
					d.guiData.sonogramView.refresh;
				}),
				StaticText().string_("Invert").align_(\center)
				.fixedSize_(60 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.fInvertSelection;
					d.guiData.sonogramView.refresh;
				}),
				StaticText().string_("Reverse").align_(\center)
				.fixedSize_(60 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.fReverseSelection;
					d.guiData.sonogramView.refresh;
				}),
				nil,
			).spacing_(16));
		});
		if (d.guiOptions.showScaleFilterProperties, {
			d.makeFilterScaleRow;
			d.makeSelectionInfoRow;
			d.makeSelectionShiftRow;
			d.guiData.toolPropertiesLayout.add(d.guiData.selectionInfoRow);
			d.guiData.toolPropertiesLayout.add(4);
			d.guiData.toolPropertiesLayout.add(d.guiData.selectionShiftRow);
			d.guiData.toolPropertiesLayout.add(4);
			d.guiData.toolPropertiesLayout.add(d.guiData.filterScaleRow);
		});
		if (d.guiOptions.showLineMode, {
			d.guiData.toolPropertiesLayout.add(4);
			d.guiData.toolPropertiesLayout.add(HLayout(
				// Line Mode
				[StaticText().string_("Line Mode").align_(\center)
					.fixedSize_(80 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				[ListView()
					.fixedSize_(120 @ (10 + (d.lineModeOptions.size * 16).min(50)))
					.items_(d.lineModeOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.lineModeOptions.flop.slice(1).indexOfEqual(d.lineMode))
					.action_({arg view;
						d.lineMode = d.lineModeOptions.flop.slice(1)[view.value];
						d.rebuildWindow;
				}), align: \top],
				nil,
			));
			if (d.lineMode == 'curve', {
				d.guiData.toolPropertiesLayout.add(4);
				d.guiData.toolPropertiesLayout.add(HLayout(
					[d.fEZSlider(ControlSpec(-1, 1), 'lineCurve', "Curve + / - ", 200), align: \top],
					nil,
				));
			});
		});
		if (d.guiOptions.showPaintLineMode, {
			d.guiData.toolPropertiesLayout.add(4);
			d.guiData.toolPropertiesLayout.add(HLayout(
				// Line Mode
				[StaticText().string_("Line Mode").align_(\center)
					.fixedSize_(80 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				[ListView()
					.fixedSize_(120 @ (10 + (d.paintLineModeOptions.size * 16).min(50)))
					.items_(d.paintLineModeOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.paintLineModeOptions.flop.slice(1).indexOfEqual(d.paintLineMode))
					.action_({arg view;
						d.paintLineMode = d.paintLineModeOptions.flop.slice(1)[view.value];
						d.rebuildWindow;
				}), align: \top],
				nil,
			));
			if (d.paintLineMode == 'curve', {
				d.guiData.toolPropertiesLayout.add(4);
				d.guiData.toolPropertiesLayout.add(HLayout(
					[d.fEZSlider(ControlSpec(-1, 1), 'lineCurve', "Curve + / - ", 200), align: \top],
					nil,
				));
			});
		});
		if (d.guiOptions.showTriangleMode and: {d.guiOptions.showPaintMode == false}, {
			d.guiData.toolPropertiesLayout.add(4);
			d.guiData.toolPropertiesLayout.add(d.guiData.toolTriangleModeLayout);
		});
		if (d.guiOptions.showColorizeMode, {
			d.guiData.toolPropertiesLayout.add(d.fEZColorize('colorizeColor1', "Colorize 1", 200, 66, 34));
			if (d.colorizeMode != 'colorizeFlat', {
				d.guiData.toolPropertiesLayout.add(HLayout(
					[d.fEZColorize('colorizeColor2', "Colorize 2", 200, 66, 34), align: \top],
					[StaticText().string_("Swap Colors").align_(\center)
						.fixedSize_(96 @ 22)
						.stringColor_(Color.white).background_(d.colButton)
						.mouseDownAction_({arg view;
							var colorTemp = d.colorizeColor1;
							d.colorizeColor1 = d.colorizeColor2;
							d.colorizeColor2 = colorTemp;
							d.rebuildWindow;
						}),
						align: \top
					],
					nil,
				));
			});
			d.guiData.toolPropertiesLayout.add(HLayout(
				// Colorize Mode
				[StaticText().string_("Colorize Mode").align_(\center)
					.fixedSize_(100 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
				[ListView()
					.fixedSize_(290 @ (10 + (d.colorizeModeOptions.size * 16).min(80)))
					.items_(d.colorizeModeOptions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colLabel)
					.value_(d.colorizeModeOptions.flop.slice(1).indexOfEqual(d.colorizeMode))
					.action_({arg view;
						d.colorizeMode = d.colorizeModeOptions.flop.slice(1)[view.value];
						d.rebuildWindow;
				}), align: \top],
				nil,
			));
		});
		if (d.guiOptions.showPerlinProperties, {
			d.makeSelectionInfoRow;
			d.makeSelectionShiftRow;
			d.guiData.toolPropertiesLayout.add(d.guiData.selectionInfoRow);
			d.guiData.toolPropertiesLayout.add(4);
			d.guiData.toolPropertiesLayout.add(d.guiData.selectionShiftRow);
			d.guiData.toolPropertiesLayout.add(10);
			d.guiData.toolPropertiesLayout.add(VLayout(
				d.fEZColorize('perlinColor', "Color", 200),
				HLayout(
					d.fEZSlider(ControlSpec(1, 8, step: 1), 'perlinOctaves', "Perlin Octaves", 80),
					HLayout(
						d.fEZNumBox(ControlSpec(0, 99999, step: 1), 'perlinRandSeed',
							"Random Seed", 90, 50),
						StaticText().string_("Rand").align_(\center)
						.fixedSize_(40 @ 22)
						.stringColor_(Color.white).background_(d.colButton)
						.mouseDownAction_({arg view;
							d.perlinRandSeed = 10000.rand;
							d.rebuildWindow;
						}),
					).spacing_(2),
					// Separate RGB Noise checkbox
					Button().states_([
						["[ ] Separate RGB Noise", d.colButton, Color.white],
						["[X] Separate RGB Noise", Color.white, d.colButton]])
					.fixedSize_(150 @ 22)
					.action_({arg view;
						var val = view.value.asBoolean;
						d.perlinTripleNoise = val;
						d.rebuildSynth;
					})
					.value_(d.perlinTripleNoise.binaryValue),
					nil,
				).spacing_(20),
				HLayout(
					d.fEZSlider(ControlSpec(0, 100, 2), 'perlinScaleX', "Perlin Scale X", 240),
					d.fEZSlider(ControlSpec(0, 100, 2), 'perlinScaleY', "Perlin Scale Y", 240),
					nil,
				).spacing_(20),
				HLayout(
					d.fEZSlider(ControlSpec(-0.999, 0.999), 'perlinOffset', "Brightness +/-", 240),
					d.fEZSlider(ControlSpec(0, 1), 'perlinQuantize', "Perlin Quantize", 240),
					nil,
				).spacing_(20),
				HLayout(
					// Generate Perlin button
					StaticText().string_("Generate Perlin Noise in Selected Region").align_(\center)
					.fixedSize_(240 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({
						d.fApplyPerlin;
						d.guiData.sonogramView.refresh;
					}),
					// Generate Perlin button
					StaticText().string_("Colorize with Perlin Noise in Selected Region").align_(\center)
					.fixedSize_(260 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({
						d.fApplyPerlin('colorize');
						d.guiData.sonogramView.refresh;
					}),
					nil,
				),
				nil,
			).spacing_(20));
		});
		if (d.guiOptions.showAnalysisProperties, {
			d.guiData.toolPropertiesLayout.add(VLayout(
				d.fEZColorize('analysisColor', "Color", 200, 66, 34),
				HLayout(
					// analysisCompLimit checkbox
					[Button().states_([
						["[ ] Compress and Limit each Frequency", d.colButton, Color.white],
						["[X] Compress and Limit each Frequency", Color.white, d.colButton]])
					.fixedSize_(230 @ 22)
					.action_({arg view;
						var val = view.value.asBoolean;
						d.analysisCompLimit = val;
					})
					.value_(d.analysisCompLimit.binaryValue), align: \top],
					VLayout(
						d.fEZSlider(ControlSpec(-5, 5), 'analysisCompressionCurve', "Compression Curve", 240, 120),
						d.fEZSlider(ControlSpec(0.1, 1), 'analysisLimitCeiling', "Limit Ceiling", 240, 120),
					).spacing_(10),
					nil,
				).spacing_(20),
				HLayout(
					// Help text
					StaticText().string_(
						"Note: Sound file must be mono or stereo and less than 120 secs.\n"
						++ "After analysis, the sonogram will replace the current image.").align_(\center)
					.fixedSize_(370 @ 40)
					.stringColor_(Color.black).background_(Color.white),
					// analysisSetsPlayLength checkbox
					[Button().states_([
						["[ ] Automatically set Play Length to length of analysed sound file", d.colButton, Color.white],
						["[X] Automatically set Play Length to length of analysed sound file", Color.white, d.colButton]])
					.fixedSize_(370 @ 22)
					.action_({arg view;
						var val = view.value.asBoolean;
						d.analysisSetsPlayLength = val;
					})
					.value_(d.analysisSetsPlayLength.binaryValue), align: \top],
					nil,
				).spacing_(14),
				HLayout(
					// Open Sound File button
					StaticText().string_(
						"Open sound file, analyse it and create sonogram image").align_(\center)
					.fixedSize_(310 @ 30)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({
						d.fAnalyseSoundFile;
						d.rebuildWindow;
					}),
					// Stop Analysis button
					StaticText().string_("Stop Analysis").align_(\center)
					.fixedSize_(90 @ 30)
					.stringColor_(Color.white).background_(d.colStop)
					.mouseDownAction_({
						d.fStopAnalysis;
					}),
					nil,
				).spacing_(14),
				nil,
			).spacing_(14));
		});
		if (d.guiOptions.showCompressionProperties, {
			d.makeSelectionInfoRow;
			d.makeSelectionShiftRow;
			d.guiData.toolPropertiesLayout.add(d.guiData.selectionInfoRow);
			d.guiData.toolPropertiesLayout.add(4);
			d.guiData.toolPropertiesLayout.add(d.guiData.selectionShiftRow);
			d.guiData.toolPropertiesLayout.add(10);
			d.guiData.toolPropertiesLayout.add(VLayout(
				HLayout(
					VLayout(
						// checkboxes
						Button().states_([
							["[ ] Use Gate", d.colButton, Color.white],
							["[X] Use Gate", Color.white, d.colButton]])
						.fixedSize_(220 @ 22)
						.action_({arg view;
							var val = view.value.asBoolean;
							d.useGate = val;
						})
						.value_(d.useGate.binaryValue),
						Button().states_([
							["[ ] Use Expansion / Compression", d.colButton, Color.white],
							["[X] Use Expansion / Compression", Color.white, d.colButton]])
						.fixedSize_(220 @ 22)
						.action_({arg view;
							var val = view.value.asBoolean;
							d.useCompression = val;
						})
						.value_(d.useCompression.binaryValue),
						Button().states_([
							["[ ] Use Limiter", d.colButton, Color.white],
							["[X] Use Limiter", Color.white, d.colButton]])
						.fixedSize_(220 @ 22)
						.action_({arg view;
							var val = view.value.asBoolean;
							d.useLimiter = val;
						})
						.value_(d.useLimiter.binaryValue),
						Button().states_([
							["[ ] Automatic Gain Compensation", d.colButton, Color.white],
							["[X] Automatic Gain Compensation", Color.white, d.colButton]])
						.fixedSize_(220 @ 22)
						.action_({arg view;
							var val = view.value.asBoolean;
							d.autoGainCompensation = val;
						})
						.value_(d.autoGainCompensation.binaryValue),
						nil,
					).spacing_(10),
					VLayout(
						d.fEZSlider(ControlSpec(0.0, 0.4), 'gateThreshold', "Gate Threshold", 240, 120),
						d.fEZSlider(ControlSpec(-5, 5), 'compressionCurve', "Expand-/ Compress+", 240, 120),
						d.fEZSlider(ControlSpec(0.5, 1), 'limitCeiling', "Limit Ceiling", 240, 120),
						nil,
					).spacing_(10),
					nil,
				).spacing_(20),
				HLayout(
					// Apply Gate, Compressor, Limiter button
					StaticText().string_("Apply Gate, Compressor, Limiter").align_(\center)
					.fixedSize_(200 @ 30)
					.stringColor_(Color.white).background_(d.colStop)
					.mouseDownAction_({
						d.fApplyCompression;
						d.rebuildWindow;
					}),
					nil,
				),
				nil,
			).spacing_(10));
		});
		// add final nil
		d.guiData.toolPropertiesLayout.add(nil);

		d.guiData.toolsBox = HLayout(  // Row of controls
			VLayout(
				// label
				StaticText().string_("Image Tools").align_(\center)
				.fixedSize_(170 @ 30)
				.stringColor_(d.colLabelString).background_(d.colLabel),
				d.guiData.toolModeView,
				// label
				StaticText().string_("Load Default Tool Settings").align_(\center)
				.fixedSize_(170 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.fLoadDefaultToolSettings;
					d.rebuildWindow;
				}),
				nil,
			),
			6, // spacer
			d.guiData.toolPropertiesLayout,
			nil, // spacer
		);
		d.guiData.imageLayout = VLayout(
			HLayout(d.guiData.imageSelectRow, d.guiData.playRow, 10, d.guiData.snapshotsRow, nil),
			5, // spacer
			[d.guiData.sonogramRow, align: \left],
			5, // spacer
			[d.guiData.toolsBox, align: \left],
			5, // spacer
			nil,  // spacer
		);
	};
	// end of d.makeImageToolsLayout

	// curve history buttons
	d.makeCurveHistoryRow = {arg event, dataKey, actionFunc = {};
		var layout = HLayout(
			// buttons
			StaticText().string_("<").align_(\center)
			.fixedSize_(22 @ 22)
			.stringColor_(Color.white).background_(d.colButton)
			.mouseDownAction_({
				d.fLoadPrevCurveHistory(dataKey, actionFunc);
				d.rebuildWindow;
			}),
			StaticText().string_(">").align_(\center)
			.fixedSize_(22 @ 22)
			.stringColor_(Color.white).background_(d.colButton)
			.mouseDownAction_({
				d.fLoadNextCurveHistory(dataKey, actionFunc);
				d.rebuildWindow;
			}),
		).spacing_(2);
		layout; // return layout
	};

	d.makeEQRow = {
		d.guiData.eqBackView = UserView()
		.background_(Color.white)
		.drawFunc_({arg view;
			Pen.color = Color.black;
			Pen.line(0 @ (0.5 * view.bounds.height), view.bounds.width  @ (0.5 * view.bounds.height));
			Pen.stroke;
			9.do({arg i;
				var gap = 8.reciprocal;
				var string = d.arrFreqs[(gap * i * (d.arrFreqs.size - 1)).asInteger]
				.round.asInteger.asString;
				var left = gap * i * (view.bounds.width - 1);
				var stringLeft = 3 + left.max(3).min(view.bounds.width - 40);
				Pen.line(left @ 3, left @ 24);
				Pen.stroke;
				Pen.stringAtPoint(string, stringLeft @ 5);
			});
		});
		d.guiData.eqMultiSliderView = MultiSliderView(d.guiData.eqBackView)
		.fixedSize_((d.arrEQAmps.size * 4).max(800) @ 260).elasticMode_(1)
		.drawLines_(true).drawRects_(false).isFilled_(true)
		.background_(Color(1, 1, 1, 0)).fillColor_(Color(0.8, 0.92, 1, 0.5))
		.value_(d.arrEQAmps * 0.5)  // scale down
		.mouseUpAction_({arg view;
			d.arrEQAmps = view.value * 2;  // scale up
			d.fBuildArrWarpedEQAmps;
			d.fAddToCurveHistory('arrEQAmps');
		});
		d.guiData.eqBackView.fixedSize_(d.guiData.eqMultiSliderView.bounds.extent);
		d.guiData.eqCurveHistRow = d.makeCurveHistoryRow('arrEQAmps', {d.fBuildArrWarpedEQAmps});
		d.guiData.eqRow = VLayout(
			4,
			HLayout(
				d.guiData.eqBackView,
				nil,
			),
			HLayout(
				// buttons
				d.guiData.eqCurveHistRow,
				StaticText().string_("Reset").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.arrEQAmps = 1 ! d.arrEQAmps.size;
					d.guiData.eqMultiSliderView.value_(d.arrEQAmps * 0.5); // scale down
					d.fBuildArrWarpedEQAmps;
					d.fAddToCurveHistory('arrEQAmps');
				}),
				StaticText().string_("Smooth").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.arrEQAmps = d.arrEQAmps.size.collect({arg i;
						[-1, 0, 1].collect({arg item; d.arrEQAmps.clipAt(i + item)}).mean;
					});
					d.guiData.eqMultiSliderView.value_(d.arrEQAmps * 0.5); // scale down
					d.fBuildArrWarpedEQAmps;
					d.fAddToCurveHistory('arrEQAmps');
				}),
				StaticText().string_("Smooth 5").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					5.do({
						d.arrEQAmps = d.arrEQAmps.size.collect({arg i;
							[-1, 0, 1].collect({arg item; d.arrEQAmps.clipAt(i + item)}).mean;
						});
					});
					d.guiData.eqMultiSliderView.value_(d.arrEQAmps * 0.5); // scale down
					d.fBuildArrWarpedEQAmps;
					d.fAddToCurveHistory('arrEQAmps');
				}),
				nil,
			),
			nil,
		).spacing_(10);
	}; // end of d.makeEQRow

	d.makeEQLayout = {
		// prepare views
		d.makeSonogramRow;
		d.makeImageSelectRow;
		d.makePlayRow;
		d.makePixelSizeRow;
		d.makeEQRow;
		d.guiData.eqLayout = VLayout(
			HLayout(d.guiData.imageSelectRow, d.guiData.playRow, nil),
			[d.guiData.sonogramRow, align: \left],
			HLayout(
				StaticText().string_("Graphic EQ"
				).align_(\center)
				.fixedSize_(110 @ 30)
				.stringColor_(d.colLabelString).background_(d.colLabel),
				20,
				// Use EQ checkbox
				Button().states_([
					["[ ] Use EQ", d.colButton, Color.white],
					["[X] Use EQ", Color.white, d.colButton]])
				.fixedSize_(90 @ 26)
				.action_({arg view;
					d.useEQ = view.value.asBoolean;
					d.rebuildWindow;
				})
				.value_(d.useEQ.binaryValue),
				20,
				StaticText().string_("Min. Freq:" + d.arrFreqs.first.round.asInteger
					+ "   Max. Freq:" + d.arrFreqs.last.round.asInteger
				).align_(\center)
				.fixedSize_(200 @ 26)
				.stringColor_(d.colLabelString).background_(d.colButton.blend(Color.white, 0.9)),
				20,
				d.pixelSizeRow,
				nil,
			),
			[d.guiData.eqRow, align: \left],
			nil,  // spacer
		).spacing_(10);
	};

	d.makeEnvRow = {
		var tableSize = d.envCurve.size;
		var linearArray = Array.interpolation(tableSize, 0.0, 1.0);
		var presetEnvCurves = [
			["Preset Curves ...", {d.envCurve}],
			["Centre Line (default)", 0.5 ! tableSize],
			["Pulse 25%",
				{tableSize.collect({arg i; [0, 1][(i < (tableSize / 4)).binaryValue]});}],
			["Pulse 33.33%",
				{tableSize.collect({arg i; [0, 1][(i < (tableSize / 3)).binaryValue]});}],
			["Pulse 50%",
				{tableSize.collect({arg i; [0, 1][(i < (tableSize / 2)).binaryValue]});}],
			["Ramp Up", linearArray],
			["Ramp Down", linearArray.reverse],
			["Triangle", { var holdArr;
				holdArr = Array.newClear(tableSize/2).seriesFill(0, 2 / (tableSize - 1));
				holdArr ++ holdArr.copy.reverse;}],
			["Sine", {
				var arr = Signal.sineFill(tableSize-1,
					[1.0],[0.0]).collect({arg item, i; (item.value + 1) * 0.5;});
				arr = arr.add(arr[0]);
			}],
			["Cosine", {
				var arr = Signal.sineFill(tableSize-1,
					[1.0],[0.5pi]).collect({arg item, i; (item.value + 1) * 0.5;});
				arr = arr.add(arr[0]);
			}],
			["Exponential", {linearArray.collect({arg item, i;
				ControlSpec(0.001, 1, \exp).map(item).linlin(0.001, 1, 0, 1)});}],
			["-Exponential", {linearArray.collect({arg item, i;
				1-ControlSpec(0.001, 1, \exp).map(1-item).linlin(0.001, 1, 0, 1)});}],
			["Curve +1", {linearArray.collect({arg item, i; ControlSpec(0, 1, 1).map(item); });}],
			["Curve +2", {linearArray.collect({arg item, i; ControlSpec(0, 1, 2).map(item); });}],
			["Curve +3", {linearArray.collect({arg item, i; ControlSpec(0, 1, 3).map(item); });}],
			["Curve +4", {linearArray.collect({arg item, i; ControlSpec(0, 1, 4).map(item); });}],
			["Curve +5", {linearArray.collect({arg item, i; ControlSpec(0, 1, 5).map(item); });}],
			["Curve +6", {linearArray.collect({arg item, i; ControlSpec(0, 1, 6).map(item); });}],
			["Curve +7", {linearArray.collect({arg item, i; ControlSpec(0, 1, 7).map(item); });}],
			["Curve +8", {linearArray.collect({arg item, i; ControlSpec(0, 1, 8).map(item); });}],
			["Curve +9", {linearArray.collect({arg item, i; ControlSpec(0, 1, 9).map(item); });}],
			["Curve +10", {linearArray.collect({arg item, i; ControlSpec(0, 1, 10).map(item); });}],
			["Curve -1", {linearArray.collect({arg item, i; ControlSpec(0, 1, -1).map(item); });}],
			["Curve -2", {linearArray.collect({arg item, i; ControlSpec(0, 1, -2).map(item); });}],
			["Curve -3", {linearArray.collect({arg item, i; ControlSpec(0, 1, -3).map(item); });}],
			["Curve -4", {linearArray.collect({arg item, i; ControlSpec(0, 1, -4).map(item); });}],
			["Curve -5", {linearArray.collect({arg item, i; ControlSpec(0, 1, -5).map(item); });}],
			["Curve -6", {linearArray.collect({arg item, i; ControlSpec(0, 1, -6).map(item); });}],
			["Curve -7", {linearArray.collect({arg item, i; ControlSpec(0, 1, -7).map(item); });}],
			["Curve -8", {linearArray.collect({arg item, i; ControlSpec(0, 1, -8).map(item); });}],
			["Curve -9", {linearArray.collect({arg item, i; ControlSpec(0, 1, -9).map(item); });}],
			["Curve -10", {linearArray.collect({arg item, i; ControlSpec(0, 1, -10).map(item); });}],
		];
		// prepare curve actions
		var multiCopy = { arg count;
			d.envCurve = d.envCurve.dup(count).flat.resamp0(d.envCurve.size);
		};
		var shiftPhase = { arg shift;
			var startIndex, tempArr;
			var size = d.envCurve.size;
			if ((shift > 0) && (shift < 1), {
				tempArr = d.envCurve.deepCopy;
				startIndex = (shift * (d.envCurve.size-1)).asInteger;
				d.envCurve = tempArr[startIndex..] ++ tempArr[..(startIndex-1)];
			});
		};
		var mirrorInvert = {
			var oldArray, startVal, midArray, endVal, newArray;
			oldArray = d.envCurve.deepCopy;
			startVal = oldArray.first.asArray;
			midArray = oldArray.drop(2).drop(-2);
			if ((midArray.size % 2) == 1, {
				midArray = midArray.add(oldArray.last);
			});
			midArray = midArray.clump(2).collect({arg item, i; item.sum/2;});
			endVal = oldArray.last.asArray;
			newArray = startVal ++ midArray ++ endVal;
			newArray = ((newArray - 1) ++ (newArray.copy.reverse.neg + 1)).madd(0.5, 0.5);
			if (newArray.size >  d.envCurve.size, {
				newArray.removeAt((newArray.size/2).asInteger);
			});
			d.envCurve = newArray;
		};
		var	envCurveActions = [
			[ "Modify curve ...", {}],
			[ "Mirror curve", {d.envCurve =
				(d.envCurve ++ d.envCurve.reverse).resamp1(tableSize);}],
			[ "Inverted Mirror curve", {mirrorInvert.value}],
			[ "Normalize curve", {d.envCurve = d.envCurve.normalize;}],
			[ "Scale curve so maximum is centred", {d.envCurve = d.envCurve * 0.5 /d.envCurve.maxItem.max(0.01);}],
			[ "2X - Double copy", {multiCopy.value(2);}],
			[ "3X - Triple copy", {multiCopy.value(3);}],
			[ "4X - Quad copy", {multiCopy.value(4);}],
			[ "Phase shift 1/16 = 6.25 % = 22.5 deg", {shiftPhase.value(0.0625);}],
			[ "Phase shift 1/8 = 12.5 % = 45 deg", {shiftPhase.value(0.125);}],
			[ "Phase shift 1/6 = 16.66 % = 60 deg", {shiftPhase.value(6.reciprocal);}],
			[ "Phase shift 1/4 = 25 % = 90 deg", {shiftPhase.value(0.25);}],
			[ "Phase shift 1/3 = 33.33 % = 120 deg", {shiftPhase.value(3.reciprocal);}],
			[ "Phase shift 1/2 = 50 % = 180 deg", {shiftPhase.value(0.5);}],
			[ "Phase shift 2/3 = 66.66 % = 240 deg", {shiftPhase.value(2.0/3.0);}],
			[ "Phase shift 3/4 = 75 % = 270 deg", {shiftPhase.value(0.75);}],
		];
		d.guiData.envBackView = UserView()
		.background_(Color.white)
		.drawFunc_({arg view;
			var maxY = view.bounds.height - 1;
			if (d.showBackgroundImage, {
				d.showBackgroundImage = true;
				d.arrImages[d.imageIndex].smooth = true;
				Pen.drawImage(Rect(0, 0, view.bounds.width, view.bounds.height),
					d.arrImages[d.imageIndex], operation: 'sourceOver', opacity:1);
			});
			Pen.color = Color.black;
			Pen.line(0 @ (0.5 * view.bounds.height), view.bounds.width  @ (0.5 * view.bounds.height));
			Pen.stroke;
			(0, 0.125..1).do({arg val, i;
				var posY = maxY - (val * maxY);
				if (val == 0.5, {
					Pen.color = Color.red(0.4);
				}, {
					Pen.color = Color.grey(0.25);
				});
				Pen.line(0 @ posY, (view.bounds.width - 1) @ posY);
				Pen.stroke;
			});
			if (d.showTimeGrid, {
				Pen.use{
					var spacing = view.bounds.width / d.timeGridSteps;
					Pen.color = Color.black;
					Pen.smoothing_(false);
					(d.timeGridSteps + 1).do({arg i;
						var x = i * spacing;
						Pen.line(Point(x, 0), Point(x, view.bounds.height));
						Pen.stroke;
					});
				};
			});
			if (d.mouseIsDown.asBoolean, {
				2.do({arg i;
					Pen.color = [Color.black, Color.white][i];
					Pen.line(Point((d.mouseX ? 0) + i, 0), Point((d.mouseX ? 0) + i, view.bounds.height));
					Pen.line(Point(0, (d.mouseY ? 0) + i), Point( view.bounds.width, (d.mouseY ? 0) + i));
					Pen.stroke;
				});
			});
		});
		d.guiData.envMultiSliderView = MultiSliderView(d.guiData.envBackView)
		.fixedSize_((d.imageWidth * d.pixelWidth).max(360) @ 250).elasticMode_(1)
		.drawLines_(true).drawRects_(false).isFilled_(true)
		.background_(Color(1, 1, 1, 0)).fillColor_(Color(0.8, 0.92, 1, 0.5))
		.value_(d.envCurve)
		.mouseDownAction_({arg view, x, y;
			d.mouseIsDown = true;
			d.mouseX = x; d.mouseY = y;
			d.guiData.envBackView.refresh;
		})
		.mouseMoveAction_({arg view, x, y;
			d.mouseX = x; d.mouseY = y;
			d.mouseIsDown = true;
			d.guiData.envBackView.refresh;
		})
		.mouseUpAction_({arg view, x, y;
			d.envCurve = view.value;
			d.fAddToCurveHistory('envCurve');
			d.mouseIsDown = false;
			d.guiData.envBackView.refresh;
		});
		d.guiData.envBackView.fixedSize_(d.guiData.envMultiSliderView.bounds.extent);
		d.guiData.envCurveHistRow = d.makeCurveHistoryRow('envCurve', {});
		d.guiData.envRow = VLayout(
			4,
			HLayout(
				StaticText().string_("Envelope").align_(\center)
				.fixedSize_(100 @ 30)
				.stringColor_(d.colLabelString).background_(d.colLabel),
				20,
				// Use Env checkbox
				Button().states_([
					["[ ] Use Env", d.colButton, Color.white],
					["[X] Use Env", Color.white, d.colButton]])
				.fixedSize_(90 @ 26)
				.action_({arg view;
					d.useEnv = view.value.asBoolean;
					d.rebuildWindow;
				})
				.value_(d.useEnv.binaryValue),
				20,
				[d.pixelSizeRow, align: \center],
				20,
				[d.guiData.timeGridRow, align: \center],
				nil,
			),
			HLayout(
				d.guiData.envBackView,
				nil,
			),
			HLayout(
				// buttons
				d.guiData.envCurveHistRow,
				// Show Image checkbox
				Button().states_([
					["[ ] Show Image", d.colButton, Color.white],
					["[X] Show Image", Color.white, d.colButton]])
				.fixedSize_(100 @ 22)
				.action_({arg view;
					d.showBackgroundImage = view.value.asBoolean;
					d.rebuildWindow;
				})
				.value_(d.showBackgroundImage.binaryValue),
				StaticText().string_("Reset").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.envCurve = 0.5 ! d.envCurve.size;
					d.guiData.envMultiSliderView.value_(d.envCurve);
					d.fAddToCurveHistory('envCurve');
				}),
				StaticText().string_("Smooth").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.envCurve = d.envCurve.size.collect({arg i;
						[-1, 0, 1].collect({arg item; d.envCurve.clipAt(i + item)}).mean;
					});
					d.guiData.envMultiSliderView.value_(d.envCurve);
					d.fAddToCurveHistory('envCurve');
				}),
				StaticText().string_("Smooth 5").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					5.do({
						d.envCurve = d.envCurve.size.collect({arg i;
							[-1, 0, 1].collect({arg item; d.envCurve.clipAt(i + item)}).mean;
						});
					});
					d.guiData.envMultiSliderView.value_(d.envCurve);
					d.fAddToCurveHistory('envCurve');
				}),
				StaticText().string_("Invert").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.envCurve = 1 - d.envCurve;
					d.guiData.envMultiSliderView.value_(d.envCurve);
					d.guiData.envBackView.refresh;
					d.fAddToCurveHistory('envCurve');
				}),
				StaticText().string_("Reverse").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.envCurve = d.envCurve.reverse;
					d.guiData.envMultiSliderView.value_(d.envCurve);
					d.guiData.envBackView.refresh;
					d.fAddToCurveHistory('envCurve');
				}),

				// presetEnvCurves popup
				PopUpMenu()
				.fixedSize_(160 @ 26)
				.items_(presetEnvCurves.flop.slice(0))
				.stringColor_(Color.black).background_(d.colButton.blend(Color.white, 0.6))
				.value_(0)
				.action_({arg view;
					if (view.value > 0, {
						d.envCurve = presetEnvCurves.flop.slice(1)[view.value].value;
						d.buildArrEnves;
						d.guiData.envMultiSliderView.value_(d.envCurve);
						d.guiData.envBackView.refresh;
						d.fAddToCurveHistory('envCurve');
						view.value = 0;
					});
				}),
				// Actions popup
				PopUpMenu()
				.fixedSize_(160 @ 26)
				.items_(envCurveActions.flop.slice(0))
				.stringColor_(Color.black).background_(d.colButton.blend(Color.white, 0.6))
				.value_(0)
				.action_({arg view;
					envCurveActions.flop.slice(1)[view.value].value;
					d.buildArrEnves;
					d.guiData.envMultiSliderView.value_(d.envCurve);
					d.guiData.envBackView.refresh;
					d.fAddToCurveHistory('envCurve');
					view.value = 0;
				}),
				nil,
			),
			nil,
		).spacing_(16);
	};  // end of d.makeEnvRow

	d.makeEnvLayout = {
		// prepare views
		d.makeSonogramRow;
		d.makeImageSelectRow;
		d.makePlayRow;
		d.makePixelSizeRow;
		d.makeTimeGridRow;
		d.makeEnvRow;
		// put edit view on top of sonogram
		d.guiData.sonogramEditView = UserView(parent: d.guiData.sonogramView).background_(Color.clear)
		.fixedSize_((d.imageWidth * d.pixelWidth) @ (d.imageHeight * d.pixelHeight))
		.drawFunc_({arg view;
			if (d.showTimeGrid, {
				Pen.use{
					var spacing = view.bounds.width / d.timeGridSteps;
					Pen.smoothing_(false);
					(d.timeGridSteps + 1).do({arg i;
						var x = i * spacing;
						Pen.color = Color(1, 1, 1, 0.6);
						Pen.line(Point(x, 0), Point(x, view.bounds.height));
						Pen.stroke;
						Pen.color = Color(0, 0, 0, 0.6);
						Pen.line(Point(x+1, 0), Point(x+1, view.bounds.height));
						Pen.line(Point(x-1, 0), Point(x-1, view.bounds.height));
						Pen.stroke;
					});
				};
			});
		});
		d.guiData.envLayout = VLayout(
			HLayout(d.guiData.imageSelectRow, d.guiData.playRow, nil),
			[d.guiData.sonogramRow, align: \left],
			[d.guiData.envRow, align: \left],
			nil,  // spacer
		).spacing_(10);
	};

	d.makePitchShiftRow = {
		var tableSize = d.arrNormPitchShifts.size;
		var linearArray = Array.interpolation(tableSize, 0.0, 1.0);
		var presetPitchShiftCurves = [
			["Preset Curves ...", {d.arrNormPitchShifts}],
			["Centre Line (default)", 0.5 ! tableSize],
			["Pulse 25%",
				{tableSize.collect({arg i; [0, 1][(i < (tableSize / 4)).binaryValue]});}],
			["Pulse 33.33%",
				{tableSize.collect({arg i; [0, 1][(i < (tableSize / 3)).binaryValue]});}],
			["Pulse 50%",
				{tableSize.collect({arg i; [0, 1][(i < (tableSize / 2)).binaryValue]});}],
			["Ramp Up", linearArray],
			["Ramp Down", linearArray.reverse],
			["Triangle", { var holdArr;
				holdArr = Array.newClear(tableSize/2).seriesFill(0, 2 / (tableSize - 1));
				holdArr ++ holdArr.copy.reverse;}],
			["Sine", {
				var arr = Signal.sineFill(tableSize-1,
					[1.0],[0.0]).collect({arg item, i; (item.value + 1) * 0.5;});
				arr = arr.add(arr[0]);
			}],
			["Cosine", {
				var arr = Signal.sineFill(tableSize-1,
					[1.0],[0.5pi]).collect({arg item, i; (item.value + 1) * 0.5;});
				arr = arr.add(arr[0]);
			}],
			["Exponential", {linearArray.collect({arg item, i;
				ControlSpec(0.001, 1, \exp).map(item).linlin(0.001, 1, 0, 1)});}],
			["-Exponential", {linearArray.collect({arg item, i;
				1-ControlSpec(0.001, 1, \exp).map(1-item).linlin(0.001, 1, 0, 1)});}],
			["Curve +1", {linearArray.collect({arg item, i; ControlSpec(0, 1, 1).map(item); });}],
			["Curve +2", {linearArray.collect({arg item, i; ControlSpec(0, 1, 2).map(item); });}],
			["Curve +3", {linearArray.collect({arg item, i; ControlSpec(0, 1, 3).map(item); });}],
			["Curve +4", {linearArray.collect({arg item, i; ControlSpec(0, 1, 4).map(item); });}],
			["Curve +5", {linearArray.collect({arg item, i; ControlSpec(0, 1, 5).map(item); });}],
			["Curve +6", {linearArray.collect({arg item, i; ControlSpec(0, 1, 6).map(item); });}],
			["Curve +7", {linearArray.collect({arg item, i; ControlSpec(0, 1, 7).map(item); });}],
			["Curve +8", {linearArray.collect({arg item, i; ControlSpec(0, 1, 8).map(item); });}],
			["Curve +9", {linearArray.collect({arg item, i; ControlSpec(0, 1, 9).map(item); });}],
			["Curve +10", {linearArray.collect({arg item, i; ControlSpec(0, 1, 10).map(item); });}],
			["Curve -1", {linearArray.collect({arg item, i; ControlSpec(0, 1, -1).map(item); });}],
			["Curve -2", {linearArray.collect({arg item, i; ControlSpec(0, 1, -2).map(item); });}],
			["Curve -3", {linearArray.collect({arg item, i; ControlSpec(0, 1, -3).map(item); });}],
			["Curve -4", {linearArray.collect({arg item, i; ControlSpec(0, 1, -4).map(item); });}],
			["Curve -5", {linearArray.collect({arg item, i; ControlSpec(0, 1, -5).map(item); });}],
			["Curve -6", {linearArray.collect({arg item, i; ControlSpec(0, 1, -6).map(item); });}],
			["Curve -7", {linearArray.collect({arg item, i; ControlSpec(0, 1, -7).map(item); });}],
			["Curve -8", {linearArray.collect({arg item, i; ControlSpec(0, 1, -8).map(item); });}],
			["Curve -9", {linearArray.collect({arg item, i; ControlSpec(0, 1, -9).map(item); });}],
			["Curve -10", {linearArray.collect({arg item, i; ControlSpec(0, 1, -10).map(item); });}],
		];
		// prepare curve actions
		var multiCopy = { arg count;
			d.arrNormPitchShifts = d.arrNormPitchShifts.dup(count).flat.resamp0(d.arrNormPitchShifts.size);
		};
		var shiftPhase = { arg shift;
			var startIndex, tempArr;
			var size = d.arrNormPitchShifts.size;
			if ((shift > 0) && (shift < 1), {
				tempArr = d.arrNormPitchShifts.deepCopy;
				startIndex = (shift * (d.arrNormPitchShifts.size-1)).asInteger;
				d.arrNormPitchShifts = tempArr[startIndex..] ++ tempArr[..(startIndex-1)];
			});
		};
		var mirrorInvert = {
			var oldArray, startVal, midArray, endVal, newArray;
			oldArray = d.arrNormPitchShifts.deepCopy;
			startVal = oldArray.first.asArray;
			midArray = oldArray.drop(2).drop(-2);
			if ((midArray.size % 2) == 1, {
				midArray = midArray.add(oldArray.last);
			});
			midArray = midArray.clump(2).collect({arg item, i; item.sum/2;});
			endVal = oldArray.last.asArray;
			newArray = startVal ++ midArray ++ endVal;
			newArray = ((newArray - 1) ++ (newArray.copy.reverse.neg + 1)).madd(0.5, 0.5);
			if (newArray.size >  d.arrNormPitchShifts.size, {
				newArray.removeAt((newArray.size/2).asInteger);
			});
			d.arrNormPitchShifts = newArray;
		};
		var	pitchShiftCurveActions = [
			[ "Modify curve ...", {}],
			[ "Mirror curve", {d.arrNormPitchShifts =
				(d.arrNormPitchShifts ++ d.arrNormPitchShifts.reverse).resamp1(tableSize);}],
			[ "Inverted Mirror curve", {mirrorInvert.value}],
			[ "Normalize curve", {d.arrNormPitchShifts = d.arrNormPitchShifts.normalize;}],
			[ "2X - Double copy", {multiCopy.value(2);}],
			[ "3X - Triple copy", {multiCopy.value(3);}],
			[ "4X - Quad copy", {multiCopy.value(4);}],
			[ "Bipolar to unipolar",
				{d.arrNormPitchShifts = d.arrNormPitchShifts.linlin(0.0, 1.0, 0.5, 1.0);}],
			[ "Bipolar to negative unipolar",
				{d.arrNormPitchShifts = d.arrNormPitchShifts.linlin(0.0, 1.0, 0.0, 0.5);}],
			[ "Phase shift 1/16 = 6.25 % = 22.5 deg", {shiftPhase.value(0.0625);}],
			[ "Phase shift 1/8 = 12.5 % = 45 deg", {shiftPhase.value(0.125);}],
			[ "Phase shift 1/6 = 16.66 % = 60 deg", {shiftPhase.value(6.reciprocal);}],
			[ "Phase shift 1/4 = 25 % = 90 deg", {shiftPhase.value(0.25);}],
			[ "Phase shift 1/3 = 33.33 % = 120 deg", {shiftPhase.value(3.reciprocal);}],
			[ "Phase shift 1/2 = 50 % = 180 deg", {shiftPhase.value(0.5);}],
			[ "Phase shift 2/3 = 66.66 % = 240 deg", {shiftPhase.value(2.0/3.0);}],
			[ "Phase shift 3/4 = 75 % = 270 deg", {shiftPhase.value(0.75);}],
		];
		// build views
		d.guiData.pitchShiftBackView = UserView()
		.background_(Color.white)
		.drawFunc_({arg view;
			var lineQuant, stringQuant, maxValQuant, mappedVals, unmappedVals, maxY, playLengthString;
			// draw image
			if (d.showBackgroundImage, {
				d.showBackgroundImage = true;
				d.arrImages[d.imageIndex].smooth = true;
				Pen.drawImage(Rect(0, 0, view.bounds.width, view.bounds.height),
					d.arrImages[d.imageIndex], operation: 'sourceOver', opacity:1);
			});
			// draw (part-)semitone lines
			case
			{d.maxShift <= 0.01} {lineQuant = 0.001}
			{d.maxShift <= 0.05} {lineQuant = 0.005}
			{d.maxShift <= 0.1} {lineQuant = 0.01}
			{d.maxShift <= 0.5} {lineQuant = 0.05}
			{d.maxShift <= 1} {lineQuant = 0.1}
			{d.maxShift <= 5} {lineQuant = 0.5}
			{d.maxShift <= 12} {lineQuant = 1}
			{d.maxShift <= 24} {lineQuant = 2}
			{d.maxShift <= 36} {lineQuant = 3}
			{d.maxShift <= 48} {lineQuant = 4}
			;
			maxValQuant = d.maxShift.roundUp(lineQuant) - lineQuant;
			mappedVals = (maxValQuant.neg, (maxValQuant.neg + lineQuant).. maxValQuant).round(0.001);
			unmappedVals = mappedVals.linlin(d.maxShift.neg, d.maxShift, 0, 1, nil);
			maxY = view.bounds.height - 1;
			Pen.color = Color.black;
			unmappedVals.do({arg val, i;
				var posX, posY, stringVal, string, stringY;
				posX = i % 2 * 30;
				posY = maxY - (val * maxY);
				stringVal = mappedVals[i];
				if (lineQuant >= 1, {
					string = stringVal.asInteger.asString;
				}, {
					string = stringVal.asString;
				});
				stringY = (posY - 10).min(view.bounds.height - 16).max(3);
				if (val == 0.5, {
					posX = 0;
					Pen.color = Color.red(0.4);
					string = stringVal.asInteger.asString + "semitones";
				}, {
					Pen.color = [Color.green(0.4), Color.grey(0.2)].wrapAt(i);
				});
				Pen.line(0 @ posY, (view.bounds.width - 1) @ posY);
				Pen.stroke;
				Pen.stringAtPoint(string, (4 + posX) @ stringY);
			});
			if (d.showTimeGrid, {
				Pen.use{
					var spacing = view.bounds.width / d.timeGridSteps;
					Pen.color = Color.black;
					Pen.smoothing_(false);
					(d.timeGridSteps + 1).do({arg i;
						var x = i * spacing;
						Pen.line(Point(x, 0), Point(x, view.bounds.height));
						Pen.stroke;
					});
				};
			});
			if (d.mouseIsDown.asBoolean, {
				2.do({arg i;
					Pen.color = [Color.black, Color.white][i];
					Pen.line(Point((d.mouseX ? 0) + i, 0), Point((d.mouseX ? 0) + i, view.bounds.height));
					Pen.line(Point(0, (d.mouseY ? 0) + i), Point( view.bounds.width, (d.mouseY ? 0) + i));
					Pen.stroke;
				});
			});
		});
		d.guiData.pitchShiftMultiSliderView = MultiSliderView(d.guiData.pitchShiftBackView)
		.fixedSize_((d.imageWidth * d.pixelWidth).max(360) @ 230).elasticMode_(1)
		.drawLines_(true).drawRects_(false).isFilled_(true)
		.reference_(0.5 ! d.arrNormPitchShifts.size)
		.background_(Color(1, 1, 1, 0)).fillColor_(Color(0.8, 0.92, 1, 0.25))
		.value_(d.arrNormPitchShifts)
		.mouseDownAction_({arg view, x, y;
			d.mouseIsDown = true;
			d.mouseX = x; d.mouseY = y;
			d.guiData.pitchShiftBackView.refresh;
		})
		.mouseMoveAction_({arg view, x, y;
			d.mouseX = x; d.mouseY = y;
			d.mouseIsDown = true;
			d.guiData.pitchShiftBackView.refresh;
		})
		.mouseUpAction_({arg view;
			d.arrNormPitchShifts = view.value;
			d.fBuildArrPitchShifts;
			d.guiData.pitchShiftBackView.refresh;
			d.fAddToCurveHistory('arrNormPitchShifts');
			d.mouseIsDown = false;
			d.guiData.pitchShiftBackView.refresh;
		});
		d.guiData.pitchShiftBackView.fixedSize_(d.guiData.pitchShiftMultiSliderView.bounds.extent);
		d.guiData.pitchShiftCurveHistRow = d.makeCurveHistoryRow('arrNormPitchShifts', {d.fBuildArrPitchShifts});
		d.guiData.pitchShiftRow = VLayout(
			4,
			HLayout(
				d.fEZSlider(ControlSpec(0.01, 48.0, 2), 'maxShift', "Max. Pitch Shift (semitones)", 280, 160, 40,
					{d.fBuildArrPitchShifts; d.guiData.pitchShiftBackView.refresh;}),
				PopUpMenu().fixedSize_(70 @ 22)
				.items_(["presets"]
					++ [48, 36, 24, "12 (default)", 7, 5, 4, 3, 2, 1, 0.5, 0.25, 0.1, 0.05, 0.025, 0.01]
					.collect({arg item; item.asString}))
				.stringColor_(Color.black).background_(Color.white)
				.value_(0)
				.action_({arg view;
					if (view.value > 0, {
						d.maxShift = [48, 36, 24, 12, 7, 5, 4, 3, 2, 1, 0.5, 0.25, 0.1, 0.05, 0.025, 0.01]
						.at(view.value - 1);
						d.fBuildArrPitchShifts;
						d.guiData.pitchShiftBackView.refresh;
						d.rebuildWindow;
					});
				}),
				10,
				StaticText().string_("Quantise curve to nearest semitone").align_(\center)
				.fixedSize_(210 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.fQuantisePitchShifts;
					d.rebuildWindow;
				}),
				10,
				StaticText().string_("Load default Pitch Shift settings").align_(\center)
				.fixedSize_(190 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.fLoadDefaultPitchShiftSettings;
					d.rebuildWindow;
				}),
				nil,
			).spacing_(14),
			HLayout(
				d.guiData.pitchShiftBackView,
				nil,
			),
			HLayout(
				// buttons
				d.guiData.pitchShiftCurveHistRow,
				// Show Image checkbox
				Button().states_([
					["[ ] Show Image", d.colButton, Color.white],
					["[X] Show Image", Color.white, d.colButton]])
				.fixedSize_(100 @ 22)
				.action_({arg view;
					d.showBackgroundImage = view.value.asBoolean;
					d.rebuildWindow;
				})
				.value_(d.showBackgroundImage.binaryValue),
				StaticText().string_("Reset").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.arrPitchShifts = 1 ! d.arrPitchShifts.size;
					d.arrNormPitchShifts = 0.5 ! d.arrNormPitchShifts.size;
					d.guiData.pitchShiftMultiSliderView.value_(d.arrNormPitchShifts);
					d.guiData.pitchShiftBackView.refresh;
					d.fAddToCurveHistory('arrNormPitchShifts');
				}),
				StaticText().string_("Smooth").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.arrNormPitchShifts = d.arrNormPitchShifts.size.collect({arg i;
						[-1, 0, 1].collect({arg item; d.arrNormPitchShifts.clipAt(i + item)}).mean;
					});
					d.fBuildArrPitchShifts;
					d.guiData.pitchShiftMultiSliderView.value_(d.arrNormPitchShifts);
					d.guiData.pitchShiftBackView.refresh;
					d.fAddToCurveHistory('arrNormPitchShifts');
				}),
				StaticText().string_("Smooth 5").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					5.do({
						d.arrNormPitchShifts = d.arrNormPitchShifts.size.collect({arg i;
							[-1, 0, 1].collect({arg item; d.arrNormPitchShifts.clipAt(i + item)}).mean;
						});
					});
					d.fBuildArrPitchShifts;
					d.guiData.pitchShiftMultiSliderView.value_(d.arrNormPitchShifts);
					d.guiData.pitchShiftBackView.refresh;
					d.fAddToCurveHistory('arrNormPitchShifts');
				}),
				StaticText().string_("Invert").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.arrNormPitchShifts = 1 - d.arrNormPitchShifts;
					d.fBuildArrPitchShifts;
					d.guiData.pitchShiftMultiSliderView.value_(d.arrNormPitchShifts);
					d.guiData.pitchShiftBackView.refresh;
					d.fAddToCurveHistory('arrNormPitchShifts');
				}),
				StaticText().string_("Reverse").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.arrNormPitchShifts = d.arrNormPitchShifts.reverse;
					d.arrPitchShifts = d.arrPitchShifts.reverse;
					d.guiData.pitchShiftMultiSliderView.value_(d.arrNormPitchShifts);
					d.guiData.pitchShiftBackView.refresh;
					d.fAddToCurveHistory('arrNormPitchShifts');
				}),
				// preset PitchShiftCurves popup
				PopUpMenu()
				.fixedSize_(160 @ 26)
				.items_(presetPitchShiftCurves.flop.slice(0))
				.stringColor_(Color.black).background_(d.colButton.blend(Color.white, 0.6))
				.value_(0)
				.action_({arg view;
					if (view.value > 0, {
						d.arrNormPitchShifts = presetPitchShiftCurves.flop.slice(1)[view.value].value;
						d.fBuildArrPitchShifts;
						d.guiData.pitchShiftMultiSliderView.value_(d.arrNormPitchShifts);
						d.guiData.pitchShiftBackView.refresh;
						d.fAddToCurveHistory('arrNormPitchShifts');
						view.value = 0;
					});
				}),
				// Actions popup
				PopUpMenu()
				.fixedSize_(160 @ 26)
				.items_(pitchShiftCurveActions.flop.slice(0))
				.stringColor_(Color.black).background_(d.colButton.blend(Color.white, 0.6))
				.value_(0)
				.action_({arg view;
					pitchShiftCurveActions.flop.slice(1)[view.value].value;
					d.fBuildArrPitchShifts;
					d.guiData.pitchShiftMultiSliderView.value_(d.arrNormPitchShifts);
					d.guiData.pitchShiftBackView.refresh;
					d.fAddToCurveHistory('arrNormPitchShifts');
					view.value = 0;
				}),
				nil,
			),
			nil,
		).spacing_(16);
	};  // end of d.makePitchShiftRow

	d.makePitchShiftLayout = {
		// prepare views
		d.makeSonogramRow;
		d.makeImageSelectRow;
		d.makePlayRow;
		d.makePixelSizeRow;
		d.makeTimeGridRow;
		d.makePitchShiftRow;
		// put edit view on top of sonogram
		d.guiData.sonogramEditView = UserView(parent: d.guiData.sonogramView).background_(Color.clear)
		.fixedSize_((d.imageWidth * d.pixelWidth) @ (d.imageHeight * d.pixelHeight))
		.drawFunc_({arg view;
			if (d.showTimeGrid, {
				Pen.use{
					var spacing = view.bounds.width / d.timeGridSteps;
					Pen.smoothing_(false);
					(d.timeGridSteps + 1).do({arg i;
						var x = i * spacing;
						Pen.color = Color(1, 1, 1, 0.6);
						Pen.line(Point(x, 0), Point(x, view.bounds.height));
						Pen.stroke;
						Pen.color = Color(0, 0, 0, 0.6);
						Pen.line(Point(x+1, 0), Point(x+1, view.bounds.height));
						Pen.line(Point(x-1, 0), Point(x-1, view.bounds.height));
						Pen.stroke;
					});
				};
			});
		});
		d.guiData.pitchShiftLayout = VLayout(
			HLayout(d.guiData.imageSelectRow, d.guiData.playRow, nil),
			[d.guiData.sonogramRow, align: \left],
			HLayout(
				StaticText().string_("Pitch Shift").align_(\center)
				.fixedSize_(90 @ 30)
				.stringColor_(d.colLabelString).background_(d.colLabel),
				20,
				// Use Pitch Shift checkbox
				Button().states_([
					["[ ] Use Pitch Shift", d.colButton, Color.white],
					["[X] Use Pitch Shift", Color.white, d.colButton]])
				.fixedSize_(120 @ 26)
				.action_({arg view;
					d.usePitchShift = view.value.asBoolean;
					d.rebuildWindow;
				})
				.value_(d.usePitchShift.binaryValue),
				20,
				[d.pixelSizeRow, align: \center],
				20,
				[d.guiData.timeGridRow, align: \center],
				nil,
			),
			[d.guiData.pitchShiftRow, align: \left],
			nil,  // spacer
		).spacing_(10);
	};

	d.makeTimeStretchRow = {
		var tableSize = d.arrNormTimeStretches.size;
		var linearArray = Array.interpolation(tableSize, 0.0, 1.0);
		var presetTimeStretchCurves = [
			["Preset Curves ...", {d.arrNormTimeStretches}],
			["Centre Line (default)", 0.5 ! tableSize],
			["Pulse 25%",
				{tableSize.collect({arg i; [0, 1][(i < (tableSize / 4)).binaryValue]});}],
			["Pulse 33.33%",
				{tableSize.collect({arg i; [0, 1][(i < (tableSize / 3)).binaryValue]});}],
			["Pulse 50%",
				{tableSize.collect({arg i; [0, 1][(i < (tableSize / 2)).binaryValue]});}],
			["Ramp Up", linearArray],
			["Ramp Down", linearArray.reverse],
			["Triangle", { var holdArr;
				holdArr = Array.newClear(tableSize/2).seriesFill(0, 2 / (tableSize - 1));
				holdArr ++ holdArr.copy.reverse;}],
			["Sine", {
				var arr = Signal.sineFill(tableSize-1,
					[1.0],[0.0]).collect({arg item, i; (item.value + 1) * 0.5;});
				arr = arr.add(arr[0]);
			}],
			["Cosine", {
				var arr = Signal.sineFill(tableSize-1,
					[1.0],[0.5pi]).collect({arg item, i; (item.value + 1) * 0.5;});
				arr = arr.add(arr[0]);
			}],
			["Exponential", {linearArray.collect({arg item, i;
				ControlSpec(0.001, 1, \exp).map(item).linlin(0.001, 1, 0, 1)});}],
			["-Exponential", {linearArray.collect({arg item, i;
				1-ControlSpec(0.001, 1, \exp).map(1-item).linlin(0.001, 1, 0, 1)});}],
			["Curve +1", {linearArray.collect({arg item, i; ControlSpec(0, 1, 1).map(item); });}],
			["Curve +2", {linearArray.collect({arg item, i; ControlSpec(0, 1, 2).map(item); });}],
			["Curve +3", {linearArray.collect({arg item, i; ControlSpec(0, 1, 3).map(item); });}],
			["Curve +4", {linearArray.collect({arg item, i; ControlSpec(0, 1, 4).map(item); });}],
			["Curve +5", {linearArray.collect({arg item, i; ControlSpec(0, 1, 5).map(item); });}],
			["Curve +6", {linearArray.collect({arg item, i; ControlSpec(0, 1, 6).map(item); });}],
			["Curve +7", {linearArray.collect({arg item, i; ControlSpec(0, 1, 7).map(item); });}],
			["Curve +8", {linearArray.collect({arg item, i; ControlSpec(0, 1, 8).map(item); });}],
			["Curve +9", {linearArray.collect({arg item, i; ControlSpec(0, 1, 9).map(item); });}],
			["Curve +10", {linearArray.collect({arg item, i; ControlSpec(0, 1, 10).map(item); });}],
			["Curve -1", {linearArray.collect({arg item, i; ControlSpec(0, 1, -1).map(item); });}],
			["Curve -2", {linearArray.collect({arg item, i; ControlSpec(0, 1, -2).map(item); });}],
			["Curve -3", {linearArray.collect({arg item, i; ControlSpec(0, 1, -3).map(item); });}],
			["Curve -4", {linearArray.collect({arg item, i; ControlSpec(0, 1, -4).map(item); });}],
			["Curve -5", {linearArray.collect({arg item, i; ControlSpec(0, 1, -5).map(item); });}],
			["Curve -6", {linearArray.collect({arg item, i; ControlSpec(0, 1, -6).map(item); });}],
			["Curve -7", {linearArray.collect({arg item, i; ControlSpec(0, 1, -7).map(item); });}],
			["Curve -8", {linearArray.collect({arg item, i; ControlSpec(0, 1, -8).map(item); });}],
			["Curve -9", {linearArray.collect({arg item, i; ControlSpec(0, 1, -9).map(item); });}],
			["Curve -10", {linearArray.collect({arg item, i; ControlSpec(0, 1, -10).map(item); });}],
		];
		// prepare curve actions
		var fitCurveToPlayLength = {
			var tempArr, absMax;
			tempArr = d.arrNormTimeStretches - 0.5;
			// adjust average
			tempArr = tempArr - tempArr.mean;
			// scale if needed to keep within range
			absMax = tempArr.abs.maxItem;
			if (absMax > 0.49, {
				tempArr = tempArr * 0.49 / absMax;
			});
			d.arrNormTimeStretches = tempArr + 0.5;
		};
		var multiCopy = { arg count;
			d.arrNormTimeStretches = d.arrNormTimeStretches.dup(count).flat.resamp0(d.arrNormTimeStretches.size);
		};
		var shiftPhase = { arg shift;
			var startIndex, tempArr;
			var size = d.arrNormTimeStretches.size;
			if ((shift > 0) && (shift < 1), {
				tempArr = d.arrNormTimeStretches.deepCopy;
				startIndex = (shift * (d.arrNormTimeStretches.size-1)).asInteger;
				d.arrNormTimeStretches = tempArr[startIndex..] ++ tempArr[..(startIndex-1)];
			});
		};
		var mirrorInvert = {
			var oldArray, startVal, midArray, endVal, newArray;
			oldArray = d.arrNormTimeStretches.deepCopy;
			startVal = oldArray.first.asArray;
			midArray = oldArray.drop(2).drop(-2);
			if ((midArray.size % 2) == 1, {
				midArray = midArray.add(oldArray.last);
			});
			midArray = midArray.clump(2).collect({arg item, i; item.sum/2;});
			endVal = oldArray.last.asArray;
			newArray = startVal ++ midArray ++ endVal;
			newArray = ((newArray - 1) ++ (newArray.copy.reverse.neg + 1)).madd(0.5, 0.5);
			if (newArray.size >  d.arrNormTimeStretches.size, {
				newArray.removeAt((newArray.size/2).asInteger);
			});
			d.arrNormTimeStretches = newArray;
		};
		var	timeStretchCurveActions = [
			[ "Modify curve ...", {}],
			[ "Adjust curve to keep original Play Length", {fitCurveToPlayLength.value}],
			[ "Mirror curve", {d.arrNormTimeStretches =
				(d.arrNormTimeStretches ++ d.arrNormTimeStretches.reverse).resamp1(tableSize);}],
			[ "Inverted Mirror curve", {mirrorInvert.value}],
			[ "Normalize curve", {d.arrNormTimeStretches = d.arrNormTimeStretches.normalize;}],
			[ "2X - Double copy", {multiCopy.value(2);}],
			[ "3X - Triple copy", {multiCopy.value(3);}],
			[ "4X - Quad copy", {multiCopy.value(4);}],
			[ "Bipolar to unipolar",
				{d.arrNormTimeStretches = d.arrNormTimeStretches.linlin(0.0, 1.0, 0.5, 1.0);}],
			[ "Bipolar to negative unipolar",
				{d.arrNormTimeStretches = d.arrNormTimeStretches.linlin(0.0, 1.0, 0.0, 0.5);}],
			[ "Phase shift 1/16 = 6.25 % = 22.5 deg", {shiftPhase.value(0.0625);}],
			[ "Phase shift 1/8 = 12.5 % = 45 deg", {shiftPhase.value(0.125);}],
			[ "Phase shift 1/6 = 16.66 % = 60 deg", {shiftPhase.value(6.reciprocal);}],
			[ "Phase shift 1/4 = 25 % = 90 deg", {shiftPhase.value(0.25);}],
			[ "Phase shift 1/3 = 33.33 % = 120 deg", {shiftPhase.value(3.reciprocal);}],
			[ "Phase shift 1/2 = 50 % = 180 deg", {shiftPhase.value(0.5);}],
			[ "Phase shift 2/3 = 66.66 % = 240 deg", {shiftPhase.value(2.0/3.0);}],
			[ "Phase shift 3/4 = 75 % = 270 deg", {shiftPhase.value(0.75);}],
		];
		// build views
		d.guiData.timeStretchBackView = UserView()
		.background_(Color.white)
		.drawFunc_({arg view;
			var unmappedVals = (0, 0.125..1);
			var mappedVals = unmappedVals.linlin(0, 1, d.maxStretch, d.minStretch);
			var maxY = view.bounds.height - 1;
			var playLengthString;
			if (d.showBackgroundImage, {
				d.showBackgroundImage = true;
				d.arrImages[d.imageIndex].smooth = true;
				Pen.drawImage(Rect(0, 0, view.bounds.width, view.bounds.height),
					d.arrImages[d.imageIndex], operation: 'sourceOver', opacity:1);
			});
			Pen.color = Color.black;
			unmappedVals.do({arg val, i;
				var posY = maxY - (val * maxY);
				var string = "Stretch:" + mappedVals[i].round(0.001).asString;
				var stringY = (posY - 12).min(view.bounds.height - 16).max(3);
				if (val == 0.5, {
					Pen.color = Color.red(0.4);
				}, {
					Pen.color = Color.grey(0.25);
				});
				Pen.line(0 @ posY, (view.bounds.width - 1) @ posY);
				Pen.stroke;
				Pen.stringAtPoint(string, 4 @ stringY);
			});
			if (d.showTimeGrid, {
				Pen.use{
					var spacing = view.bounds.width / d.timeGridSteps;
					Pen.color = Color.black;
					Pen.smoothing_(false);
					(d.timeGridSteps + 1).do({arg i;
						var x = i * spacing;
						Pen.line(Point(x, 0), Point(x, view.bounds.height));
						Pen.stroke;
					});
				};
			});
			if (d.mouseIsDown.asBoolean, {
				2.do({arg i;
					Pen.color = [Color.black, Color.white][i];
					Pen.line(Point((d.mouseX ? 0) + i, 0), Point((d.mouseX ? 0) + i, view.bounds.height));
					Pen.line(Point(0, (d.mouseY ? 0) + i), Point( view.bounds.width, (d.mouseY ? 0) + i));
					Pen.stroke;
				});
			});
		});
		d.guiData.timeStretchMultiSliderView = MultiSliderView(d.guiData.timeStretchBackView)
		.fixedSize_((d.imageWidth * d.pixelWidth).max(360) @ 230).elasticMode_(1)
		.drawLines_(true).drawRects_(false).isFilled_(true)
		.reference_(0.5 ! d.arrNormTimeStretches.size)
		.background_(Color(1, 1, 1, 0)).fillColor_(Color(0.8, 0.92, 1, 0.25))
		.value_(d.arrNormTimeStretches)
		.mouseDownAction_({arg view, x, y;
			d.mouseIsDown = true;
			d.mouseX = x; d.mouseY = y;
			d.guiData.timeStretchBackView.refresh;
		})
		.mouseMoveAction_({arg view, x, y;
			d.mouseX = x; d.mouseY = y;
			d.mouseIsDown = true;
			d.guiData.timeStretchBackView.refresh;
		})
		.mouseUpAction_({arg view;
			d.arrNormTimeStretches = view.value;
			d.buildArrTimeStretches;
			d.guiData.timeStretchBackView.refresh;
			d.fAddToCurveHistory('arrNormTimeStretches');
			d.mouseIsDown = false;
			d.guiData.timeStretchBackView.refresh;
		});
		d.guiData.timeStretchBackView.fixedSize_(d.guiData.timeStretchMultiSliderView.bounds.extent);
		d.guiData.timeStretchCurveHistRow = d.makeCurveHistoryRow('arrNormTimeStretches', {d.buildArrTimeStretches});
		d.guiData.curveRateMultiRow = d.fEZNumBox(ControlSpec(1, 32,), 'timeStretchRateMulti',
			"Curve rate multiply", 110, 40);
		d.guiData.curveRateMultiRow = d.guiData.curveRateMultiRow.add(PopUpMenu().fixedSize_(70 @ 22)
			.items_(["presets"] ++ (1..32).collect({arg item; item.asString}))
			.stringColor_(Color.black).background_(Color.white)
			.value_(0)
			.action_({arg view;
				if (view.value > 0, {
					d.timeStretchRateMulti = view.value;
				});
				d.rebuildWindow;
			})
		);
		d.guiData.timeStretchRow = VLayout(
			4,
			HLayout(
				d.fEZSlider(ControlSpec(1.01, 1.9), 'maxStretch', "Max. stretch", 240, 80, 40, {
					d.minStretch = 1 - (d.maxStretch - 1);
					d.buildArrTimeStretches;
					d.guiData.timeStretchBackView.refresh;
				}),
				d.guiData.curveRateMultiRow,
				10,
				StaticText().string_("Load Default Time Stretch Settings").align_(\center)
				.fixedSize_(200 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.fLoadDefaultTimeStretchSettings;
					d.rebuildWindow;
				}),
				nil,
			).spacing_(30),
			HLayout(
				d.guiData.timeStretchBackView,
				nil,
			),
			HLayout(
				// buttons
				d.guiData.timeStretchCurveHistRow,
				// Show Image checkbox
				Button().states_([
					["[ ] Show Image", d.colButton, Color.white],
					["[X] Show Image", Color.white, d.colButton]])
				.fixedSize_(100 @ 22)
				.action_({arg view;
					d.showBackgroundImage = view.value.asBoolean;
					d.rebuildWindow;
				})
				.value_(d.showBackgroundImage.binaryValue),
				StaticText().string_("Reset").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.arrTimeStretches = 1 ! d.arrTimeStretches.size;
					d.arrNormTimeStretches = 0.5 ! d.arrNormTimeStretches.size;
					d.guiData.timeStretchMultiSliderView.value_(d.arrNormTimeStretches);
					d.guiData.timeStretchBackView.refresh;
					d.fAddToCurveHistory('arrNormTimeStretches');
				}),
				StaticText().string_("Smooth").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.arrNormTimeStretches = d.arrNormTimeStretches.size.collect({arg i;
						[-1, 0, 1].collect({arg item; d.arrNormTimeStretches.clipAt(i + item)}).mean;
					});
					d.buildArrTimeStretches;
					d.guiData.timeStretchMultiSliderView.value_(d.arrNormTimeStretches);
					d.guiData.timeStretchBackView.refresh;
					d.fAddToCurveHistory('arrNormTimeStretches');
				}),
				StaticText().string_("Smooth 5").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					5.do({
						d.arrNormTimeStretches = d.arrNormTimeStretches.size.collect({arg i;
							[-1, 0, 1].collect({arg item; d.arrNormTimeStretches.clipAt(i + item)}).mean;
						});
					});
					d.buildArrTimeStretches;
					d.guiData.timeStretchMultiSliderView.value_(d.arrNormTimeStretches);
					d.guiData.timeStretchBackView.refresh;
					d.fAddToCurveHistory('arrNormTimeStretches');
				}),
				StaticText().string_("Invert").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.arrNormTimeStretches = 1 - d.arrNormTimeStretches;
					d.buildArrTimeStretches;
					d.guiData.timeStretchMultiSliderView.value_(d.arrNormTimeStretches);
					d.guiData.timeStretchBackView.refresh;
					d.fAddToCurveHistory('arrNormTimeStretches');
				}),
				StaticText().string_("Reverse").align_(\center)
				.fixedSize_(70 @ 22)
				.stringColor_(Color.white).background_(d.colButton)
				.mouseDownAction_({
					d.arrNormTimeStretches = d.arrNormTimeStretches.reverse;
					d.arrTimeStretches = d.arrTimeStretches.reverse;
					d.guiData.timeStretchMultiSliderView.value_(d.arrNormTimeStretches);
					d.guiData.timeStretchBackView.refresh;
					d.fAddToCurveHistory('arrNormTimeStretches');
				}),
				// preset TimeStretchCurves popup
				PopUpMenu()
				.fixedSize_(160 @ 26)
				.items_(presetTimeStretchCurves.flop.slice(0))
				.stringColor_(Color.black).background_(d.colButton.blend(Color.white, 0.6))
				.value_(0)
				.action_({arg view;
					if (view.value > 0, {
						d.arrNormTimeStretches = presetTimeStretchCurves.flop.slice(1)[view.value].value;
						d.buildArrTimeStretches;
						d.guiData.timeStretchMultiSliderView.value_(d.arrNormTimeStretches);
						d.guiData.timeStretchBackView.refresh;
						d.fAddToCurveHistory('arrNormTimeStretches');
						view.value = 0;
					});
				}),
				// Actions popup
				PopUpMenu()
				.fixedSize_(160 @ 26)
				.items_(timeStretchCurveActions.flop.slice(0))
				.stringColor_(Color.black).background_(d.colButton.blend(Color.white, 0.6))
				.value_(0)
				.action_({arg view;
					timeStretchCurveActions.flop.slice(1)[view.value].value;
					d.buildArrTimeStretches;
					d.guiData.timeStretchMultiSliderView.value_(d.arrNormTimeStretches);
					d.guiData.timeStretchBackView.refresh;
					d.fAddToCurveHistory('arrNormTimeStretches');
					view.value = 0;
				}),
				nil,
			),
			nil,
		).spacing_(16);
	};  // end of d.makeTimeStretchRow

	d.buildArrTimeStretches = {
		d.arrTimeStretches = d.arrNormTimeStretches.linlin(0, 1, d.maxStretch, d.minStretch);
	};

	d.makeTimeStretchLayout = {
		// prepare views
		d.makeSonogramRow;
		d.makeImageSelectRow;
		d.makePlayRow;
		d.makePixelSizeRow;
		d.makeTimeGridRow;
		d.makeTimeStretchRow;
		// put edit view on top of sonogram
		d.guiData.sonogramEditView = UserView(parent: d.guiData.sonogramView).background_(Color.clear)
		.fixedSize_((d.imageWidth * d.pixelWidth) @ (d.imageHeight * d.pixelHeight))
		.drawFunc_({arg view;
			if (d.showTimeGrid, {
				Pen.use{
					var spacing = view.bounds.width / d.timeGridSteps;
					Pen.smoothing_(false);
					(d.timeGridSteps + 1).do({arg i;
						var x = i * spacing;
						Pen.color = Color(1, 1, 1, 0.6);
						Pen.line(Point(x, 0), Point(x, view.bounds.height));
						Pen.stroke;
						Pen.color = Color(0, 0, 0, 0.6);
						Pen.line(Point(x+1, 0), Point(x+1, view.bounds.height));
						Pen.line(Point(x-1, 0), Point(x-1, view.bounds.height));
						Pen.stroke;
					});
				};
			});
		});
		d.guiData.timeStretchLayout = VLayout(
			HLayout(d.guiData.imageSelectRow, d.guiData.playRow, nil),
			[d.guiData.sonogramRow, align: \left],
			HLayout(
				StaticText().string_("Time Stretch").align_(\center)
				.fixedSize_(100 @ 30)
				.stringColor_(d.colLabelString).background_(d.colLabel),
				20,
				// Use Time Stretch checkbox
				Button().states_([
					["[ ] Use Time Stretch", d.colButton, Color.white],
					["[X] Use Time Stretch", Color.white, d.colButton]])
				.fixedSize_(120 @ 26)
				.action_({arg view;
					d.useTimeStretch = view.value.asBoolean;
					d.rebuildWindow;
				})
				.value_(d.useTimeStretch.binaryValue),
				20,
				[d.pixelSizeRow, align: \center],
				20,
				[d.guiData.timeGridRow, align: \center],
				nil,
			),
			[d.guiData.timeStretchRow, align: \left],
			nil,  // spacer
		).spacing_(10);
	};

	d.makeWarpRow = {
		var tableSize = d.warpCurve.size;
		var linearArray = Array.interpolation(tableSize, 0.0, 1.0);
		var presetWarpCurves = [
			["Preset Curves ...", {d.warpCurve}],
			["Ramp Up (default)", linearArray],
			["Ramp Down", linearArray.reverse],
			["Triangle", { var holdArr;
				holdArr = Array.newClear(tableSize/2).seriesFill(0, 2 / (tableSize - 1));
				holdArr ++ holdArr.copy.reverse;}],
			["Sine", {
				var arr = Signal.sineFill(tableSize-1,
					[1.0],[0.0]).collect({arg item, i; (item.value + 1) * 0.5;});
				arr = arr.add(arr[0]);
			}],
			["Cosine", {
				var arr = Signal.sineFill(tableSize-1,
					[1.0],[0.5pi]).collect({arg item, i; (item.value + 1) * 0.5;});
				arr = arr.add(arr[0]);
			}],
			["Exponential", {linearArray.collect({arg item, i;
				ControlSpec(0.001, 1, \exp).map(item).linlin(0.001, 1, 0, 1)});}],
			["-Exponential", {linearArray.collect({arg item, i;
				1-ControlSpec(0.001, 1, \exp).map(1-item).linlin(0.001, 1, 0, 1)});}],
			["Curve +1", {linearArray.collect({arg item, i; ControlSpec(0, 1, 1).map(item); });}],
			["Curve +2", {linearArray.collect({arg item, i; ControlSpec(0, 1, 2).map(item); });}],
			["Curve +3", {linearArray.collect({arg item, i; ControlSpec(0, 1, 3).map(item); });}],
			["Curve +4", {linearArray.collect({arg item, i; ControlSpec(0, 1, 4).map(item); });}],
			["Curve +5", {linearArray.collect({arg item, i; ControlSpec(0, 1, 5).map(item); });}],
			["Curve +6", {linearArray.collect({arg item, i; ControlSpec(0, 1, 6).map(item); });}],
			["Curve +7", {linearArray.collect({arg item, i; ControlSpec(0, 1, 7).map(item); });}],
			["Curve +8", {linearArray.collect({arg item, i; ControlSpec(0, 1, 8).map(item); });}],
			["Curve +9", {linearArray.collect({arg item, i; ControlSpec(0, 1, 9).map(item); });}],
			["Curve +10", {linearArray.collect({arg item, i; ControlSpec(0, 1, 10).map(item); });}],
			["Curve -1", {linearArray.collect({arg item, i; ControlSpec(0, 1, -1).map(item); });}],
			["Curve -2", {linearArray.collect({arg item, i; ControlSpec(0, 1, -2).map(item); });}],
			["Curve -3", {linearArray.collect({arg item, i; ControlSpec(0, 1, -3).map(item); });}],
			["Curve -4", {linearArray.collect({arg item, i; ControlSpec(0, 1, -4).map(item); });}],
			["Curve -5", {linearArray.collect({arg item, i; ControlSpec(0, 1, -5).map(item); });}],
			["Curve -6", {linearArray.collect({arg item, i; ControlSpec(0, 1, -6).map(item); });}],
			["Curve -7", {linearArray.collect({arg item, i; ControlSpec(0, 1, -7).map(item); });}],
			["Curve -8", {linearArray.collect({arg item, i; ControlSpec(0, 1, -8).map(item); });}],
			["Curve -9", {linearArray.collect({arg item, i; ControlSpec(0, 1, -9).map(item); });}],
			["Curve -10", {linearArray.collect({arg item, i; ControlSpec(0, 1, -10).map(item); });}],
		];
		// prepare curve actions
		var multiCopy = { arg count;
			d.warpCurve = d.warpCurve.dup(count).flat.resamp0(d.warpCurve.size);
		};
		var shiftPhase = { arg shift;
			var startIndex, tempArr;
			var size = d.warpCurve.size;
			if ((shift > 0) && (shift < 1), {
				tempArr = d.warpCurve.deepCopy;
				startIndex = (shift * (d.warpCurve.size-1)).asInteger;
				d.warpCurve = tempArr[startIndex..] ++ tempArr[..(startIndex-1)];
			});
		};
		var mirrorInvert = {
			var oldArray, startVal, midArray, endVal, newArray;
			oldArray = d.warpCurve.deepCopy;
			startVal = oldArray.first.asArray;
			midArray = oldArray.drop(2).drop(-2);
			if ((midArray.size % 2) == 1, {
				midArray = midArray.add(oldArray.last);
			});
			midArray = midArray.clump(2).collect({arg item, i; item.sum/2;});
			endVal = oldArray.last.asArray;
			newArray = startVal ++ midArray ++ endVal;
			newArray = ((newArray - 1) ++ (newArray.copy.reverse.neg + 1)).madd(0.5, 0.5);
			if (newArray.size >  d.warpCurve.size, {
				newArray.removeAt((newArray.size/2).asInteger);
			});
			d.warpCurve = newArray;
		};
		var	warpCurveActions = [
			[ "Modify curve ...", {}],
			[ "Mirror curve", {d.warpCurve =
				(d.warpCurve ++ d.warpCurve.reverse).resamp1(tableSize);}],
			[ "Inverted Mirror curve", {mirrorInvert.value}],
			[ "Normalize curve", {d.warpCurve = d.warpCurve.normalize;}],
			[ "2X - Double copy", {multiCopy.value(2);}],
			[ "3X - Triple copy", {multiCopy.value(3);}],
			[ "4X - Quad copy", {multiCopy.value(4);}],
			[ "Phase shift 1/16 = 6.25 % = 22.5 deg", {shiftPhase.value(0.0625);}],
			[ "Phase shift 1/8 = 12.5 % = 45 deg", {shiftPhase.value(0.125);}],
			[ "Phase shift 1/6 = 16.66 % = 60 deg", {shiftPhase.value(6.reciprocal);}],
			[ "Phase shift 1/4 = 25 % = 90 deg", {shiftPhase.value(0.25);}],
			[ "Phase shift 1/3 = 33.33 % = 120 deg", {shiftPhase.value(3.reciprocal);}],
			[ "Phase shift 1/2 = 50 % = 180 deg", {shiftPhase.value(0.5);}],
			[ "Phase shift 2/3 = 66.66 % = 240 deg", {shiftPhase.value(2.0/3.0);}],
			[ "Phase shift 3/4 = 75 % = 270 deg", {shiftPhase.value(0.75);}],
		];
		d.guiData.warpBackView = UserView()
		.background_(Color.white)
		.drawFunc_({arg view;
			var vWidth = view.bounds.width;
			var vHeight = view.bounds.height;
			Pen.color = Color.black;
			Pen.line(0 @ vHeight, vWidth  @ 0);
			Pen.stroke;
			8.do({arg i;
				var gap = 8.reciprocal;
				var string = d.arrFreqs[(gap * i * (d.arrFreqs.size - 1)).asInteger]
				.round.asInteger.asString;
				var left = gap * i * (vWidth - 1);
				var stringLeft = 3 + left.max(3);
				var top = gap * i * (vHeight - 1);
				var stringTop = top + 16;
				Pen.color = Color.grey;
				Pen.line(left @ 3, left @ (vHeight - 1));
				Pen.line(3 @ (vHeight - top), (vWidth - 1) @ (vHeight - top));
				Pen.stroke;
				Pen.color = Color.black;
				Pen.stringAtPoint(string, stringLeft @ 5);
				Pen.stringAtPoint(string, 5 @ (vHeight - stringTop));
			});
		});
		d.guiData.warpMultiSliderView = MultiSliderView(d.guiData.warpBackView)
		.fixedSize_(404 @ 404).elasticMode_(1)
		.drawLines_(true).drawRects_(false).isFilled_(true)
		.background_(Color(1, 1, 1, 0)).fillColor_(Color(0.8, 0.92, 1, 0.5))
		.value_(d.warpCurve)
		.mouseUpAction_({arg view;
			d.warpCurve = view.value;
			d.fBuildArrOutFreqs;
			d.fAddToCurveHistory('warpCurve');
		});
		d.guiData.warpBackView.fixedSize_(d.guiData.warpMultiSliderView.bounds.extent);
		d.guiData.warpCurveHistRow = d.makeCurveHistoryRow('warpCurve', {d.fBuildArrOutFreqs});
		d.guiData.warpRow = VLayout(
			4,
			HLayout(
				VLayout(
					StaticText().string_("Freq Warp").align_(\center)
					.fixedSize_(90 @ 30)
					.stringColor_(d.colLabelString).background_(d.colLabel),
					// Use Warp checkbox
					Button().states_([
						["[ ] Use Warp", d.colButton, Color.white],
						["[X] Use Warp", Color.white, d.colButton]])
					.fixedSize_(90 @ 26)
					.action_({arg view;
						d.useWarp = view.value.asBoolean;
						d.fBuildArrOutFreqs;
						d.rebuildWindow;
					})
					.value_(d.useWarp.binaryValue),
					10,
					// buttons
					HLayout(8, d.guiData.warpCurveHistRow, 30),
					StaticText().string_("Reset").align_(\center)
					.fixedSize_(70 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({
						d.warpCurve = Array.interpolation(d.warpCurve.size, 0, 1);
						d.guiData.warpMultiSliderView.value_(d.warpCurve);
						d.fBuildArrOutFreqs;
						d.fAddToCurveHistory('warpCurve');
					}),
					StaticText().string_("Smooth").align_(\center)
					.fixedSize_(70 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({
						d.warpCurve = d.warpCurve.size.collect({arg i;
							[-1, 0, 1].collect({arg item; d.warpCurve.clipAt(i + item)}).mean;
						});
						d.guiData.warpMultiSliderView.value_(d.warpCurve);
						d.fBuildArrOutFreqs;
						d.fAddToCurveHistory('warpCurve');
					}),
					StaticText().string_("Smooth 5").align_(\center)
					.fixedSize_(70 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({
						5.do({
							d.warpCurve = d.warpCurve.size.collect({arg i;
								[-1, 0, 1].collect({arg item; d.warpCurve.clipAt(i + item)}).mean;
							});
						});
						d.guiData.warpMultiSliderView.value_(d.warpCurve);
						d.fBuildArrOutFreqs;
						d.fAddToCurveHistory('warpCurve');
					}),
					StaticText().string_("Invert").align_(\center)
					.fixedSize_(70 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({
						d.warpCurve = 1 - d.warpCurve;
						d.guiData.warpMultiSliderView.value_(d.warpCurve);
						d.guiData.warpBackView.refresh;
						d.fBuildArrOutFreqs;
						d.fAddToCurveHistory('warpCurve');
					}),
					StaticText().string_("Reverse").align_(\center)
					.fixedSize_(70 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({
						d.warpCurve = d.warpCurve.reverse;
						d.guiData.warpMultiSliderView.value_(d.warpCurve);
						d.guiData.warpBackView.refresh;
						d.fBuildArrOutFreqs;
						d.fAddToCurveHistory('warpCurve');
					}),
					nil,
				).spacing_(10),
				d.guiData.warpBackView,
				VLayout(
					StaticText().string_(" Min. Freq:" + d.arrFreqs.first.round.asInteger
						+ "   Max. Freq:" + d.arrFreqs.last.round.asInteger)
					.fixedSize_(280 @ 22).align_(\left)
					.stringColor_(d.colLabelString).background_(d.colButton.blend(Color.white, 0.9)),
					20,
					// presetWarpCurves popup
					PopUpMenu()
					.fixedSize_(280 @ 26)
					.items_(presetWarpCurves.flop.slice(0))
					.stringColor_(Color.black).background_(d.colButton.blend(Color.white, 0.6))
					.value_(0)
					.action_({arg view;
						if (view.value > 0, {
							d.warpCurve = presetWarpCurves.flop.slice(1)[view.value].value;
							d.fBuildArrOutFreqs;
							d.guiData.warpMultiSliderView.value_(d.warpCurve);
							d.guiData.warpBackView.refresh;
							d.fAddToCurveHistory('warpCurve');
							view.value = 0;
						});
					}),
					// warpCurveActions popup
					PopUpMenu()
					.fixedSize_(280 @ 26)
					.items_(warpCurveActions.flop.slice(0))
					.stringColor_(Color.black).background_(d.colButton.blend(Color.white, 0.6))
					.value_(0)
					.action_({arg view;
						warpCurveActions.flop.slice(1)[view.value].value;
						d.fBuildArrOutFreqs;
						d.guiData.warpMultiSliderView.value_(d.warpCurve);
						d.guiData.warpBackView.refresh;
						d.fAddToCurveHistory('warpCurve');
						view.value = 0;
					}),
					nil,
				).spacing_(20),
				nil,
			).spacing_(10),
			nil,
		).spacing_(10);
	};  // end of d.makeWarpRow

	d.makeWarpLayout = {
		// prepare views
		d.makeSonogramRow(false);
		d.makeImageSelectRow;
		d.makePlayRow;
		d.makePixelSizeRow;
		d.makeWarpRow;
		d.guiData.warpLayout = VLayout(
			HLayout(d.guiData.imageSelectRow, d.guiData.playRow, nil),
			[d.guiData.sonogramRow, align: \left],
			[d.guiData.warpRow, align: \left],
			nil,  // spacer
		).spacing_(10);
	};

	d.makeFXLayout = {
		// prepare views
		d.makeSonogramRow;
		d.makeImageSelectRow;
		d.makePlayRow;
		d.makePixelSizeRow;
		d.guiData.fxBox = VLayout(
			UserView().fixedHeight_(2).background_(Color.white),
			HLayout(
				VLayout(
					d.fEZSlider(ControlSpec(0, 1), 'delayMix', "Delay Mix", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('delayMix', val)}),
					d.fEZSlider(ControlSpec(0.01, 5, 2), 'delayL', "Delay Time L", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('delayL', val)}),
					d.fEZSlider(ControlSpec(0.01, 5, 2), 'delayR', "Delay Time R", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('delayR', val)}),
				).spacing_(8),
				20,
				VLayout(
					HLayout(
						StaticText().string_("Load Default Delay Settings").align_(\center)
						.fixedSize_(180 @ 22)
						.stringColor_(Color.white).background_(d.colButton)
						.mouseDownAction_({
							d.fLoadDefaultDelaySettings;
							d.rebuildWindow;
						}),
						10,
						StaticText().string_("Copy Delay L to Delay R").align_(\center)
						.fixedSize_(160 @ 22)
						.stringColor_(Color.white).background_(d.colButton)
						.mouseDownAction_({
							d.fCopyDelayL2DelayR;
							d.rebuildWindow;
						}),
						nil,
					),
					d.fEZSlider(ControlSpec(0.01, 30, 2), 'decayTimeL', "Decay Time L", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('decayTimeL', val)}),
					d.fEZSlider(ControlSpec(0.01, 30, 2), 'decayTimeR', "Decay Time R", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('decayTimeR', val)}),
				).spacing_(8),
				nil,
			),
			UserView().fixedHeight_(2).background_(Color.white),
			HLayout(
				VLayout(
					d.fEZSlider(ControlSpec(0, 1), 'reverbMix', "Reverb Mix", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('reverbMix', val)}),
					d.fEZSlider(ControlSpec(0.01, 20, 'exp'), 'reverbTime', "Decay Time", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('reverbTime', val)}),
					d.fEZSlider(ControlSpec(0.5, 5, warp: 2), 'reverbSize', "Room Size", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('reverbSize', val)}),
					d.fEZSlider(ControlSpec(0, 1), 'reverbEarlyRef', "Early Reflections", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('reverbEarlyRef', val)}),
					d.fEZSlider(ControlSpec(0, 1), 'reverbDamp', "Damping", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('reverbDamp', val)}),
					d.fEZSlider(ControlSpec(0, 1), 'reverbModDepth', "Modulation Depth", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('reverbModDepth', val)}),
					d.fEZSlider(ControlSpec(0, 10), 'reverbModFreq', "Modulation Freq", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('reverbModFreq', val)}),
					nil,
				).spacing_(8),
				20,
				VLayout(
					StaticText().string_("Load Default Reverb Settings").align_(\center)
					.fixedSize_(180 @ 22)
					.stringColor_(Color.white).background_(d.colButton)
					.mouseDownAction_({
						d.fLoadDefaultReverbSettings;
						d.rebuildWindow;
					}),
					d.fEZSlider(ControlSpec(0, 1), 'reverbLow', "Bass Level", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('reverbLow', val)}),
					d.fEZSlider(ControlSpec(0, 1), 'reverbMid', "Mid  Level", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('reverbMid', val)}),
					d.fEZSlider(ControlSpec(0, 1), 'reverbHigh', "High Level", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('reverbHigh', val)}),
					d.fEZSlider(ControlSpec(100, 6000, 'exp'), 'reverbLoCutFreq', "Lo Cut Freq", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('reverbLoCutFreq', val)}),
					d.fEZSlider(ControlSpec(1000, 10000, 'exp'), 'reverbHiCutFreq', "Hi  Cut Freq", 300, 110, 50,
						{arg val; d.fSetImageSynthVal('reverbHiCutFreq', val)}),
					nil,
				).spacing_(8),
				nil,
			),
			nil,
		).spacing_(8);
		d.guiData.fxLayout = VLayout(
			HLayout(d.guiData.imageSelectRow, d.guiData.playRow, nil),
			[d.guiData.sonogramRow, align: \left],
			HLayout(
				StaticText().string_("FX: Delay --> Reverb").align_(\center)
				.fixedSize_(150 @ 24)
				.stringColor_(d.colLabelString).background_(d.colLabel),
				// Use FX checkbox
				Button().states_([
					["[ ] Use FX", d.colButton, Color.white],
					["[X] Use FX", Color.white, d.colButton]])
				.fixedSize_(90 @ 26)
				.action_({arg view;
					d.useFX = view.value.asBoolean;
					d.fBuildArrOutFreqs;
					if (d.imageSynth.notNil, {
						d.imageSynth.set('useFX', d.useFX.binaryValue);
					});
					d.rebuildWindow;
				})
				.value_(d.useFX.binaryValue),
				d.pixelSizeRow,
				nil,
			).spacing_(20),
			[d.guiData.fxBox, align: \left],
			nil,  // spacer
		).spacing_(10);
	};
	// end of d.makeFXLayout

	d.makeRecordingLayout = {
		var holdLength;
		// prepare views
		d.makeSonogramRow;
		d.makeImageSelectRow;
		d.makePlayRow;
		d.makePixelSizeRow;
		d.guiData.recordFormatRow = HLayout(
			[StaticText().string_("Record Format*").align_(\center)
				.fixedSize_(130 @ 22)
				.stringColor_(d.colLabelString).background_(d.colLabel), align: \top],
			[ListView()
				.fixedSize_(140 @ 80)
				.items_(d.recordFormatOptions.flop.slice(0))
				.stringColor_(Color.black).background_(d.colLabel)
				.value_(d.recordFormatOptions.flop.slice(1).indexOfEqual(d.recordFormat))
				.action_({arg view;
					d.recordFormat = d.recordFormatOptions.flop.slice(1)[view.value];
				}),
				align: \top],
			VLayout(
				[HLayout(20, d.pixelSizeRow, nil),  align: \left],
				22,
				[StaticText().string_("* Choose Record Format before opening a record file").align_(\center)
					.fixedSize_(290 @ 22)
					.stringColor_(d.colLabelString).background_(d.colLabel), align: \left],
				nil,
			),
			nil,
		).spacing_(4);
		d.guiData.recordClockView = StaticText().align_(\center)
		.string_(d.recordClockTime)
		.fixedSize_(50 @ 22)
		.stringColor_(d.colLabelString).background_(Color.white);
		d.guiData.recordClockRow = HLayout(
			StaticText().string_("Record Clock").align_(\center)
			.fixedSize_(80 @ 22)
			.stringColor_(d.colLabelString).background_(d.colLabel),
			d.guiData.recordClockView,
		);
		d.guiData.recordingControlsRow = HLayout(
			// label
			StaticText().string_("Recording Controls").align_(\center)
			.fixedSize_(130 @ 22)
			.stringColor_(d.colLabelString).background_(d.colLabel),
			// Open Record File button
			StaticText().string_("Open Record File").align_(\center)
			.fixedSize_(120 @ 22)
			.stringColor_(Color.white).background_(d.colButton)
			.mouseDownAction_({d.fOpenRecordFile;}),
		).spacing_(10);
		if (d.recordingStatus == " Ready to Record", {
			d.guiData.recordingControlsRow.add(
				// Record button
				StaticText().string_("Record").align_(\center)
				.fixedSize_(60 @ 22)
				.stringColor_(Color.white).background_(d.colRecord)
				.mouseDownAction_({d.fStartRecording})
			);
			d.guiData.recordingControlsRow.add(
				// Stop button
				StaticText().string_("Stop").align_(\center)
				.fixedSize_(60 @ 22)
				.stringColor_(Color.white).background_(d.colStop)
				.mouseDownAction_({d.fStopSound; d.fStopRecording; d.rebuildWindow;})
			);
			d.guiData.recordingControlsRow.add(30);
			d.guiData.recordingControlsRow.add(d.guiData.recordClockRow);
		});
		d.guiData.recordingControlsRow.add(nil);
		// recordTime
		d.guiData.recordTimeNumbox = NumberBox().maxDecimals_(3)
		.fixedSize_(50 @ 22).background_(d.colHighlight)
		.value_(d.recordTime)
		.action_({arg view;
			d.recordTime = view.value;
			if (d.recordingSynth.notNil, {
				d.recordingSynth.set(\recordTime, d.recordTime);
			});
		});
		// Copy Play Length button
		d.guiData.copyPlayLengthButton = StaticText()
		.string_("Copy Play Length:" + d.playLength.round(0.01) + "s")
		.align_(\center)
		.fixedSize_(170 @ 22)
		.stringColor_(Color.white).background_(d.colButton)
		.mouseDownAction_({d.recordTime = d.playLength; d.rebuildWindow;});
		if (d.useTimeStretch, {
			// holdLength = (d.playLength / d.arrTimeStretches.mean);
			// d.guiData.copyPlayLengthButton = StaticText()
			// .string_("Copy Play Length with Time Stretch:" + holdLength.round(0.01) + "s")
			// .align_(\center)
			// .fixedSize_(260 @ 22)
			// .stringColor_(Color.white).background_(d.colButton)
			// .mouseDownAction_({d.recordTime = holdLength; d.rebuildWindow;});
			d.guiData.playLengthWarning = StaticText()
			.string_("Note: Using Time Stretch will affect the play length.")
			.align_(\center)
			.fixedSize_(280 @ 22)
			.stringColor_(Color.black).background_(Color.white);
		}, {
			d.guiData.playLengthWarning = nil;
		});
		d.guiData.recordTimeRow = HLayout(
			StaticText().string_("Max. Record Time").align_(\center)
			.fixedSize_(130 @ 22)
			.stringColor_(d.colLabelString).background_(d.colLabel),
			d.guiData.recordTimeNumbox,
			PopUpMenu()
			.fixedSize_(110 @ 22)
			.items_(d.recordTimePresets.flop.slice(0))
			.stringColor_(Color.black).background_(d.colLabel)
			.value_(0)
			.action_({arg view;
				if (view.value != 0, {
					d.recordTime = d.recordTimePresets.flop.slice(1)[view.value];
					d.rebuildWindow;
				});
			}),
			// +5 button
			StaticText().string_("+5 secs").align_(\center)
			.fixedSize_(50 @ 22)
			.stringColor_(Color.white).background_(d.colButton)
			.mouseDownAction_({d.recordTime = d.recordTime + 5; d.rebuildWindow;}),
			d.guiData.copyPlayLengthButton,
			d.guiData.playLengthWarning,
			nil,
		).spacing_(6);
		// recordingStatus
		d.guiData.recordingStatusView = StaticText().align_(\left)
		.string_(" " ++ d.recordingStatus)
		.fixedSize_(500 @ 22)
		.stringColor_(d.colLabelString).background_(d.colHighlight);
		d.guiData.recordingStatusRow = HLayout(
			StaticText().string_("Recording Status").align_(\center)
			.fixedSize_(130 @ 22)
			.stringColor_(d.colLabelString).background_(d.colLabel),
			d.guiData.recordingStatusView,
			nil,
		).spacing_(4);
		// currentFile
		d.guiData.currentFileView = StaticText().align_(\left)
		.string_(" " ++ d.currentRecFileName)
		.fixedSize_(800 @ 32)
		.stringColor_(d.colLabelString).background_(Color.white);
		d.guiData.currentFileRow = HLayout(
			StaticText().string_("Current Record File").align_(\center)
			.fixedSize_(130 @ 32)
			.stringColor_(d.colLabelString).background_(d.colLabel),
			d.guiData.currentFileView,
			nil,
		).spacing_(4);
		// previousFile
		d.guiData.previousFileView = StaticText().align_(\left)
		.string_(" " ++ d.previousRecFileName)
		.fixedSize_(800 @ 32)
		.stringColor_(d.colLabelString).background_(Color.white);
		d.guiData.previousFileRow = HLayout(
			StaticText().string_("Previous Record File").align_(\center)
			.fixedSize_(130 @ 32)
			.stringColor_(d.colLabelString).background_(d.colLabel),
			d.guiData.previousFileView,
			nil,
		).spacing_(4);
		d.guiData.recordingBox= VLayout(
			d.guiData.recordFormatRow,
			d.guiData.recordTimeRow,
			d.fEZSlider(ControlSpec(0, 2), 'recordingLevel', "Recording Level", 300, 130, 40,
				{arg val; d.fSetImageSynthVal('recordingLevel', val)}).add(nil),
			UserView().fixedHeight_(2).background_(Color.white),
			d.guiData.recordingStatusRow,
			d.guiData.recordingControlsRow,
			d.guiData.currentFileRow,
			d.guiData.previousFileRow,
			nil,  // spacer
		).spacing_(12);
		d.guiData.imageLayout = VLayout(
			HLayout(d.guiData.imageSelectRow, d.guiData.playRow, nil),
			5, // spacer
			[d.guiData.sonogramRow, align: \left],
			5, // spacer
			[d.guiData.recordingBox, align: \left],
			nil,  // spacer
		).spacing_(10);
	};
	// end of d.makeRecordingLayout

	d.rebuildWindow = {
		// remove all previous views
		if (d.guiData.window.layout.notNil, {
			d.guiData.window.view.removeAll;
		});
		// tabs row
		d.guiData.tabsRow = HLayout ();
		d.guiData.tabsRow.add(
			UserView().background_(Color.gray(0.6))
			.fixedHeight_(34)
			.layout_(HLayout (
				// Settings button
				[StaticText().string_("Settings").align_(\center)
					.fixedSize_(58 @ 22)
					.stringColor_(Color.black).background_(d.fGetDisplayTabCol(\settings,
						d.colHighlight2))
					.mouseDownAction_({
						if (d.isRecording, {
							d.fShowError("Warning: Cannot change Settings, Sound or Image during recording.");
						}, {
							d.fStopSound;
							d.fCheckBuildSynthDef;
							d.displayTab = \settings;
							d.rebuildWindow;
						});
				}), align: \top],
				[StaticText().string_("Sound").align_(\center)
					.fixedSize_(44 @ 22)
					.stringColor_(Color.black).background_(d.fGetDisplayTabCol(\soundSource,
						d.colHighlight2))
					.mouseDownAction_({
						if (d.isRecording, {
							d.fShowError("Warning: Cannot change Settings, Sound or Image during recording.");
						}, {
							d.fStopSound;
							d.fCheckBuildSynthDef;
							d.displayTab = \soundSource;
							d.rebuildWindow;
						});
				}), align: \top],
				[StaticText().string_("Image").align_(\center)
					.fixedSize_(44 @ 22)
					.stringColor_(Color.black).background_(d.fGetDisplayTabCol(\imageTools,
						d.colHighlight2))
					.mouseDownAction_({
						if (d.isRecording, {
							d.fShowError("Warning: Cannot change Settings, Sound or Image during recording.");
						}, {
							d.fCheckBuildSynthDef;
							d.displayTab = \imageTools;
							d.rebuildWindow;
						});
				}), align: \top],
				[HLayout (StaticText().string_("Env").align_(\center)
					.fixedSize_(30 @ 22)
					.stringColor_(Color.black).background_(d.fGetDisplayTabCol(\env,
						d.colHighlight2))
					.mouseDownAction_({
						d.fCheckBuildSynthDef;
						d.displayTab = \env;
						d.rebuildWindow;
					}),
					StaticText().fixedSize_(3 @ 22)
					.background_([Color.white, Color.green(0.95)][d.useEnv.binaryValue])
				).spacing_(1), align: \top],
				[HLayout (StaticText().string_("EQ").align_(\center)
					.fixedSize_(30 @ 22)
					.stringColor_(Color.black).background_(d.fGetDisplayTabCol(\eq,
						d.colHighlight2))
					.mouseDownAction_({
						d.fCheckBuildSynthDef;
						d.displayTab = \eq;
						d.rebuildWindow;
					}),
					StaticText().fixedSize_(3 @ 22)
					.background_([Color.white, Color.green(0.95)][d.useEQ.binaryValue])
				).spacing_(1), align: \top],
				[HLayout (StaticText().string_("Warp").align_(\center)
					.fixedSize_(40 @ 22)
					.stringColor_(Color.black).background_(d.fGetDisplayTabCol(\warp,
						d.colHighlight2))
					.mouseDownAction_({
						d.fCheckBuildSynthDef;
						d.displayTab = \warp;
						d.rebuildWindow;
					}),
					StaticText().fixedSize_(3 @ 22)
					.background_([Color.white, Color.green(0.95)][d.useWarp.binaryValue])
				).spacing_(1), align: \top],
				[HLayout (StaticText().string_("Time Stretch").align_(\center)
					.fixedSize_(74 @ 22)
					.stringColor_(Color.black).background_(d.fGetDisplayTabCol(\timeStretch,
						d.colHighlight2))
					.mouseDownAction_({
						d.fCheckBuildSynthDef;
						d.displayTab = \timeStretch;
						d.rebuildWindow;
					}),
					StaticText().fixedSize_(3 @ 22)
					.background_([Color.white, Color.green(0.95)][d.useTimeStretch.binaryValue])
				).spacing_(1), align: \top],
				[HLayout (StaticText().string_("Pitch Shift").align_(\center)
					.fixedSize_(62 @ 22)
					.stringColor_(Color.black).background_(d.fGetDisplayTabCol(\pitchShift,
						d.colHighlight2))
					.mouseDownAction_({
						d.fCheckBuildSynthDef;
						d.displayTab = \pitchShift;
						d.rebuildWindow;
					}),
					StaticText().fixedSize_(3 @ 22)
					.background_([Color.white, Color.green(0.95)][d.usePitchShift.binaryValue])
				).spacing_(1), align: \top],
				[HLayout (StaticText().string_("FX").align_(\center)
					.fixedSize_(30 @ 22)
					.stringColor_(Color.black).background_(d.fGetDisplayTabCol(\fx,
						d.colHighlight2))
					.mouseDownAction_({
						d.fCheckBuildSynthDef;
						d.displayTab = \fx;
						d.rebuildWindow;
					}),
					StaticText().fixedSize_(3 @ 22)
					.background_([Color.white, Color.green(0.95)][d.useFX.binaryValue])
				).spacing_(1), align: \top],
				[HLayout (StaticText().string_("Record").align_(\center)
					.fixedSize_(50 @ 22)
					.stringColor_(Color.black).background_(d.fGetDisplayTabCol(\recording,
						d.colHighlight2))
					.mouseDownAction_({
						d.fCheckBuildSynthDef;
						d.displayTab = \recording;
						d.rebuildWindow;
					}),
					StaticText().fixedSize_(3 @ 22)
					.background_([Color.white, Color.red(0.95)][d.isRecording.binaryValue])
				).spacing_(1), align: \top],
			).margins_(7).spacing_(7))
		);
		// Volume slider & numbox
		d.guiData.volumeSlider = Slider().thumbSize_(8).orientation_(\horizontal)
		.fixedSize_(150 @ 22)
		.background_(Color.white).knobColor_(d.colButton)
		.action_({arg view;
			d.volume = view.value;
			d.guiData.volumeNumbox.value_(d.volume);
			d.fSetAnalysisVol(view.value);
		})
		.value_(d.volume);
		d.guiData.volumeNumbox = NumberBox().maxDecimals_(2)
		.fixedSize_(34 @ 22)
		.action_({arg view;
			d.volume = view.value.clip(0, 1);
			d.guiData.volumeSlider.value = d.volume;
			d.fSetAnalysisVol(d.volume);
		})
		.value_(d.volume);

		// File Actions popup
		d.guiData.fileActionPopup = PopUpMenu()
		.fixedSize_(90 @ 26)
		.stringColor_(Color.black).background_(d.colButton.blend(Color.white, 0.6))
		.value_(0)
		.action_({arg view;
			d.fileActions.flop.slice(1)[view.value].value;
			view.value = 0;
		});
		// only show project actions if image isn't shown
		if (d.displayTab == \settings or: {d.displayTab == \soundSource}, {
			d.guiData.fileActionPopup.items_(d.fileActions.keep(3).flop.slice(0))
		}, {
			d.guiData.fileActionPopup.items_(d.fileActions.flop.slice(0))
		});
		// Top Row of controls
		d.guiData.topRow = HLayout(
			d.guiData.tabsRow,
			// Help button
			StaticText().string_("Help").align_(\center)
			.fixedSize_(46 @ 26)
			.stringColor_(Color.white).background_(d.colHelp)
			.mouseDownAction_({d.showHelpWindow}),
			d.guiData.fileActionPopup,
			HLayout(
				// label
				StaticText().string_("Volume").align_(\center)
				.fixedSize_(56 @ 26)
				.stringColor_(d.colLabelString).background_(d.colLabel),
				// volume slider/numbox
				d.guiData.volumeSlider,
				d.guiData.volumeNumbox,
			).spacing_(2),
			// Window on top checkbox
			Button().states_([
				["[ ] Window on top", d.colButton, Color.white],
				["[X] Window on top", Color.white, d.colButton]])
			.fixedSize_(110 @ 26)
			.action_({arg view;
				var val = view.value.asBoolean;
				d.alwaysOnTop = val;
				d.guiData.window.alwaysOnTop = val;
			})
			.value_(d.alwaysOnTop.binaryValue)
		).spacing_(12);
		if (d.displayTab == \imageTools, {
			d.guiData.topRow.add(
				// Clear Image button
				StaticText().string_("Clear Image").align_(\center)
				.fixedSize_(76 @ 26)
				.stringColor_(Color.white).background_(d.colClearImage)
				.mouseDownAction_({d.fClearImage}),
			);
		});
		d.guiData.topRow.add(nil);

		// assemble window layout
		d.guiData.window.layout = VLayout(
			2, // spacer
			d.guiData.topRow,
			2, // spacer
		).margins_(([12, 6, 12, 10]));
		case
		{d.displayTab == \settings} {
			d.makeSettingsLayout;
			d.guiData.window.layout.add(d.guiData.settingsLayout);
		}
		{d.displayTab == \soundSource} {
			d.makeSoundLayout;
			d.guiData.window.layout.add(d.guiData.settingsLayout);
		}
		{d.displayTab == \imageTools} {
			d.makeImageToolsLayout;
			d.guiData.window.layout.add(d.guiData.imageLayout);
		}
		{d.displayTab == \eq} {
			d.makeEQLayout;
			d.guiData.window.layout.add(d.guiData.eqLayout);
		}
		{d.displayTab == \env} {
			d.makeEnvLayout;
			d.guiData.window.layout.add(d.guiData.envLayout);
		}
		{d.displayTab == \warp} {
			d.makeWarpLayout;
			d.guiData.window.layout.add(d.guiData.warpLayout);
		}
		{d.displayTab == \timeStretch} {
			d.makeTimeStretchLayout;
			d.guiData.window.layout.add(d.guiData.timeStretchLayout);
		}
		{d.displayTab == \pitchShift} {
			d.makePitchShiftLayout;
			d.guiData.window.layout.add(d.guiData.pitchShiftLayout);
		}
		{d.displayTab == \fx} {
			d.makeFXLayout;
			d.guiData.window.layout.add(d.guiData.fxLayout);
		}
		{d.displayTab == \recording} {
			d.makeRecordingLayout;
			d.guiData.window.layout.add(d.guiData.imageLayout);
		};
		d.guiData.window.layout.add(nil);
	};
	// end of d.rebuildWindow

	d.makeGui = {
		var w = d.guiData.window;  // store window if present
		d.guiData = ();  //  clear old data
		Font.default = Font("Helvetica", 12);
		d.guiData.titleFont =  Font("Helvetica", 13);
		d.guiData.window = w; // restore window
		// create window if needed
		if (d.guiData.window.isNil or: {d.guiData.window.isClosed}, {
			d.guiData.window = Window(
				"TX Image Synth App",
				Rect(10, Window.availableBounds.height - d.windowHeight - 40, d.windowWidth,  d.windowHeight),
			).front;
			w = d.guiData.window;
			w.view.resize_(5);
			w.view.background_(d.colWindow);
			w.alwaysOnTop = d.alwaysOnTop;
			w.onClose_({
				d.fStopSound;
				d.fStopRecording;
				d.fFreeAllResources;
			});
		}, {
			d.guiData.window.front.view.removeAll;
		});
		// add layout
		d.rebuildWindow;
	};
	// end of d.makeGui

	d.deferMakeGui = {
		{
			s.sync;
			{d.makeGui}.defer(0.05);
		}.forkIfNeeded(AppClock);
	};

	// help window
	d.showHelpWindow = {
		{ // defer
			// create window if needed
			if (d.guiData.helpWindow.isNil, {
				d.guiData.helpWindow = Window(
					"Help for TX Image Synth App",
					Rect(10, Window.availableBounds.height - d.windowHeight - 10, 600,  600),
					scroll: true
				).front;
				d.guiData.helpWindow.alwaysOnTop = d.alwaysOnTop;
				d.guiData.helpWindow.view.resize_(5);
				d.guiData.helpWindow.view.background_(Color.white);
				d.guiData.helpWindow.onClose_({
					d.guiData.helpWindow = nil;
				});
				// StaticText(d.guiData.helpWindow.view, d.guiData.helpWindow.bounds)
				StaticText(d.guiData.helpWindow.view, Rect(10, 10, 580, 1750))
				// .align_(\left)
				.resize_(5)
				.stringColor_(Color.black).background_(Color.white)
				.font_(Font("Helvetica", 14))
				.string_("\n\nTX Image Synth App\n\n\n"
					++ "Intro\n\n"
					++ "- This tool is for generating sounds based on images used as sonograms.\n\n"
					++ "- Images can be created by analysing a sound file, by importing an existing image file, or by drawing coloured lines or shapes using the image tools provided.\n\n"
					++ "- Image files can be saved or imported, Sound files can be recorded, and Project files with all the current settings can be saved and opened.\n\n"
					++ "- For each sonogram image, the pixel rows represent a set of frequencies with the lowest frequency at the bottom and the pixel columns represent slices of time. So each pixel represents a frequency at a particular time.\n\n"
					++ "- The brightness of the pixel represents the loudness of the sound, and the colour of the pixel represents some aspects of the sound - depending on the sound settings. The colour might control the stereo position of the sound or modulate the sound synthesis is some way.\n\n"
					++ "- The sonogram image can be synthesised using filtered noise, sine waves, phase modulation synthesis or wavetable synthesis. EQ, frequency warping, time stretching, pitch shifting, delay and reverb can be added.\n\n\n"
					++ "Settings Tab\n"
					++ "Play Length is in seconds or beats with a BPM.\n"
					++ "Random Seed can be changed to give a different set of values wherever randomness is used, such as random voice detune or random panning.\n"
					++ "Choose the size of the image and which frequencies to use.\n"
					++ "The Freq Keyboard lets you hear the frequencies chosen by dragging a mouse.\n"
					++ "Frequency Mode sets how the frequencies are chosen either based on MIDI notes, scales, harmonics, or using a linear or exponential frequency range.\n"
					++ "If scales are used, various tuning options are also given.\n"
					++ "Amp Compensation reduces the level of higher frequencies where human hearing is more sensitive to give a more balanced overall spectrum. The frequency balance can also be adjusted in greater detail using the EQ tab - see below.\n\n"
					++ "Sound Tab\n"
					++ "Choose a Sound Source for synthesis when playing or recording the image and a Stereo Mode.\n"
					++ "Depending on the option chosen, the colour of each pixel may control an aspect of the sound or its stereo position.\n"
					++ "Phase modulation - also sometimes called Frequency Modulation uses two sine waves with the second one modulating the phase/frequency of the first.\n"
					++ "The ratio between the frequencies of the first and second sines can either be fixed or modulatable (option Phase Mode Sines 2). The blueness of the pixels will increase the modulation depth. If option Phase Mode Sines 2 is chosen, the redness of the pixels will increase the modulating sine wave’s frequency ratio.\n"
					++ "If a Wavetables sound source is chosen, the interface lets you draw in the harmonics of 3 wavetables. The blueness of the pixels will morph between the tables.\n"
					++ "In the two Sound Source options named “[something] + Filtered Noise”, the redness of the pixels will mix between a synthesised waveform and filtered noise at the same frequency.\n\n"
					++ "Image Tab\n"
					++ "Image 1/ Image 2 - choose which image to work with. Having two images gives some flexibility, such as using one image as a sketch book to try things out.\n"
					++ "Rewind/Play@Start/ Play/ Stop - control playback of the image.\n"
					++ "Loop - for repeated playback of the image.\n"
					++ "Store/Load/Delete Snapshot - uses copies of the current image. Useful for saving an image before editing, so you easily reload it if needed.\n\n"
					++ "Image Tools:\n"
					++ "Analysis - open a mono or stereo file and convert it to an image by playing the file and analysing the frequencies chosen in the Settings tab.\n"
					++ "Blur - adds blur in vertical or horizontal directions.\n"
					++ "Colorize - drag over a region to change its color (hue and saturation) keeping its original brightness (i.e. dark areas stay dark).\n"
					++ "Copy, Cut, Paste - drag to select a region, then copy, cut, paste, invert or reverse the selection. Paste includes many further options including horizontal or vertical repeats.\n"
					++ "Compression - drag to select a region, then apply gating, expansion/compression (using negative/positive curve) and limiting with optional gain compensation.\n"
					++ "Drag Draw - drag over a region to draw a chosen shape. Each shape has different options.\n"
					++ "Paint - drag over a region to paint single or multiple shapes.\n"
					++ "Perlin Noise - paint or colorize a selected region using Perlin Noise in single or multiple colours.\n"
					++ "Scale Filter - This tool only works with 12-semitone Chromatic scales. After choosing a scale or interval or chord, drag over a region of the image. This will remove any frequencies that aren't part of the chosen scale by painting their pixels black. If the Invert Scale switch is on, only frequencies that are part of the scale will be removed.\n\n"
					++ "Env Tab\n"
					++ "With Env switched on, cut or boost sound levels along the timeline.\n\n"
					++ "EQ Tab\n"
					++ "With EQ switched on, cut or boost chosen frequencies to change the overall balance of the sound.\n\n"
					++ "Warp Tab\n"
					++ "With Warp switched on, all the frequencies are mapped to a new set of frequencies depending on the shape of the curve. This can drastically change the sound spectrum. Press Reset for the default upwards ramp curve.\n\n"
					++ "Time Stretch Tab\n"
					++ "With Time Stretch switched on, the time taken for each pixel can be stretched or squashed by drawing in the curve. This can produce gradual or sudden speed changes. The 'Curve rate multiply' slider will decide how many times the curve will be applied over the whole play length (default is 1).\n\n"
					++ "Pitch Shift Tab\n"
					++ "With Pitch Shift switched on, pitch changes can be drawn in along the timeline. It has a settable range between +-0.01 and +-48 semitones.\n\n"
					++ "FX Tab\n"
					++ "Delay and Reverb can be mixed into the sound.\n\n"
					++ "Record Tab\n"
					++ "Choose a recording format, open a new file to record to, then record the sound of the image.\n"
					++ "While recording, you can't change the image settings.\n\n"
					++ "Thanks\n"
					++ "This app was developed from code originally shared by PyoungRyang Ko on SuperCollider Forum thread:\n"
					++ "// https://scsynth.org/t/a-sketch-to-make-an-image-filter-similar-to-the-image-filter-in-audiosculpt/10317\n"
					++ "Big thanks to all who share their code.\n\n"
					++ "Created by Paul Miller (palemoonrising.co.uk)\n\n\n"
				)
			}, {
				d.guiData.helpWindow.front;
			});
		}.defer;
	};  // end of d.showHelpWindow

};  // end of d.fDefineGUIFunctions

d.fDefineGUIFunctions; // run function

// ========  Starting App ===========

// start server if needed
s = Server.default;
s.options.numWireBufs = 1024;  // because default too small
s.waitForBoot({
	fork{
		// init
		d.fAllocUpdateWTBuffers;
		d.fPrepareScaleData;
		d.fUpdateScaleData;
		d.fBuildArrFreqs;
		d.fBuildImageSynthDef;
		d.fCreateImages;
		d.fInitAllCurveHistories;
		// start gui
		d.deferMakeGui;
	};
});
"---  Starting Image Sonify ...".postln;
"";
)