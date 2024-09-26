macro "filaments" {
	// Uses BioVoxxel, BIOP (PTBIOP) and MorpholibJ plugins (can be installed through update sites)
	// Requires Cellpose and its integration with Fiji - https://github.com/BioImaging-NKI/Cellpose-Fiji
	
	/* This macro measures length of filaments touching (or very close to) cells. It was developed 
	for type-3 secretion system of bacteria. Filaments are manually traced and measured cell-by-cell,
	manual tracing for each cell can be repeated any number of steps to allow for sequential 
	measurement of crossing filaments, any number of filaments can be traced in each step. As only 
	the maximum length is recorded, it is not suitable for branched filaments. Attempt was made to 
	make this macro as user-friendly as possible. Detailed use instructions are at the end.
	 */
	//Jan Valečka, Light Microscopy Facility, IMG CAS, 2024-07-12, jan.valecka@img.cas.cz
	
	// parameters to be set
	channelBacteria = 1; // channel with bacteria body staining
	channelToSkeletonize = 2; // channel with filaments staining
	surroundings = 3; // pixels around bacteria counting as bacteria when checking filaments (px)
	bacteriaDiameterCellpose = 35; // diameter parameter from cellpose, saying roughly how many pixels the bacteria measure (px)
	cutoutSize = 300; // size of a window containing surroundings of a cell that should have all filaments (px)
	lineWidth = 4; // width of a line used for manual drawing of the filaments (to be skeletonized for analysis)
	closeResults = false; // whether to close results when analysis is finished
	zoomCutout = 300; // zoom factor of a window containing surroundings of a cell containing all filaments (default 300)
	minSize = 200; // minimum size to consider segmented object a cell (px)
	
	
	saveSettings();
	initialize(); // changing settings to make macro work consistently on various ImageJs
	
	title = getTitle();
	name = substring(title, 0, lastIndexOf(title, "."));
	getDimensions(widthFull, heightFull, channelsFull, slicesFull, framesFull);
	directory = getInfo("image.directory");
	File.makeDirectory(directory+"results");
	run("Select None");
	setBatchMode(true);
	
	// results recording preparations
	Table.create("Measurements");
	Table.setLocationAndSize(screenWidth-250, screenHeight-600, 200, 550);
	Table.create("Summarisation");
	Table.setLocationAndSize(screenWidth-1050, screenHeight-250, 800, 200);
	nCells = 0; // cell counter // mělo by stačit variable n
	nFilaments = 0; // filament counter
	newImage("Measured filaments", "8-bit black", widthFull, heightFull, 1); // image for aggregating skeletons of manually drawn filaments, the actually measured objects
	
	// image preparation
	selectWindow(title);
	Property.set("CompositeProjection", "Sum");
	Stack.setDisplayMode("composite");
	run("Z Project...", "projection=[Max Intensity]");
	rename("projection");
	close(title);
	
	// preprocesing
	run("Split Channels");
	skeletonizeFilaments("C"+channelToSkeletonize+"-projection"); // creates an image called "skeleton" from a specified window by autothresholding, binarizing and skeletonizing
	createBacteriaMask("C"+channelBacteria+"-projection"); // creates an image called "bacteria_mask" from a specified image by thresholding and binarizing
	filterFilaments("bacteria_mask","skeleton"); // creates an image called "filtered_skeleton" which contains only skeletons of filaments attached to the bacteria
	makeDrawingImage(); // creates an image called "overview" that contains bacterial and filaments channels, "filtered_skeleton" as guidance, and an empty channel for manula drawing of filaments
	setBatchMode("exit and display");
	segmentBacteria("bacteria"); // segments individual bacteria using Cellpose for counting and locating them; includes manual removal of unsuitable bacteria by deleting them form a label image
	
	n = roiManager("count"); // number of bacterial cells to be analysed
	nFilaments = analyseAllCells(); // duplicates defined area around each cell sequentially, allows for manual drawing of filaments in an arbitrary number of steps, measures the hand-drawn filaments and records the values
	
	createSummary();
	saveResults();
	
	restoreSettings;
	showMessage("Analysis finished!", "Your results are in:\n"+directory+"results");	
}


function initialize() {
	// changing settings to make it work consistently on various ImageJs
	setOption("BlackBackground", true);
	run("Options...", "iterations=1 count=1 black do=Nothing"); //process>binary>options set to black background to avoid inverting LUT after thresholding
	run("Input/Output...", "jpeg=85 gif=-1 file=.csv copy_column copy_row save_column save_row"); // making sure column headers and row numbers are saved
	run("Colors...", "foreground=white background=black selection=yellow");
	run("Set Measurements...", "area mean standard min integrated median redirect=None decimal=3");
}


function skeletonizeFilaments(window) {
	// creates an image called "skeleton" from a specified window by autothresholding, binarizing and skeletonizing
	// the image is used to create a guidance image, not actually used for analysis
	selectWindow(window);
	run("Duplicate...", "title=skeleton");
	run("Gaussian Blur...", "sigma=1");
	setAutoThreshold("Otsu dark"); // IsoData and Otsu were most robust during testing, followed by Default, IJ_IsoDara and RenyiEntropy
	run("Convert to Mask");
	run("Skeletonize");
}


function createBacteriaMask(window) {
	// creates image called "bacteria_mask" from a specified image by thresholding and binarizing
	// the image is used for filtering out filaments not attached to cells
	selectWindow(window);
	run("Duplicate...", "title=bacteria_mask");
	run("Gaussian Blur...", "sigma=1");
	setAutoThreshold("Default dark");
	run("Convert to Mask");
	run("Fill Holes");
	run("EDM Binary Operations", "iterations="+surroundings+" operation=dilate"); // BioVoxxel
}


function filterFilaments(bacteria, skeleton) {
	// creates an image called "filtered_skeleton" which contains only skeletons of filaments attached to the bacteria
	// the image is used only as a guidance, not actually used for analysis
	minSize = 1; // minimal size of bacteria to exclude unattached filaments (µm²)
	
	imageCalculator("OR create", bacteria, skeleton);
	selectImage("Result of bacteria_mask");
	run("Analyze Particles...", "size="+minSize+"-Infinity show=Masks");
	run("Grays");
	imageCalculator("AND create", "Mask of Result of "+bacteria, skeleton);
	close("Result of "+bacteria);
	close("Mask of Result of "+bacteria);
	selectImage("Result of Mask of Result of "+bacteria);
	rename("filtered_skeleton");
	close(bacteria);
	close(skeleton);
}


function makeDrawingImage() {
	// creates an image called "overview" that contains bacterial and filaments channels, "filtered_skeleton" as guidance, and an empty channel for manual drawing of filaments
	selectImage("C"+channelBacteria+"-projection");
	run("Duplicate...", "title=bacteria");
	selectImage("C"+channelBacteria+"-projection");
	run("Enhance Contrast", "saturated=0.35");
	run("8-bit");
	selectImage("C"+channelToSkeletonize+"-projection");
	run("Enhance Contrast", "saturated=0.35");
	run("8-bit");
	newImage("temp", "8-bit black", widthFull, heightFull, 1);
	run("Merge Channels...", "c2=C"+channelToSkeletonize+"-projection c3=temp c7=filtered_skeleton c6=C"+channelBacteria+"-projection ignore create");
	run("Arrange Channels...", "new=3142");
	rename("overview");
}


function segmentBacteria(window) {
	// segments individual bacteria using Cellpose for counting and locating them
	// includes manual removal of unsuitable bacteria by deleting them form a label image
	selectWindow(window);
	run("8-bit");
	run("Subtract Background...", "rolling=10");
	// Cellpose (using BIOP):
	run("Cellpose Advanced", "diameter="+bacteriaDiameterCellpose+" cellproba_threshold=0.0 "
	+"flow_threshold=0.0 anisotropy=1.0 diam_threshold=12.0 model=cyto2 nuclei_channel=2 "
	+"cyto_channel=1 dimensionmode=2D stitch_threshold=-1.0 omni=false cluster=false additional_flags=");
	run("Label Size Filtering", "operation=Greater_Than size="+minSize);
	close(window+"-cellpose");
	rename(window+"-cellpose");
	removeCellsManually(window+"-cellpose") // manual removal of unsuitable bacteria by deleting them form a label image
	run("Label image to ROIs", "rm=[RoiManager[visible=true]]"); // BIOP
	close(window);
	close(window+"-cellpose");
}

function removeCellsManually(labelImage) {
	// manual removal of unsuitable bacteria by deleting them form a label image
	// label image is renumbered not to have any values missing
	selectWindow("overview");
	setLocation(100, 100);
	zoom = getZoom();
	selectWindow("bacteria-cellpose");
	setLocation(120+widthFull*zoom, 100);
	run("glasbey_on_dark");
	setTool("wand");
	waitForUser("Adjust label image", "Remove any labels not to be analysed,"
	+"\nfor example on the edges or too dense.\n\nWhen done, press OK.");
	run("Remap Labels"); // MorphoLibJ
	setTool("rectangle");
}


function analyseAllCells() {
	// duplicates defined area around each cell sequentially, allows for manual drawing of filaments in an arbitrary number of steps,
	// measures the hand-drawn filaments and records the values
	for (i = 0; i < n; i++) {
		selectWindow("overview");
		roiManager("Show All");
		roiManager("select", i);
		getSelectionBounds(xSelection, ySelection, widthSelection, heightSelection);
		Overlay.remove;
		Overlay.drawEllipse(xSelection+widthSelection/2, ySelection+heightSelection/2, 1, 1);
		Overlay.add;
		Overlay.show;
		xCutout = xSelection+widthSelection/2-cutoutSize/2;
		yCutout = ySelection+heightSelection/2-cutoutSize/2;
		makeRectangle(xCutout, yCutout, cutoutSize, cutoutSize);
		run("Duplicate...", "title=[cell "+i+1+" of "+n+"] duplicate");
		title2 = getTitle();
		run("Set... ", "zoom="+zoomCutout);
		setLocation(screenWidth/10, screenHeight/5);
		Stack.setChannel(4);
		while (isOpen(title2)) {
			selectWindow(title2);
			draw(); // drawing tool; handles logic for aribtrary stopping of drawing
			count = analyseFilament(); // skeletonizes manually-drawn filaments, measures them and returns the number of filaments drawn
			nFilaments = nFilaments + count;
			transferFilaments("drawn", "Measured filaments"); // copies skeletons drawn into a cropped image into a full-size image used for the record
			close("drawn");
			setTool("rectangle");
		}
		close("Drawing"); // tidying up
	}
	Overlay.remove;
	return nFilaments;
}

function draw() {
	// drawing tool
	// handles logic for aribtrary stopping of drawing
	alt=8;
	leftClick=16;
	tool = IJ.getToolName();
	setTool("freeline");
	Table.create("Drawing");
	Table.setLocationAndSize(screenWidth/10+(300*zoomCutout/100)+20, screenHeight/5, 320, 420);
	Table.set("Instructions", 0, "Draw line along the filament.");
	Table.set("Instructions", 1, "It will be skeletonized and measured.");
	Table.set("Instructions", 2, "Use alt to erase the line.");
	Table.set("Instructions", 3, "");
	Table.set("Instructions", 4, "You can draw multiple lines each time.");
	Table.set("Instructions", 5, "When drawing is done and want to");
	Table.set("Instructions", 6, "measure, close this window.");
	Table.set("Instructions", 7, "");
	Table.set("Instructions", 8, "When all filaments for this cell are");
	Table.set("Instructions", 9, "measured, close the image window");
	Table.set("Instructions", 10, "where you draw.");
	Table.set("Instructions", 11, "Don't save changes.");
	Table.update;
	setupUndo();
	setLineWidth(lineWidth);
	while (isOpen("Drawing") && isOpen(title2)) {
		setForegroundColor(255, 255, 255);
		getCursorLoc(x, y, z, flags);
		if (flags&leftClick==0) {
			moveTo(x,y);
			x2=-1; y2=-1;
			wait(10);
			continue;
		}
		if (flags&alt!=0) {
			setForegroundColor(0, 0, 0);
		}
		if (x!=x2 || y!=y2)
			lineTo(x,y);
		x2=x; y2 =y;
		wait(10);
	}
	setTool(tool);
}

function analyseFilament() {
	// skeletonizes manually-drawn filaments, measures them and returns the number of filaments drawn
	if (isOpen(title2)) {selectWindow(title2);}
	else {selectWindow("overview");}
	run("Duplicate...", "title=drawn duplicate channels=4");
	getStatistics(area, mean, min, max, std, histogram);
	if (max > 0) {
		run("Skeletonize");
		run("Analyze Skeleton (2D/3D)", "prune=none");
		close("Tagged skeleton");
		// manage results
		count = nResults;
		for (j = 0; j < count; j++) {
			line = Table.size("Measurements");
			length = getResult("Maximum Branch Length", j);
			Table.set("Cell no.", line, i+1, "Measurements"); // the i is correct, it is the currently porcessed cell
			Table.set("Length", line, length, "Measurements");
			Table.update("Measurements");
		}
		run("Clear Results");
		close("Results");
		selectWindow(title2);
		run("Select All");
		run("Clear", "slice");
	}
	else {
		count = 0;
	}
	return count;
}

function transferFilaments(sourceImage, targetImage) {
	// copies skeletons drawn into a cropped image into a full-size image used for the record
	// depends of variables from outside the function for correct placement in the full-size image
	selectWindow(sourceImage);
	getDimensions(width, height, channels, slices, frames);
	setPasteMode("copy");
	run("Select All");
	run("Copy");
	
	// ugly, non-general implementation of marking, which filaments were already drawn
	if (isOpen(title2)) {
		selectWindow(title2);
		Stack.setChannel(1);
	    setPasteMode("add");
		run("Paste");
		Stack.setChannel(4);
	}
	// end of the ugly bit
	
	selectWindow(targetImage);
	makeRectangle(maxOf(0, xCutout), maxOf(0, yCutout), width, height);
    setPasteMode("add");
	run("Paste");
	run("Select None");
}


function createSummary() {
	lengthsArray = Table.getColumn("Length", "Measurements");
	Array.getStatistics(lengthsArray, min, max, mean, stdDev);
	Table.set("Title", 0, title, "Summarisation");
	Table.set("Cells", 0, n, "Summarisation");
	cellsWithFilaments = countCellsWithFilaments();
	Table.set("Cells without filaments", 0, n-cellsWithFilaments, "Summarisation");
	Table.set("Cells with filaments", 0, cellsWithFilaments, "Summarisation");
	Table.set("Filaments", 0, nFilaments, "Summarisation");
	Table.set("Filaments per population", 0, nFilaments/n, "Summarisation");
	Table.set("Filaments per cell", 0, nFilaments/cellsWithFilaments, "Summarisation");
	Table.set("Average length", 0, mean, "Summarisation");
	Table.set("Length SD", 0, stdDev, "Summarisation");
	Table.set("Channel bacteria", 0, channelBacteria, "Summarisation");
	Table.set("Channel filaments", 0, channelToSkeletonize, "Summarisation");
	Table.set("Cellpose diameter", 0, bacteriaDiameterCellpose, "Summarisation");
	Table.update("Summarisation");	
}

function countCellsWithFilaments() {
	cellNumbers = Table.getColumn("Cell no.", "Measurements");
	cellsWithFilaments = 0;
	while (cellNumbers.length > 0) {
		number = cellNumbers[0];
		cellsWithFilaments++;
		cellNumbers = Array.deleteValue(cellNumbers, number);
		wait(2);
	}
	return cellsWithFilaments;
}


function saveResults() {
	Table.save(directory+"results"+File.separator+"Summary_"+name+".csv", "Summarisation");
	Table.save(directory+"results"+File.separator+"Measurements_"+name+".csv", "Measurements");
	selectImage("Measured filaments");
	run("ROIs to Label image");
	selectImage("ROIs2Label_Measured filaments");
	run("glasbey_on_dark");
	selectImage("overview");
	run("Split Channels");
	close();
	close();
	run("Merge Channels...", "c1=C1-overview c2=C2-overview c3=[Measured filaments] c4=[ROIs2Label_Measured filaments] create");
	saveAs("Tiff", directory+"results"+File.separator+"Overview_"+name);
	if (closeResults) {
		close("Summarisation");
		close("Measurements");
		close("Overview_"+name+".tif");
	}
}

/*
HOW TO USE:
- Open image to analyse. Z-stack is expected, drawing is performed on a maximum intensity projection.
- Run the macro.
- Cellpose segments bacteria. It may take a while.
- Segmentation and an overview image appears side by side. You can now manually remove bacteria unsuitable
for analysis (too dense, on the edge etc.) from the label image. Just delete them. Then press OK.
- A cutout containing a currently analysed cell marked at its centre and instructions appear. Cutout 
contains bacteria (magenta) and filaments (green) channels and suggested, automatically generated 
traces of the filaments (yellow). Draw filaments manually into this image (blue). You can draw multiple, 
but don't have to draw all of them. Make sure drawn filaments don't touch. If you need to erase a line,
press alt and draw over it. You can repeat drawing and erasing as needed. Then close the instructions ("Drawing").
- "Drawing" window reappears, skeleton of the drawn filament is transferred to the "Measured filaments" window, 
and is also visible in the cutout in magenta. You can draw next filament (or more) and then close 
the "Drawing" window.
- When all the filaments were drawn and transferred by closing the "Drawing" window, close the cutout
window (the one named "cell x of y"). Don't save changes.
- A cutout centered on a next cell to analyse appears. Repeat the filament drawing for all filaments on all 
cells. Currently analysed cell is marked by a yellow circle (the first cell by a yellow dot). A cell can 
have no filaments.
- When cutout containing the last cell is closed, results are processed and saved into a subfolder 
called "results" within a filder containing the image that was analysed. An overview window (which is also
saved in the "results" remains open. It has 4 channels: Bacteria (magenta), filaments (green), skeletons
of the drawn filaments (white; this is what was actually analysed), and segmentation of the analysed cells
(glasbey_on_dark, that means a different colour for each cell). The image is saved as a multipage tiff,
not an RGB, to make post-analysis check possible, but it may open incorrectly in various image viewers.
For proper inspection, please use ImageJ.
*/


