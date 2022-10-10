/* ImageJ macro script to generate clustering measurments based on segmentation 
 * from ilastik classifier. For Jooss et al (2022). 
 *  
 *  Author: Jeremy Pike, Image analyst for COMPARE, j.a.pike@bham.ac.uk
*/


#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory for csv", style = "directory") output
#@ File (label = "Ilastik project file", style = "file") ilastik_file
#@ String (label = "File suffix", value = ".tif") suffix
#@ Double (label = "Voxel size (microns)", value = 0.1) voxel_size


batch_mode = false
setBatchMode(batch_mode);

run("Close All");

// Global table to hold measurements from all images
measurments = Table.create("measurements");

// process all images in specified directory (recussive)
processFolder(input);



// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, list[i]);
	}
}

function processFile(input, file) {

	print("Processing: " + input + File.separator + file);
	
	// open image
	open(input + File.separator + file);
	
	rename("raw");
	
	run("16-bit");
	// run specified ilastik pixel classifier
	// on some systems we observed errors if batch mode was on for this step so turn this off and on again if used
	setBatchMode(false);
	run("Run Pixel Classification Prediction", "projectfilename=[" + ilastik_file + "] raw pixelclassificationtype=Segmentation");
	setBatchMode(batch_mode);
	rename("ilastik seg");

	// creating binary segmentations for each segmentation class (three)
	setOption("BlackBackground", false);
	selectWindow("ilastik seg");
	run("Duplicate...", "title=bg");
	setThreshold(1, 1, "raw");
	run("Convert to Mask");
	selectWindow("ilastik seg");
	run("Duplicate...", "title=cell");
	setThreshold(2, 2, "raw");
	run("Convert to Mask");
	selectWindow("ilastik seg");
	run("Duplicate...", "title=clustered");
	setThreshold(3, 3, "raw");
	run("Convert to Mask");

	//waitForUser("ok?");
	
	// get area of background class
	selectWindow("bg");
	run("Select None");
	run("Create Selection");
	getStatistics(area);
	bg_area = area * voxel_size * voxel_size;
	// get area of clustered class
	selectWindow("clustered");
	run("Select None");
	run("Create Selection");
	getStatistics(area);
	clust_area = area * voxel_size * voxel_size;
	// get area of cells (area of cell class + are of clustered class)
	selectWindow("cell");
	run("Select None");
	run("Create Selection");
	getStatistics(area);
	cell_area = clust_area + area * voxel_size * voxel_size;
	
	// get summary stats for connected components of clustered class
	selectWindow("clustered");
	run("Select None");
	run("Analyze Particles...", "size=5-Infinity exclude summarize");
	
	// retrieve mean cluster area from summary table
	selectWindow("Summary");

	mean_cluster_area = Table.get("Average Size", Table.size - 1) * voxel_size * voxel_size;

	// place measurements for this image in a new row of the global "measurments" table
	// also add filename and directory
	selectWindow("measurements");
	row = Table.size;
	Table.set("file", row, file)
	Table.set("folder", row, input)  
	Table.set("bg_area", row, bg_area) 
	Table.set("cell_area", row, cell_area) 
	Table.set("clust_area", row, clust_area) 
	Table.set("clust_cell ratio", row, clust_area/cell_area)
	Table.set("cell coverage", row, cell_area/(cell_area + bg_area))  
	Table.set("mean cluster area", row, mean_cluster_area)  
	Table.update;
	// save table
	Table.save(output + File.separator + "measurements.csv");
	//waitForUser("ok?");
	
	// produce ilastik segmentation visualisation and save as png
	selectWindow("ilastik seg");	
	setMinAndMax(1, 3);
	run("Apply LUT");
	run("Green Fire Blue");
	run("RGB Color");
	saveAs("PNG", input + File.separator + replace(file, ".tif", "_seg.png"));
	
	run("Close All");
}
