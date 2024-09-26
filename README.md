# T3SS-filaments

This macro measures length of filaments touching (or very close to) cells. It was developed for type-3 secretion system of bacteria. Filaments are manually traced and measured cell-by-cell, manual tracing for each cell can be repeated any number of steps to allow for sequential measurement of crossing filaments, any number of filaments can be traced in each step. As only the maximum length is recorded, it is not suitable for branched filaments. Attempt was made to make this macro as user-friendly as possible.

## HOW TO USE:
- Open image to analyse. Z-stack is expected, drawing is performed on a maximum intensity projection.
- Run the macro.
- Cellpose segments bacteria. It may take a while.
- Segmentation and an overview image appears side by side. You can now manually remove bacteria unsuitable for analysis (too dense, on the edge etc.) from the label image. Just delete them. Then press OK.
- A cutout containing a currently analysed cell marked at its centre and instructions appear. Cutout contains bacteria (magenta) and filaments (green) channels and suggested, automatically generated traces of the filaments (yellow). Draw filaments manually into this image (blue). You can draw multiple, but don't have to draw all of them. Make sure drawn filaments don't touch. If you need to erase a line, press alt and draw over it. You can repeat drawing and erasing as needed. Then close the instructions ("Drawing").
- "Drawing" window reappears, skeleton of the drawn filament is transferred to the "Measured filaments" window, and is also visible in the cutout in magenta. You can draw next filament (or more) and then close the "Drawing" window.
- When all the filaments were drawn and transferred by closing the "Drawing" window, close the cutout window (the one named "cell x of y"). Don't save changes.
- A cutout centered on a next cell to analyse appears. Repeat the filament drawing for all filaments on all cells. Currently analysed cell is marked by a yellow circle (the first cell by a yellow dot). A cell can have no filaments.
- When cutout containing the last cell is closed, results are processed and saved into a subfolder called "results" within a filder containing the image that was analysed. An overview window (which is also saved in the "results" remains open. It has 4 channels: Bacteria (magenta), filaments (green), skeletons of the drawn filaments (white; this is what was actually analysed), and segmentation of the analysed cells (glasbey_on_dark, that means a different colour for each cell). The image is saved as a multipage tiff, not an RGB, to make post-analysis check possible, but it may open incorrectly in various image viewers. For proper inspection, please use ImageJ.
