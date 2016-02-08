#!/usr/bin/perl

use strict;
use warnings;
use Tk;
use Tk::ProgressBar;
#use Tk::FileDialog;
use Cwd;
use Cwd 'chdir';
use Cwd 'realpath';
use Image::ExifTool;
#use ImageArrayIn;
use Tk::FBox;





my $currentdir = getcwd();
print "$currentdir\n";

chdir(); # change to homedir
# my @filearray;
# my $filearrayref;

my $filearray = ImageArrayIn->new();
my $thumbarray = ImageArrayIn->new();



my $tempmrc = "tempmrc.mrc";
my $tempxf1 = "temp1.xf";
my $tempxf2 = "temp2.xf";
my $tempxg1 = "temp1.xg";
my $tempxg2 = "temp2.xg";
my $tempxg = "temp.xg";
my $tempaligned = "tempaligned.mrc";


my $tempdir; #directories will be initialised when directory of images is known
# my $newtempdir; #name of tempdir with backslashes in case of non alphanumeric signs





my $initial = 0;
my $alignfile;
#my $color = "rgb";
my $skiptext = "";
my $userefslice = "off";
my $slicenumber = 1;
my $borderfill = 127;
my $hexborderfill = sprintf ("#%.2x%.2x%.2x", $borderfill, $borderfill, $borderfill);
my $trendsparameter = "-nfit 1";
my $writetransformations = "off";


#####################file loading

my $top0 = MainWindow->new(-title => 'IMOD align');


my $frame7 = $top0->Frame(-relief=>"groove", -borderwidth=>"3");
$frame7->pack(-side=>"bottom", -expand => 'yes', -fill => 'both');

#my $progresslabel = $frame7->Label(-text => "Progress");
#$progresslabel->pack(-side=>"top", -anchor=>'w', -expand=>'no', -fill=>"x", -anchor=>"nw");


my $frame1 = $top0->Frame(-relief=>'groove', -borderwidth=>"3")->pack(-side=>"left", -expand => 'yes', -fill => 'both');


######wird erst später gebraucht, muss aber hier konfiguriert werden können ($maxslice)
my $frame5 = $top0->Frame(-relief=>"groove", -borderwidth=>"3");


my $prevparam = 0;

my @prevparamtext = ("allow all", "prevent translation", "prevent rotation", "prevent magnification");
my $prevparamtext = $prevparamtext[$prevparam];

my $prevtrendslider = $frame5->Scale(-label => "prevent trend assignment",
							-from => 0,
							-to => 3,
							-orient => "horizontal",
							-length => 150,
							-resolution => 1,
				     -variable => \$prevparam);

$prevtrendslider ->Tk::bind("<ButtonRelease-1>",
				     sub {
					 $prevparamtext = $prevparamtext[$prevparam];
			                 });

my $prevtrendlabel = $frame5->Label(-textvariable => \$prevparamtext);




my $refbutton = $frame5->Checkbutton(-text => 'align to reference slice',
				     -onvalue => "on", -offvalue => "off",
				     -selectcolor=>"green",
				     -variable => \$userefslice
                                     );




$refbutton->Tk::bind("<Button>", 
		     sub {
			 if ($userefslice eq "off") {
			     unless ($trendsparameter eq "-nfit 0") {
				 $prevparam = 0;
				 $prevtrendslider->update;
				 $prevtrendslider->configure(-state => "active");
			     }
			 }
			 else {
			     $prevparam = 0;
			     $prevtrendslider->update;
			     $prevtrendslider->configure(-state => "disabled");
			 }
		     });


my $refslicescale = $frame5 ->Scale(-label => "choose reference slice",
				    -from => 1,
				    -to => 1,
				    -orient => "horizontal",
				    -length => 150,
				    -resolution => 1,
				    -variable => \$slicenumber,
                                    );



my $fillscale = $frame5 ->Scale(-label => "fill borders black / white",
							-from => 0,
							-to => 255,
							-orient => "horizontal",
							-length => 150,
							-resolution => 1,
				                        -troughcolor => "$hexborderfill",
				    -variable => \$borderfill);


$fillscale ->Tk::bind("<ButtonRelease-1>",
				     sub {
					 $hexborderfill = sprintf ("#%.2x%.2x%.2x", $borderfill, $borderfill, $borderfill);
					 $fillscale -> configure(-troughcolor => "$hexborderfill");
					 #print "\n$borderfill troughcolor $hexborderfill\n";
					 });




my $trendslabel = $frame5 -> Label(-text => "use trends in alignment");



$refbutton->deselect;
$refbutton->configure(-state => "disabled");


my $trendsbutton1 = $frame5 ->Radiobutton(-text => "linear N1",
					 -value => "-nfit 1",
					 -variable => \$trendsparameter,
					  -command, sub {
					      $refbutton->deselect;
					      $refbutton->configure(-state => "disabled");
					      $userefslice = "off"; # to ensure that it is set to off whenever linear N1 is choosen
					      $prevparam = 0;
					      $prevtrendslider->update;
					      $prevtrendslider->configure(-state => "active");
					  });


my $trendsbutton2 = $frame5 ->Radiobutton(-text => "global",
					 -value => "-nfit 0",
					 -variable => \$trendsparameter,
					  -command, sub {
					      $refbutton->configure(-state => "active");
					      $refbutton->select;

					      $prevparam = 0;
					      $prevtrendslider->update;
					      $prevtrendslider->configure(-state => "disabled");
					  });


my $trendsbutton3 = $frame5 ->Radiobutton(-text => "default",
					 -value => "",
					 -variable => \$trendsparameter,
					  -command, sub {
					      $refbutton->deselect; # start with deselected, because prevtrendslider must be set disabled, when reference slice is enabled
					      $refbutton->configure(-state => "active");
					      $userefslice = "off"; # to ensure that it is set to off whenever linear N1 is choosen

					      $prevparam = 0;
					      $prevtrendslider->update;
					      $prevtrendslider->configure(-state => "active");
					  });





#########################


my $filelabeltext = "no files loaded";

my $filelabel = $frame1->Label(-textvariable => \$filelabeltext, -relief=>'sunken', -background=>"red");


my $resize = "off";
#my $resizebutton = $frame1->Checkbutton(-text => 'resize images',
#					   -onvalue => "on", -offvalue => "off",
#					   -selectcolor=>"green",
#					-variable => \$resize);



my $reduce = 0.1;
my $reducescale = $frame1 ->Scale(-label => "reduce preview images",
				  -from => 1,
				  -to => 0.1,
				  -orient => "horizontal",
				  -length => 200,
				  -resolution => 0.1,
				  -variable => \$reduce);


my $xsize = 20;
my $xsizescale = $frame1 ->Scale(-label => "width of images",
							-from => 1,
							-to => 20000,
							-orient => "horizontal",
							-length => 200,
							-resolution => 1,
				    -variable => \$xsize);


my $ysize = 20;
my $ysizescale = $frame1 ->Scale(-label => "height of images",
							-from => 1,
							-to => 20000,
							-orient => "horizontal",
							-length => 200,
							-resolution => 1,
				    -variable => \$ysize);






my $f1label = $frame1->Label(-text=>"1. select files") -> pack (-side=>"top", -anchor=>'nw');
my $loadbutton=$frame1->Button(-text => 'open *.tif files',
			       -command => sub {

				   &filedialog($frame1, $filearray);
				   if ($filearray->{arrayref}) {
				       $filearray->readarray();

				       if (($filearray->{imagedirectory}) && (-d $filearray->{imagedirectory})) {
					   $tempdir = "$filearray->{imagedirectory}\/imodalign_tmp\/";
#					   $newtempdir = $tempdir;
#					   $newtempdir = "\"$newtempdir\""; # =~ s/([^\w\.\/])/\\$1/g;



					   unless (-d $tempdir) {
					       unless (mkdir ($tempdir, 0744)) {
						   die "kann Temp-Verzeichnis nicht anlegen!";
						   return undef;
					       }
					   }
				       }


				       $top0->Busy(-recurse => "1");
				       my $steps = $filearray->{filenumber};
				       my $progressbar = $frame7->ProgressBar(-length => "300", -blocks => "$steps", -from => "0", -to => "$steps", -padx => "5", -pady => "5")->pack(-expand => "yes", -fill => "both");
				       $top0->update;

				       $filelabel -> configure(-background=>"yellow");
				       $filearray->makethumbimages(reduce=>$reduce, progressbar=>$progressbar);
				       $filelabeltext = "please wait";
				       &load_tifs($top0, $filearray, $tempmrc, $tempdir);

				       $progressbar->destroy();
				       $top0->Unbusy;

				       $filelabeltext = "files loaded";
				       $filelabel -> configure(-background=>"green");
				       $refslicescale -> configure(-to=>$filearray->{filenumber});
				       $xsize = $filearray->{maxwidth};
				       $xsizescale -> configure(-variable=>\$xsize);
				       $ysize = $filearray->{maxheight};
				       $ysizescale -> configure(-variable=>\$ysize);
				       &setlabelsred ($top0, 0);
				   }
				   else {
				       $filelabeltext = "no files loaded";
				       $filelabel -> configure(-background=>"red");
				   }}
    );
$loadbutton->pack(-side => 'top', -expand => 'no', -fill => 'x');

$filelabel -> pack (-side=>"top", -expand=>'no', -fill=>"x");



my $reloadbutton = $frame1->Button(-text => 'reload images with given size',
				   -command => sub {
				       $filelabel -> configure(-background=>"yellow");
				       $filelabeltext = "please wait";
				       $filearray -> setimagesize (width => $xsize, height => $ysize);
#				       $filearray -> setreduce (reduce => $reduce);
				       $top0->Busy(-recurse => "1");
				       my $steps = $filearray->{filenumber};
				       my $progressbar = $frame7->ProgressBar(-length => "300", -blocks => "$steps", -from => "0", -to => "$steps", -padx => "5", -pady => "5")->pack(-expand => "yes", -fill => "both");
				       $top0->update;

				       $filearray->makethumbimages(reduce=>$reduce, progressbar=>$progressbar);
				       &load_tifs($top0, $filearray, $tempmrc, $tempdir);
				       $filelabeltext = "files loaded";
				       $filelabel -> configure(-background=>"green");
				       &setlabelsred ($top0, 0);
				       $refslicescale -> configure(-to=>$filearray->{filenumber});

				       $progressbar->destroy();
				       $top0->Unbusy;

				   }
    );




#$resizebutton->pack(-side => 'top', -anchor => 'nw', -expand => 'no', -fill => 'none');
$reducescale -> pack(-side => 'top', -expand => 'no', -fill => 'none');
$xsizescale -> pack(-side => 'top', -expand => 'no', -fill => 'none');
$ysizescale -> pack(-side => 'top', -expand => 'no', -fill => 'none');
$reloadbutton->pack(-side => 'top', -anchor => 'nw', -expand => 'no', -fill => 'none');






#######################prealign
my $frame2 = $top0->Frame(-relief=>"groove", -borderwidth=>"3")->pack(-side=>"left", -expand => 'yes', -fill => 'both');
my $f2label = $frame2->Label(-text=>"2. prealign automatically") -> pack (-side=>"top", -anchor=>'nw');


my $bframe2 = $frame2->Frame(-relief=>"raised", -borderwidth=>"3")->pack(-side=>'top', -expand => 'no', -fill => 'x', -anchor=>"n");

my $prexcorr = "on";
my $prexcorrbutton = $bframe2->Checkbutton(-text => 'coarse prealignment',
					   -onvalue => "on", -offvalue => "off",
					   -selectcolor=>"green",
					   -variable => \$prexcorr)
    ->pack(-side => 'top', -anchor => 'nw', -expand => 'no', -fill => 'none');


my $bframe1 = $frame2->Frame(-relief=>"raised", -borderwidth=>"3")->pack(-side=>'top', -expand => 'no', -fill => 'x', -anchor=>"n");


my $param = 3;
my @paramtext = ("0", "1", "displacement", "displacement + rotation", "disp. + rotation + magnification", "disp. + rot. + magnification + distortion");
my $paramlabeltext = $paramtext[$param];

my $paramscale = $bframe1->Scale(-label => "free alignment parameters",
							-from => 2,
							-to => 5,
							-orient => "horizontal",
							-length => 150,
							-resolution => 1,
							-variable => \$param)
    ->pack(-side => 'top', -expand => 'no', -fill => 'x', -anchor=>"nw");

$paramscale ->Tk::bind("<ButtonRelease-1>",
				     sub {
					 $paramlabeltext = $paramtext[$param];
					 });

my $paramlabel = $bframe1->Label(-textvariable => \$paramlabeltext) -> pack (-side=>"top", -anchor=>'n', -expand=>"yes", -fill=>"both");


my $matt = 0.1;
my $mattscale = $bframe1->Scale(-label => "skip image borders",
							-from => 0,
							-to => 0.4,
							-orient => "horizontal",
							-length => 130,
							-resolution => 0.05,
							-variable => \$matt)
    ->pack(-side => 'left', -anchor => "nw", -expand => 'no', -fill => 'x');

my $binning = 2;
my $binscale = $bframe1->Scale(-label => "reduce images",
							-from => 1,
							-to => 16,
							-orient => "horizontal",
							-length => 130,
							-resolution => 1,
							-variable => \$binning)
    ->pack(-side => 'left', -anchor => "nw", -expand => 'no', -fill => 'x');



my $use_filter = "off";
my $filter1 = 0;
my $filter2 = 0;
my $filter3 = 0;
my $filter4 = 0;



my $alignlabeltext = "not aligned";

my $alignlabel = $frame2->Label(-textvariable => \$alignlabeltext, -relief=>'sunken', -background=>"red");

my $teststart=$frame2->Button(-text => 'start alignment',
			      -command => sub {
				  $alignlabel -> configure(-background=>"yellow");
				  $alignlabeltext = "please wait";
				  $initial = 0;
				  &align($top0, $tempmrc, $tempxf1, $tempxf2, $tempdir, $initial, $param, $prexcorr, $matt, $binning, $skiptext, $use_filter, $filter1, $filter2, $filter3, $filter4);
				  $alignlabel -> configure(-background=>"green");
				  $alignlabeltext = "xf-file for alignment complete";
				  $alignfile = $tempxf1;
				  &setlabelsred ($top0, 1);
				  }
			      );
$teststart->pack(-side => 'top', -expand => 'no', -fill => 'x', -before=>$bframe2);
$alignlabel -> pack (-side=>"top", -anchor=>'w', -expand=>'no', -fill=>"x", -before=>$bframe2);


#########################midasalign
#my $frame3 = $top0->Frame(-relief=>"groove", -borderwidth=>"3")->pack(-side=>"left", -expand => 'yes', -fill => 'both');

my $f3label = $frame2->Label(-text=>"3. align by hand with midas") -> pack (-side=>"top", -anchor=>'nw');


my $midaslabeltext = "save transforms in midas! (key s)";
my $midaslabel = $frame2->Label(-textvariable => \$midaslabeltext, -relief=>'sunken', -background=>"red");
my $midasstart=$frame2->Button(-text => 'start midas',
			       -command => sub {
				   $midaslabel -> configure(-background=>"yellow");
				   $midaslabeltext = "save transforms in midas! (key s)";
				   &midasalign($top0, $tempmrc, $tempxf1, $tempdir);
				   $midaslabel -> configure(-background=>"green");
				   $midaslabeltext = "hope you have stored the transform-file";
				   $alignfile = $tempxf1;
				   &setlabelsred ($top0, 2);
			       }
			       );
$midasstart->pack(-side => 'top', -expand => 'no', -fill => 'x', -anchor=>"nw");
$midaslabel -> pack (-side=>"top", -anchor=>'w', -expand=>'no', -fill=>"x", -anchor=>"nw");


####################postalign
my $frame4 = $top0->Frame(-relief=>"groove", -borderwidth=>"3")->pack(-side=>"left", -expand => 'yes', -fill => 'both');
my $f4label = $frame4->Label(-text=>"4. align automatically") -> pack (-side=>"top", -anchor=>'nw');

my $dframe4 = $frame4->Frame(-relief=>"raised", -borderwidth=>"3")->pack(-side=>'top', -expand => 'yes', -fill => 'both');

my $param4 = 3;
my @paramtext4 = ("0", "1", "displacement", "displacement + rotation", "disp. + rotation + magnification", "disp. + rot. + magnification + distortion");
my $paramlabeltext4 = $paramtext4[$param4];

my $paramscale4 = $dframe4->Scale(-label => "free alignment parameters",
							-from => 2,
							-to => 5,
							-orient => "horizontal",
							-length => 150,
							-resolution => 1,
							-variable => \$param4)
    ->pack(-side => 'top', -expand => 'yes', -fill => 'both', -anchor=>"nw");

$paramscale4 ->Tk::bind("<ButtonRelease-1>",
				     sub {
					 $paramlabeltext4 = $paramtext4[$param4];
					 });

my $paramlabel4 = $dframe4->Label(-textvariable => \$paramlabeltext4) -> pack (-side=>"top", -anchor=>'n', -expand=>"yes", -fill=>"both");

my $prexcorr4 = "off";


my $matt4 = 0;
my $mattscale4 = $dframe4->Scale(-label => "skip image borders",
							-from => 0,
							-to => 0.4,
							-orient => "horizontal",
							-length => 130,
							-resolution => 0.05,
							-variable => \$matt4)
    ->pack(-side => 'left', -anchor => "w", -expand => 'yes', -fill => 'none');

my $binning4 = 2;
my $binscale4 = $dframe4->Scale(-label => "reduce images",
							-from => 1,
							-to => 16,
							-orient => "horizontal",
							-length => 130,
							-resolution => 1,
							-variable => \$binning4)
    ->pack(-side => 'left', -anchor => "w", -expand => 'yes', -fill => 'none');


#my $eframe4 = $frame4->Frame(-relief=>"raised", -borderwidth=>"3")->pack(-side=>'top', -expand => 'yes', -fill => 'both');



#my $skiplabel = $eframe4->Label(-text => 'skip sections (e.g. 2,5,7-9)') -> pack (-side=>"top", -anchor=>'w', -expand=>"yes", -fill=>"none");


#-label=>'skip sections e\.g\.\(2\,5\,7\-9\)',
#my $skipfield = $eframe4->Entry(-textvariable=>\$skiptext)->pack(-side=>"top", -expand => 'yes', -fill => 'both');




my $use_filter4 = "off";
my $filter14 = 0;
my $filter24 = 0;
my $filter34 = 0;
my $filter44 = 0;


my $filterframe4 = $frame4->Frame(-relief=>"raised", -borderwidth=>"3")->pack(-side=>"top", -expand => 'yes', -fill => 'both');

my $filterframe14 = $filterframe4->Frame()->pack(-side=>"top", -expand => 'yes', -fill => 'both');


my $usefilterbutton4 = $filterframe14->Checkbutton(-text => 'use filter',
						   -selectcolor=>"green",
						   -onvalue => "on", -offvalue => "off",
						   -variable => \$use_filter4)
    ->pack(-side => 'top', -expand => 'no', -fill => 'none', -anchor => 'nw');



my $filter1scale4 = $filterframe14->Scale(-label => "sigma 1",
					  -from => -0.5,
					  -to => 0.5,
					  -orient => "horizontal",
					  -length => 130,
					  -resolution => 0.05,
					  -variable => \$filter14)
    ->pack(-side => 'left', -expand => 'yes', -fill => 'none');

my $filter2scale4 = $filterframe14->Scale(-label => "sigma 2",
					  -from => -0.5,
					  -to => 0.5,
					  -orient => "horizontal",
					  -length => 130,
					  -resolution => 0.05,
					  -variable => \$filter24)
    ->pack(-side => 'top', -expand => 'yes', -fill => 'none');


my $filterframe24 = $filterframe4->Frame()->pack(-expand => 'yes', -fill => 'both');

my $filter3scale4 = $filterframe24->Scale(-label => "radius 1",
							-from => -0.5,
							-to => 0.5,
							-orient => "horizontal",
							-length => 130,
							-resolution => 0.05,
							-variable => \$filter34)
    ->pack(-side => 'left', -expand => 'yes', -fill => 'none');



my $filter4scale4 = $filterframe24->Scale(-label => "radius 2",
							-from => -0.5,
							-to => 0.5,
							-orient => "horizontal",
							-length => 130,
							-resolution => 0.05,
							-variable => \$filter44)
    ->pack(-side => 'top', -expand => 'yes', -fill => 'none');


my $alignlabeltext4 = "not aligned";
my $alignlabel4 = $frame4->Label(-textvariable => \$alignlabeltext4, -relief=>'sunken', -background=>"red");

my $alignstart=$frame4->Button(-text => 'start alignment',
			       -command => sub {
				   $alignlabel4 -> configure(-background=>"yellow");
				   $alignlabeltext4 = "please wait";
				   $initial = 1;
				   &align($top0, $tempmrc, $tempxf1, $tempxf2, $tempdir, $initial, $param4, $prexcorr4, $matt4, $binning4, $skiptext, $use_filter4, $filter14, $filter24, $filter34, $filter44);
				   $alignlabel4 -> configure(-background=>"green");
				   $alignlabeltext4 = "xf-file for alignment complete";
				   $alignfile = $tempxf2;
				   &setlabelsred ($top0, 3);
			       }
    );
$alignstart->pack(-side => 'top', -expand => 'yes', -fill => 'both', -before => $dframe4);
$alignlabel4 -> pack (-side=>"top", -anchor=>'w', -expand=>'yes', -fill=>"both", -before => $dframe4);



#########################midasalign

my $fm2label = $frame4->Label(-text=>"5. align by hand with midas") -> pack (-side=>"top", -anchor=>'nw');

my $midaslabeltext2 = "save transforms in midas! (key s)";
my $midaslabel2 = $frame4->Label(-textvariable => \$midaslabeltext2, -relief=>'sunken', -background=>"red");
my $midasstart2=$frame4->Button(-text => 'start midas',
			       -command => sub {
				   $midaslabel2 -> configure(-background=>"yellow");
				   $midaslabeltext2 = "save transforms in midas! (key s)";
				   &midasalign($top0, $tempmrc, $alignfile, $tempdir);
				   $midaslabel2 -> configure(-background=>"green");
				   $midaslabeltext2 = "hope you have stored the transform-file";
				   &setlabelsred ($top0, 4);
			       }
			       );
$midasstart2->pack(-side => 'top', -expand => 'no', -fill => 'x', -anchor=>"nw");
$midaslabel2 -> pack (-side=>"top", -anchor=>'w', -expand=>'no', -fill=>"x", -anchor=>"nw");




####################apply
#my $frame6 = $top0->Frame(-relief=>"groove", -borderwidth=>"3") nach oben, wegen refslicescale-konfiguration


$frame5->pack(-side=>"left", -expand => 'yes', -fill => 'both');

my $f6previewlabel = $frame5->Label(-text=>"6. show preview") -> pack (-side=>"top", -anchor=>'nw');


my $previewlabeltext = "preview not started";
my $previewlabel = $frame5->Label(-textvariable => \$previewlabeltext, -relief=>'sunken', -background=>"red");
my $previewstart=$frame5->Button(-text => 'compute preview',
			       -command => sub {
				   $previewlabel -> configure(-background=>"yellow");
				   $previewlabeltext = "please wait";
				   $top0->update();
				   &preview($top0, $filearray, $tempmrc, $tempxg, $alignfile, $tempaligned, $tempdir, $userefslice, $slicenumber, $trendsparameter, $prevparam, $borderfill);
				   $previewlabel -> configure(-background=>"green");
				   $previewlabeltext = "preview ready";
				   #$alignfile = $tempxf1; was sollte das?
				   &setlabelsred ($top0, 5);
			       }
			       );
$previewstart->pack(-side => 'top', -expand => 'no', -fill => 'x', -anchor=>"nw");
$previewlabel -> pack (-side=>"top", -anchor=>'w', -expand=>'no', -fill=>"x", -anchor=>"nw");


$refbutton ->pack(-side => 'top', -anchor => 'nw', -expand => 'no', -fill => 'none');

$refslicescale -> pack(-side => 'top', -expand => 'no', -fill => 'none');

$trendslabel ->  pack(-side => 'top', -expand => 'no', -fill => 'none');

$trendsbutton1 ->  pack(-side => 'top', -expand => 'no', -fill => 'none', -anchor => 'nw');
$trendsbutton2 ->  pack(-side => 'top', -expand => 'no', -fill => 'none', -anchor => 'nw');
$trendsbutton3 ->  pack(-side => 'top', -expand => 'no', -fill => 'none', -anchor => 'nw');

$prevtrendslider -> pack(-side => 'top', -expand => 'no', -fill => 'none');
$prevtrendlabel -> pack (-side=>"top", -anchor=>'n', -expand=>"yes", -fill=>"both");

$fillscale ->  pack(-side => 'top', -expand => 'no', -fill => 'none');

my $writetransbutton = $frame5->Checkbutton(-text => 'write transformation list only',
					   -onvalue => "on", -offvalue => "off",
					   -selectcolor=>"green",
				     -variable => \$writetransformations);



my $f6label = $frame5->Label(-text=>"7. apply transformations") -> pack (-side=>"top", -anchor=>'nw');


my $applylabeltext = "transformations not applied";
my $applylabel = $frame5->Label(-textvariable => \$applylabeltext, -relief=>'sunken', -background=>"red");
my $applystart=$frame5->Button(-text => 'start apply',
			       -command => sub {
				   $applylabel -> configure(-background=>"yellow");
				   $applylabeltext = "please wait";
				   $top0->update();

				   $top0->Busy(-recurse => "1");
				   my $steps = $filearray->{filenumber} * 3;
				   my $progressbar = $frame7->ProgressBar(-length => "300", -blocks => "$steps", -from => "0", -to => "$steps", -padx => "5", -pady => "5")->pack(-expand => "yes", -fill => "both");
				   $top0->update;

				   &transform($top0, $filearray, $reduce, $tempmrc, $tempxg, $alignfile, $tempaligned, $tempdir, $userefslice, $slicenumber, $trendsparameter, $prevparam, $progressbar, $writetransformations, $borderfill);
				   $applylabel -> configure(-background=>"green");
				   $applylabeltext = "transformation ready";

				   $progressbar->destroy();
				   $top0->Unbusy;

				   #$alignfile = $tempxf1; was sollte das?
#				   &setlabelsred ($top0, 6);
			       }
			       );
$applystart->pack(-side => 'top', -expand => 'no', -fill => 'x', -anchor=>"nw");
$applylabel -> pack (-side=>"top", -anchor=>'w', -expand=>'no', -fill=>"x", -anchor=>"nw");



$writetransbutton ->pack(-side => 'top', -anchor => 'nw', -expand => 'no', -fill => 'none');

# its better to use the transform subroutine for writing the transformation file.
=command
my $writetransforms=$frame5->Button(-text => 'write transformation file',
			       -command => sub {
				   &writetransformationfile($top0, $filearray, $alignfile, $userefslice, $slicenumber, $trendsparameter);
			       }
    );
$writetransforms->pack(-side => 'top', -expand => 'no', -fill => 'x', -anchor=>"nw");
=cut








MainLoop;




sub setlabelsred {
    my $top0 = shift;
    my $labelnumber = shift;

    my @labellist = ($filelabel, $alignlabel, $midaslabel, $alignlabel4, $midaslabel2, $previewlabel, $applylabel);

    while ($labelnumber < $#labellist) {
	$labellist[$labelnumber + 1] -> configure(-background=>"red");
	$labelnumber++;
    }
    return 1;
}



sub filedialog {
    my $top0 = shift;
    my $filearray = shift;


    $filearray->{arrayref} = $top0->FBox(-multiple=>"1")->Show();


#    my $resultdir = $dirselector->Show();


#     $filearray->{arrayref}  = $top0 -> getOpenFile(-title=>"load tiff files", -filetypes=>[["Tiff Files", [".tif", ".TIF", ".tiff", ".TIFF"]], ['All Files','*']], -multiple=>1);

    print "@{$filearray->{arrayref}}  \n";

    return $filearray;
}



sub load_tifs {
    my $top0 = shift;
    my $filearray = shift;
#    my $filearrayref = shift;
#    my $maxwidth = shift;
#    my $maxheight = shift;
    my $tempmrc = shift;
    my $tempdir = shift;

#$filearray->{thumbarrayref}, $filearray->{thumbmaxwidth}, $filearray->{thumbmaxheight}

    my $resizetext = "-o $filearray->{thumbmaxwidth}\,$filearray->{thumbmaxheight}";

    my $flag;
    if ($filearray->{imagetype} eq "RGB") {
	$flag = "-g";
    }
    else {
	$flag = "";
    }

    my $filestring;

# use tif2mrc and newstack to load the files one by one, otherwise, the file list may not fit into the command line

#    $filestring = join(" ", @{$filearray->{thumbarrayref}});

#    my $process;
#    print "|tif2mrc $flag $resizetext $filestring \"$tempdir$tempmrc\" \n";
#    open ($process, "|tif2mrc $flag $resizetext $filestring \"$tempdir$tempmrc\"") or die "tif2mrc nicht gestartet";
#    $top0->update;


#    my $file = ${$filearray->{thumbarrayref}}[0];


#    my $process;
#    open ($process, "|tif2mrc $flag $resizetext \"$file\" \"$tempdir$tempmrc\"") or die "tif2mrc nicht gestartet";
#    print "\n1\n";

#    close $process;


    my $file;

    my $j = 0;
    my @collectfornewstack;

    my @blocks;
    my $k = 0; 

    for (my $i = 0; $i <= $#{$filearray->{thumbarrayref}}; $i++) {

	$file = ${$filearray->{thumbarrayref}}[$i];



#	if (($j < 50) && ($i <= $#{$filearray->{thumbarrayref}})) {

	my $newloadproc;
	open ($newloadproc, "|tif2mrc $flag $resizetext \"$file\" \"$tempdir$tempmrc\_single\_$j\"") or die "tif2mrc nicht gestartet";
#	    print "\n3\n";
	close $newloadproc;

#	print "\n\"$tempdir$tempmrc\_single\_$j\"";
	push (@collectfornewstack, "\"$tempdir$tempmrc\_single\_$j\"");

	$j++;
#	}

	if (($j >= 50) || ($i >= $#{$filearray->{thumbarrayref}})) {
	    my $filescollected = join(' ', @collectfornewstack); 

#	    print "\n ################### |newstack $filescollected \"$tempdir$tempmrc\_block\_$k\"";

	    my $newstackproc;
	    open ($newstackproc, "|newstack $filescollected \"$tempdir$tempmrc\_block\_$k\"") or die "newstack nicht gestartet";
	    print "\n4\n";
	    close $newstackproc;


	    push (@blocks, "\"$tempdir$tempmrc\_block\_$k\"");
	    $k++;

	    foreach my $element (@collectfornewstack) {
		unlink ("$element");
	    }

	    $j = 0;
	    @collectfornewstack = ();
	}

#	print "\nhallo\n";
#	my $mvproc;
#	open ($mvproc, "|mv \"$tempdir$tempmrc\" \"$tempdir$tempmrc\_base\"") or die "tif2mrc nicht gestartet";
#	print "\n2\n";
#	close $mvproc;




#	my $newstackproc;
#	open ($newstackproc, "|newstack \"$tempdir$tempmrc\_base\" \"$tempdir$tempmrc\_single\" \"$tempdir$tempmrc\"") or die "newstack nicht gestartet";
#	print "\n4\n";
#	close $newstackproc;



    }



    my $blockscollected = join(' ', @blocks); 
    print "\n 11111111111111111111 |newstack $blockscollected \"$tempdir$tempmrc\"";
    
    my $newstackproc;
    open ($newstackproc, "|newstack $blockscollected \"$tempdir$tempmrc\"") or die "newstack nicht gestartet";
    print "\n4\n";
    close $newstackproc;



    foreach my $element (@collectfornewstack) {
	unlink ("$element");
    }



    return $tempmrc;

}


sub align {
    my $top0 = shift;
    my $tempmrc = shift;
    my $tempxf1 = shift;
    my $tempxf2 = shift;
    my $tempdir = shift;
    my $initial = shift;
    my $param = shift;
    my $prexcorr = shift;
    my $matt = shift;
    my $binning = shift;
    my $skiptext = shift;
    my $use_filter = shift;
    my $filter1 = shift;
    my $filter2 = shift;
    my $filter3 = shift;
    my $filter4 = shift;


    my $processstring = "xfalign";

    $processstring.= " -param $param";

    if ($initial == 1) {
	$processstring.= " -initial \"$tempdir$tempxf1\"";
    }

    if ($prexcorr eq "on") {
	$processstring.= " -prexcorr";
    }

    if ($matt != 0) {
	$processstring.= " -matt $matt";
    }

    if ($binning != 2) {
	$processstring.= " -reduce $binning";
    }

    if ($skiptext ne "") {
	$skiptext =~ s/\s+//g;
	print "$skiptext\n";
	my @newskiparray;
	my @skiparray = split (',', $skiptext);
	foreach my $element (@skiparray) {
	    if ($element =~ m/(\d+)-(\d+)/) {
		push (@newskiparray, ($1-1), "-", ($2-1));
	    }
	    elsif ($element =~ m/^(\d+)$/) {
		push (@newskiparray, ($1-1));
	    }
	    push (@newskiparray, ",");
	}
	pop @newskiparray;
	$skiptext = join ("", @newskiparray);

	print "$skiptext\n";
	$processstring.= " -skip $skiptext";
    }



    if ($use_filter eq "on") {
	$processstring.= " -filter $filter1,$filter2,$filter3,$filter4";
    }

    if ($initial == 1) {
	$processstring.= " \"$tempdir$tempmrc\" \"$tempdir$tempxf2\"";
    }
    else {
	$processstring.= " \"$tempdir$tempmrc\" \"$tempdir$tempxf1\"";
    }

    my $xfalign;
    print "|$processstring \n";
    open ($xfalign, "|$processstring") or die "xfalign nicht gestartet";
    $top0->update;
    return 1;
}



sub midasalign {
    my $top0 = shift;
    my $tempmrc = shift;
    my $tempxf1 = shift;
    my $tempdir = shift;

    my $midas;
    print "|midas \"$tempdir$tempmrc\" \"$tempdir$tempxf1\"";
    open ($midas, "|midas \"$tempdir$tempmrc\" \"$tempdir$tempxf1\"") or die "midas nicht gestartet";
    $top0->update;
    return 1;

}


sub preview {
    my $top0 =shift;
    my $filearray = shift;
    my $tempmrc = shift;
    my $tempxg = shift;
    my $alignfile = shift;
    my $tempaligned = shift;
    my $tempdir = shift;
    my $userefsclice = shift;
    my $slicenumber = shift;
    my $trendsparameter = shift;
    my $prevparam = shift;
    my $borderfill = shift;

    my $previewmrc = "$tempaligned\.prev";

    my $resizestring = "-o $filearray->{thumbmaxwidth}\,$filearray->{thumbmaxheight}";


    my $xftoxg;
    my $refstring = "";
    if ($userefslice eq "on") {
	$refstring = "-ref $slicenumber";
    }

    my $trends;

    if ($trendsparameter ne "") {
	$trends = "$trendsparameter ";
    }
    else {
	$trends = "";
    }


    my $preventtrends = "";

    if ($prevparam ne "0") {
	my $prevparamnumber = $prevparam + 1; #slider from 0 to 3, useable parameters 2 (translation),3 (rotation), 4 (magnification)
	$preventtrends = " -mixed ".$prevparamnumber;
    }

    print "xftoxg ${trends}${refstring}${preventtrends} \"$tempdir$alignfile\" \"$tempdir$tempxg\"\n";

    open ($xftoxg, "|xftoxg ${trends}${refstring}${preventtrends} \"$tempdir$alignfile\" \"$tempdir$tempxg\"") or die "xftofxg nicht gestartet";
    close $xftoxg;
    $top0->update;


    my $newstack;
    my $newstackstring = "newstack -fill $borderfill -xform \"$tempdir$tempxg\" \"$tempdir$tempmrc\" \"$tempdir$previewmrc\"";
    print "$newstackstring\n";
    open ($newstack, "|$newstackstring") or die "newstack nicht gestartet";
    close $newstack;
    $top0->update;


    my $imodpreview;
    my $imodstring = "3dmod \"$tempdir$previewmrc\"";
    open ($imodpreview, "|$imodstring") or die "imod not started";
    return 1;
}


=command
sub convert_transform {
    my $top0 =shift;
    my $filearray = shift;
    my $tempmrc = shift;
    my $tempxg = shift;
    my $alignfile = shift;
    my $tempaligned = shift;
    my $tempdir = shift;
    my $userefsclice = shift;
    my $slicenumber = shift;
    my $trendsparameter = shift;

# generate xg-file with parameters
    my $resizestring = "-o $filearray->{maxwidth}\,$filearray->{maxheight}";
    my $xftoxg;
    my $refstring = "";
    if ($userefslice eq "on") {
	$refstring = "-ref $slicenumber";
    }
    my $trends;
    if ($trendsparameter ne "none") {
	$trends = "-n $trendsparameter";
    }
    else {
	$trends = "";
    }
    if ($reduce != 1) {
	my @outarray;
	my $filename;
	my $line;
	my $xyscale = 1 / $reduce;
	open (XFDAT, "<${tempdir}${alignfile}") or die ("\nkann Datei ${tempdir}${alignfile} nicht oeffnen\n");
	while ($line = <XFDAT>) {
	    if ($line =~ m/\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
		my $newline = sprintf " % 11.7f % 11.7f % 11.7f % 11.7f % 11.3f % 11.3f\n", $1, $2, $3, $4, $5 * $xyscale, $6 * $xyscale;
		push (@outarray, $newline);
	    }
	    else {
		push (@outarray, $line);
	    }
	}
	close XFDAT;
	$alignfile = "${alignfile}\.scaled";
	open (XFOUTDAT, ">${tempdir}${alignfile}") or die ("\nkann Datei ${tempdir}${alignfile} nicht oeffnen\n");
	foreach $line (@outarray) {
	    print XFOUTDAT $line
	}
	close XFOUTDAT;
    }
    else {
	my $copyxffile;
	open ($copyxffile, "|cp ${tempdir}${alignfile} ${tempdir}${alignfile}\.scaled") or die "can not copy ${tempdir}${alignfile} ${tempdir}${alignfile}\.scaled\n";
	$alignfile = "${alignfile}\.scaled";
    }

    open ($xftoxg, "|xftoxg $trends $refstring \"$tempdir$alignfile\" \"$tempdir$tempxg\"") or die "xftofxg nicht gestartet";
    close $xftoxg;
    $top0->update;

# extending the images with black border
    my @borderarray;
    for my $file (@{$filearray->{arrayref}}) {
	my ($filename) = $file=~ m/\/([^\/]+)$/;
	my $borderfile = $tempdir.$filename."\.bordered\.tif";
	my $canvassize = "$filearray->{maxwidth}x$filearray->{maxheight}";
	my $bordercolor = "black";
	my $convert;
	print "|convert $file -gravity center -background $bordercolor -extent $canvassize $borderfile\n";
	open ($convert, "|convert $file -gravity center -background $bordercolor -extent $canvassize $borderfile") or die "\n imagemagick-convert -extend failed";
	print "\nextended $borderfile to $canvassize";
	push (@borderarray, $borderfile);
	close $convert;
    }

# transforming the images



    my $xgfile;
    my @transformations;
    open ($xgfile, "<$tempdir$tempxg") or die "\ncan not open xg-file\n";
    while (my $line = <$xgfile>) {
	push (@transformations, $line);
    }


    close $xftoxg;

    my $counter = 0;
    foreach my $file (@borderarray) {

	my $dirpath;
	my $extension_old;
	my $filename_old;

	($dirpath) = $file =~ m/(^.*\/)/;
	($extension_old) = $file =~ m/(\.[^\.]+)$/;
	($filename_old) = $file =~ m/\/([^\/]+)\.[^\.]+$/;

	my $newfilestring = " \"${dirpath}imodal_${filename_old}${extension_old}\"";
	my $transformstring = $transformations[$counter];
	$transformstring =~ s/^\s+//;
	$transformstring =~ s/\s+$//;
	my @transformstring = split (/\s+/, $transformstring);
	$transformstring = join (",", @transformstring);
	#print "\n$transformstring";
	$counter++;

	my $convert;
	print "|convert $file -virtual-pixel black -distort AffineProjection $transformstring $newfilestring\n";
	open ($convert, "|convert $file -virtual-pixel black -distort AffineProjection $transformstring $newfilestring") or die "\n imagemagick-convert -transform failed";
	print "\transformed $file to $newfilestring";
	close $convert;

	$top0->update;
    }






}
=cut


sub transform {
    my $top0 =shift;
    my $filearray = shift;
    my $reduce = shift;
    my $tempmrc = shift;
    my $tempxg = shift;
    my $alignfile = shift;
    my $tempaligned = shift;
    my $tempdir = shift;
    my $userefsclice = shift;
    my $slicenumber = shift;
    my $trendsparameter = shift;
    my $prevparam = shift;
    my $progressbar = shift;
    my $writetransformations = shift;
    my $borderfill = shift;

    my $tempgray = "tempgray.mrc";
    my $temprgb = "temprgb.mrc";
    my $tempr = "temp.r";
    my $tempg = "temp.g";
    my $tempb = "temp.b";
    my $tempalr = "tempal.r";
    my $tempalg = "tempal.g";
    my $tempalb = "tempal.b";


    my $xftoxg;
    my $refstring = "";
    if ($userefslice eq "on") {
	$refstring = "-ref $slicenumber";
    }


    my $trends;

    if ($trendsparameter ne "") {
	$trends = "$trendsparameter ";
    }
    else {
	$trends = "";
    }


    my $preventtrends = "";

    if ($prevparam ne "0") {
	my $prevparamnumber = $prevparam + 1; #slider from 0 to 3, useable parameters 2 (translation),3 (rotation), 4 (magnification)
	$preventtrends = " -mixed ".$prevparamnumber;
    }


    if ($reduce != 1) {

	my @outarray;
	my $filename;
	my $line;

	my $xyscale = 1 / $reduce;

	open (XFDAT, "<${tempdir}${alignfile}") or die ("\nkann Datei ${tempdir}${alignfile} nicht oeffnen\n");

	while ($line = <XFDAT>) {

	    if ($line =~ m/\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {

		my $newline = sprintf " % 11.7f % 11.7f % 11.7f % 11.7f % 11.3f % 11.3f\n", $1, $2, $3, $4, $5 * $xyscale, $6 * $xyscale;
		push (@outarray, $newline);
	    }

	    else {
		push (@outarray, $line); #sollte das hier nicht besser abbrechen, wenn Zeilen auftauchen, die nicht Transformationsdaten enhalten?
	    }

	}



	close XFDAT;

	$alignfile = "${alignfile}\.scaled";

	open (XFOUTDAT, ">${tempdir}${alignfile}") or die ("\nkann Datei ${tempdir}${alignfile} nicht oeffnen\n");

	foreach $line (@outarray) {
	    print XFOUTDAT $line
	}
	close XFOUTDAT;
    }

    else {
	my $copyxffile;
	open ($copyxffile, "|cp ${tempdir}${alignfile} ${tempdir}${alignfile}\.scaled") or die "can not copy ${tempdir}${alignfile} ${tempdir}${alignfile}\.scaled\n";

	$alignfile = "${alignfile}\.scaled";

    }

    print "xftoxg ${trends}${refstring}${preventtrends} \"$tempdir$alignfile\" \"$tempdir$tempxg\""; 

    open ($xftoxg, "|xftoxg ${trends}${refstring}${preventtrends} \"$tempdir$alignfile\" \"$tempdir$tempxg\"") or die "xftofxg nicht gestartet";
    close $xftoxg;
    $top0->update;

    my $xglinenumber = 0;
    my $stepsdone = 0;


    if ($writetransformations eq "on") {

	open (XGDAT, "<${tempdir}${tempxg}") or die ("\nkann Datei ${tempdir}${tempxg} nicht oeffnen\n");

	my @xgarray;

	while (my $line = <XGDAT>) {

	    #print "$line \njetzt array\n";

	    #$line =~ s/\s+/\;/g;
	    push (@xgarray, $line);
	    #print @xgarray;

	}
	close XGDAT;

	my @transformationlist;
	my $dirpath;

	foreach my $file (@{$filearray->{arrayref}}) {
	    # my ($filestring) = $file =~ m/\/([^\/]+\.[^\.]+$)/;
	    ($dirpath) = $file =~ m/(^.*\/)/;


	    my $imageinfohash = Image::ExifTool::ImageInfo($file);
#	    print "PhotometricInterpretation => $imageinfohash->{'PhotometricInterpretation'}\n";
	    print "ImageHeight => $imageinfohash->{'ImageHeight'}\n";
	    print "ImageWidth => $imageinfohash->{'ImageWidth'}\n";



#recalculate x and y transformation because of the different center in calculation and coordinate system
	    $xgarray[$xglinenumber] =~ s/^\s+//; #cut off leading whitespaces
#	    print "xgarray = $xgarray[$xglinenumber]\n";
	    my @transformarray = split(/\s+/,$xgarray[$xglinenumber]);

#	    print "0= $transformarray[0]\n1 = $transformarray[1]\n2 = $transformarray[2]\n3 = $transformarray[3]\n4 = $transformarray[4]\n maxheight = $filearray->{maxheight}\n";

#           imod-transformations (calculated from image center?)
#           X' = A11 * (X - Xc) + A12 * (Y - Yc) + DX + Xc
#           Y' = A21 * (X - Xc) + A22 * (Y - Yc) + DY + Yc


	    my $xshift1 = (($imageinfohash->{'ImageWidth'}/2 * $transformarray[0]) + ((($imageinfohash->{'ImageHeight'}/2)) * $transformarray[1]));
	    my $yshift1 = (($imageinfohash->{'ImageWidth'}/2 * $transformarray[2]) + ((($imageinfohash->{'ImageHeight'}/2)) * $transformarray[3]));

	    my $xshift = $filearray->{'maxwidth'}/2 - (($imageinfohash->{'ImageWidth'}/2 * $transformarray[0]) + (-($imageinfohash->{'ImageHeight'}/2) * $transformarray[1]));
	    my $yshift = -$filearray->{'maxheight'}/2 - (($imageinfohash->{'ImageWidth'}/2 * $transformarray[2]) + (-($imageinfohash->{'ImageHeight'}/2) * $transformarray[3]));


# atrakem = aimod * (xcentertrakem / xcenterimod) = $transformarray_trakem[0] = $transformarray[0] * (($imageinfohash->{'ImageWidth'}/2) / $filearray->{'maxwidth'}/2))
# btrakem = bimod * (ycentertrakem / ycenterimod) = $transformarray_trakem[1] = $transformarray[1] * (($imageinfohash->{'ImageHeight'}/2) / $filearray->{'maxheight'}/2))
# ctrakem = cimod * (xcentertrakem / xcenterimod) = $transformarray_trakem[2] = $transformarray[2] * (($imageinfohash->{'ImageWidth'}/2) / $filearray->{'maxwidth'}/2))
# dtrakem = dimod * (ycentertrakem / ycenterimod) = $transformarray_trakem[3] = $transformarray[3] * (($imageinfohash->{'ImageHeight'}/2) / $filearray->{'maxheight'}/2))

#	    my $newa = $transformarray[0] * (($filearray->{'maxwidth'}/2) / ($imageinfohash->{'ImageWidth'}/2));
#	    my $newb = $transformarray[1] * (($filearray->{'maxheight'}/2) / ($imageinfohash->{'ImageHeight'}/2));
#	    my $newc = $transformarray[2] * (($filearray->{'maxwidth'}/2) / ($imageinfohash->{'ImageWidth'}/2));
#	    my $newd = $transformarray[3] * (($filearray->{'maxheight'}/2) / ($imageinfohash->{'ImageHeight'}/2));


	    my $newa = $transformarray[0];
	    my $newb = -$transformarray[2];
	    my $newc = -$transformarray[1];
	    my $newd = $transformarray[3];

	    my $newx = $xshift + $transformarray[4];
	    my $newy = -($yshift + $transformarray[5]);



	    print "\nxshift = $xshift\nyshift = $yshift\n\n";

	    print "\nxshift1 = $xshift1\nyshift1 = $yshift1\n";
	    print "\nxtransform = $transformarray[4]\nytransform = $transformarray[5]\n";



	    my $oldtransformations = "$transformarray[0] $transformarray[1] $transformarray[2] $transformarray[3] $transformarray[4] $transformarray[5]\n";
	    print "imod transformations $oldtransformations\n";


	    my $newtransformations = "$newa $newb $newc $newd $newx $newy\n";
	    print "trakem transformations $newtransformations\n";

	    push (@transformationlist, $file, " ", $newtransformations);
#	    print "$xglinenumber : $xgarray[$xglinenumber]\n";
	    $xglinenumber++;

	}
	my $tffile = "imod_transformations.txt";

	open (TRLIST, ">${dirpath}${tffile}") or die ("\nkann Datei ${dirpath}${tffile} nicht oeffnen\n");

	foreach my $line (@transformationlist) {

	    $line =~ s/\ +/\ /g;
	    print TRLIST $line;
	}

	close TRLIST;


    }

    else {


	my $resizestring = "-o $filearray->{maxwidth}\,$filearray->{maxheight}";
	my $borderfillstring = "-F $borderfill";

	foreach my $file (@{$filearray->{arrayref}}) {

	    my $filestring = "\"$file\"";


	    if ($filearray->{imagetype} eq "RGB") {

		#my $filestring = join(" ", @{$filearray->{newarrayref}});
		my $process;
		print "|tif2mrc $resizestring $borderfillstring $filestring \"$tempdir$temprgb\" \n";
		open ($process, "|tif2mrc $resizestring $borderfillstring $filestring \"$tempdir$temprgb\"") or die "tif2mrc nicht gestartet";
		close $process;
		$top0->update;

		my $splitrgb;
		my $splitrgbstring = "clip splitrgb \"$tempdir$temprgb\" \"${tempdir}temp\"";
		open ($splitrgb, "|$splitrgbstring") or die "clip splitrgb nicht gestartet";
		close $splitrgb;
		$stepsdone++;
		$progressbar->value($stepsdone);
		$top0->update;

		my $newstack;
		my $newstackstring = "newstack -fill $borderfill -xform \"$tempdir$tempxg\" -useline $xglinenumber \"$tempdir$tempr\" \"$tempdir$tempalr\"";
		open ($newstack, "|$newstackstring") or die "newstack nicht gestartet";
		close $newstack;
		$top0->update;

		$newstackstring = "newstack -fill $borderfill -xform \"$tempdir$tempxg\" -useline $xglinenumber \"$tempdir$tempg\" \"$tempdir$tempalg\"";
		open ($newstack, "|$newstackstring") or die "newstack nicht gestartet";
		close $newstack;
		$top0->update;

		$newstackstring = "newstack -fill $borderfill -xform \"$tempdir$tempxg\" -useline $xglinenumber \"$tempdir$tempb\" \"$tempdir$tempalb\"";
		open ($newstack, "|$newstackstring") or die "newstack nicht gestartet";
		close $newstack;
		$stepsdone++;
		$progressbar->value($stepsdone);
		$top0->update;

		my $joinrgb;
		my $joinrgbstring = "clip joinrgb \"$tempdir$tempalr\" \"$tempdir$tempalg\" \"$tempdir$tempalb\" \"$tempdir$tempaligned\"";
		open ($joinrgb, "|$joinrgbstring") or die "clip splitrgb nicht gestartet";
		close $joinrgb;
		$stepsdone++;
		$progressbar->value($stepsdone);
		$top0->update;

		unlink ("$tempdir$tempr", "$tempdir$tempalr", "$tempdir$tempg", "$tempdir$tempalg", "$tempdir$tempb", "$tempdir$tempalb", "$tempdir$temprgb");

	    }
	    else {

		#my $filestring = join(" ", @{$filearray->{newarrayref}});
		my $process;
		print "|tif2mrc $resizestring $borderfillstring $filestring \"$tempdir$tempgray\" \n";
		open ($process, "|tif2mrc $resizestring $borderfillstring $filestring \"$tempdir$tempgray\"") or die "tif2mrc nicht gestartet";
		close $process;
		$stepsdone++;
		$progressbar->value($stepsdone);
		$top0->update;


		my $newstack;
		my $newstackstring = "newstack -fill $borderfill -xform \"$tempdir$tempxg\" -useline $xglinenumber \"$tempdir$tempgray\" \"$tempdir$tempaligned\"";
		print "$newstackstring\n";
		open ($newstack, "|$newstackstring") or die "newstack nicht gestartet";
		close $newstack;
		$stepsdone += 2;
		$progressbar->value($stepsdone);
		$top0->update;

	    }

	    $xglinenumber++;

# write tif from mrc-file

	    my $mrc2tif;
	    open ($mrc2tif, "|mrc2tif \"$tempdir$tempaligned\" \"${tempdir}tempaligned.tif\"") or die "mrc2tif nicht gestartet";
	    close $mrc2tif;
	    $top0->update;

	    my $dirpath;
	    my $extension_old;
	    my $filename_old;

	    ($dirpath) = $file =~ m/(^.*\/)/;
	    ($extension_old) = $file =~ m/(\.[^\.]+)$/;
	    ($filename_old) = $file =~ m/\/([^\/]+)\.[^\.]+$/;


	    my $move;
	    my $movestring = "mv \"${tempdir}tempaligned.tif\" \"${dirpath}imodal_${filename_old}${extension_old}\"";
	    print "$movestring\n";
	    open ($move, "|$movestring") or die "mv nicht gestartet";
	    close $move;
	    $top0->update;
	}

    }

}



=command
sub write_tifs {
    my $top0 = shift;
    my $filearray = shift;
    my $tempaligned = shift;
    my $tempdir = shift;


    my $mrc2tif;
    open ($mrc2tif, "|mrc2tif \"$tempdir$tempaligned\" \"${tempdir}tempaligned\"") or die "mrc2tif nicht gestartet";
    close $mrc2tif;
    $top0->update;


    my $counter = 0;
    my $file;
    foreach $file (@{$filearray->{arrayref}}) {

	my $dirpath;
	my $extension_old;
	my $filename_old;

	($dirpath) = $file =~ m/(^.*\/)/;
	($extension_old) = $file =~ m/(\.[^\.]+)$/;
	($filename_old) = $file =~ m/\/([^\/]+)\.[^\.]+$/;

	my $counterform = sprintf ("%03d", $counter);

	my $move;
	my $movestring = "mv \"${tempdir}tempaligned\.$counterform\.tif\" \"${dirpath}imodal_${filename_old}${extension_old}\"";
	print "$movestring\n";
	open ($move, "|$movestring") or die "mv nicht gestartet";
	close $move;
	$top0->update;

	$counter++;

    }


}
=cut




package ImageObject;

use strict;
use warnings;
use Image::ExifTool;

sub new {
    my $type = shift;
    my $class = ref($type) || $type;

    my $self = {@_};

    unless (defined ($self->{filepath})) {
	die "no filepath given for ImageObject\n";  
	$self->{filepath} = "";
    }

    unless (defined ($self->{width})) {
	die "no width given for ImageObject\n";
    }

    unless (defined ($self->{height})) {
	die "no height given for ImageObject\n";
    }

    unless (defined ($self->{imagetype})) {
	die "no colormode given for ImageObject\n";
    }


    bless($self, $class); #das ganze wird zu einem Objekt gemacht



    return $self;

}


sub setparameters {
    my $self = {@_};


    return $self;
}






package ImageArrayIn;

# use 5.008001;
use strict;
use warnings;
use Image::ExifTool;



sub new {
    my $type = shift;
    my $class = ref($type) || $type;

    my $self = {@_};



    unless (defined ($self->{reduce})) {
	$self->{reduce} = 0.1;
    }

    unless (defined ($self->{maxwidth})) {
	$self->{maxwidth} = 10;
    }

    unless (defined ($self->{maxheight})) {
	$self->{maxheight} = 10;
    }

    unless (defined ($self->{imagetype})) {
	$self->{imagetype} = "GRAY";
    }

    unless (defined ($self->{imageObjectlist})) {
	$self->{imageObjectlist} = [];
    }




    bless($self, $class); #das ganze wird zu einem Objekt gemacht


    if ($self->{arrayref}) {
	$self->readarray();
	$self->makethumbimages();
    }


    return $self;

}



sub generateimagearray {

    my $self = shift;
    my %parameter = @_;

    if ($parameter{arrayref}) {
	$self->{arrayref} = $parameter{arrayref};
    }

    unless ($self->{arrayref}) {
	die "no reference to array given\n";
    }
    else {
	foreach my $element (@{$self->{arrayref}}) {

	    print "image = $element\n";

	    my $imageinfohash = Image::ExifTool::ImageInfo($element);
	    print "PhotometricInterpretation => $imageinfohash->{'PhotometricInterpretation'}\n";
	    print "ImageHeight => $imageinfohash->{'ImageHeight'}\n";
	    print "ImageWidth => $imageinfohash->{'ImageWidth'}\n";


# generate ImageObject
	    my $imageobject = ImageObject->new(filepath => $element, width => $imageinfohash->{'ImageWidth'}, height => $imageinfohash->{'ImageHeight'}, $imageinfohash->{'PhotometricInterpretation'}); 

# append ImageObject to list of Images

	    push (@{$self->{imageObjectlist}}, $imageobject);


# determine parameters for comlete list
	    if ($imageinfohash->{'ImageHeight'} > $self->{maxheight}) {
		$self->{maxheight} =  $imageinfohash->{'ImageHeight'};
	    }

	    if ($imageinfohash->{'ImageWidth'} > $self->{maxwidth}) {
		$self->{maxwidth} =  $imageinfohash->{'ImageWidth'};
	    }

	    if ($imageinfohash->{'PhotometricInterpretation'} eq "RGB") {
		$self->{imagetype} =  $imageinfohash->{'PhotometricInterpretation'};
	    }

	    elsif ($imageinfohash->{'PhotometricInterpretation'} eq "RGB Palette") {
		$self->{imagetype} =  "RGB";
	    }

	    elsif (($imageinfohash->{'PhotometricInterpretation'} eq "BlackIsZero") && (not($self->{imagetype} eq  "RGB")))   {
		$self->{imagetype} =  "GRAY";
	    }
	    elsif (($imageinfohash->{'PhotometricInterpretation'} eq "WhiteIsZero") && (not($self->{imagetype} eq  "RGB"))) {
		$self->{imagetype} =  "GRAY";
	    }

	    elsif (($imageinfohash->{'PhotometricInterpretation'} eq "BlackIsZero") || ($imageinfohash->{'PhotometricInterpretation'} eq "WhiteIsZero") && ($self->{imagetype} eq  "RGB"))   {
		# $self->{imagetype} =  "GRAY";
		die "can not use rgb and grayscale images together\n";

	    }

	    else {
		die "Imagetype $imageinfohash->{'PhotometricInterpretation'} not supported\n";
	    }

	    if ($imageinfohash->{'SamplesPerPixel'} > 3) {
		die "images with more than 3 channels are not supported\n";
	    }


	    if (($imageinfohash->{'Directory'}) and not ($self->{imagedirectory})) {
		$self->{imagedirectory} = $imageinfohash->{'Directory'};
	    }

	}

    }


}



sub extendimagearray {


}




sub readarray {
    my $self = shift;
    my %parameter = @_;

    if ($parameter{arrayref}) {
	$self->{arrayref} = $parameter{arrayref};
    }

    unless ($self->{arrayref}) {
	die "no reference to array given\n";
    }
    else {
#put backslashes into filename and path if there are non alphanumeric signs
	my @newarray;
	foreach my $element (@{$self->{arrayref}}) {
	    my $newname =  $element;
	    $newname = "\"$newname\""; #=~ s/([^\w\.\/])/\\$1/g;
	    push (@newarray, $newname);

	}

	$self->{newarrayref} = \@newarray;

	$self->{filenumber} = $#newarray + 1;

	foreach my $element (@{$self->{arrayref}}) {

	    print "image = $element\n";

	    my $imageinfohash = Image::ExifTool::ImageInfo($element);
	    print "PhotometricInterpretation => $imageinfohash->{'PhotometricInterpretation'}\n";
	    print "ImageHeight => $imageinfohash->{'ImageHeight'}\n";
	    print "ImageWidth => $imageinfohash->{'ImageWidth'}\n";

	    if ($imageinfohash->{'ImageHeight'} > $self->{maxheight}) {
		$self->{maxheight} =  $imageinfohash->{'ImageHeight'};
	    }

	    if ($imageinfohash->{'ImageWidth'} > $self->{maxwidth}) {
		$self->{maxwidth} =  $imageinfohash->{'ImageWidth'};
	    }

	    if ($imageinfohash->{'PhotometricInterpretation'} eq "RGB") {
		$self->{imagetype} =  $imageinfohash->{'PhotometricInterpretation'};
	    }

	    elsif ($imageinfohash->{'PhotometricInterpretation'} eq "RGB Palette") {
		$self->{imagetype} =  "RGB";
	    }

	    elsif (($imageinfohash->{'PhotometricInterpretation'} eq "BlackIsZero") && (not($self->{imagetype} eq  "RGB")))   {
		$self->{imagetype} =  "GRAY";
	    }
	    elsif (($imageinfohash->{'PhotometricInterpretation'} eq "WhiteIsZero") && (not($self->{imagetype} eq  "RGB"))) {
		$self->{imagetype} =  "GRAY";
	    }

	    elsif (($imageinfohash->{'PhotometricInterpretation'} eq "BlackIsZero") || ($imageinfohash->{'PhotometricInterpretation'} eq "WhiteIsZero") && ($self->{imagetype} eq  "RGB"))   {
		# $self->{imagetype} =  "GRAY";
		die "can not use rgb and grayscale images together\n";

	    }

	    else {
		die "Imagetype $imageinfohash->{'PhotometricInterpretation'} not supported\n";
	    }

	    if ($imageinfohash->{'SamplesPerPixel'} > 3) {
		die "images with more than 3 channels are not supported\n";
	    }


	    if (($imageinfohash->{'Directory'}) and not ($self->{imagedirectory})) {
		$self->{imagedirectory} = $imageinfohash->{'Directory'};
	    }
	}


	unless ($self->{imagedirectory}) {
	    die "can not determine path to images\n"
	}


    }

}





sub makethumbimages {
    my $self = shift;
    my %parameter = @_;

    if ($parameter{reduce}) {
	$self->{reduce} = $parameter{reduce};
    }

    if ($parameter{progressbar}) {
	$self->{progressbar} = $parameter{progressbar};
    }

    print "\n###############\nreduce = $reduce, \$self->\{reduce\} = $self->{reduce}\n";


    my @thumbarray;

    my $stepsdone= 0;

    if ($self->{reduce} != 1) {
	for my $file (@{$self->{arrayref}}) {
	    my ($filename) = $file=~ m/\/([^\/]+)$/;
	    my $reducefile = $tempdir.$filename;
	    my $convert;
	    my $procentreduce = int(100*$self->{reduce});
	    print "\n|convert $file -resize $procentreduce\% $reducefile\n";
	    open ($convert, "|convert \"$file\" -resize $procentreduce\% \"$reducefile\"") or die "\n imagemagick-convert failed";
	    print "\n$file resized with $self->{reduce} to $reducefile";
	    push (@thumbarray, $reducefile);
	    #print "\n$self->{progressbar}\n";
	    if ($self->{progressbar}) {
		$self->{progressbar}->value($stepsdone);
		$top0->update;
		}
	    #print "$stepsdone\n";
	    $stepsdone++;
	}

	$self->{thumbarrayref} = \@thumbarray;
	$self->{thumbmaxheight} = int($self->{maxheight} * $self->{reduce} + 0.5);
	$self->{thumbmaxwidth} = int($self->{maxwidth} * $self->{reduce} + 0.5);
	$self->{thumbimagetype} = $self->{imagetype};


    }

    else {
	$self->{thumbarrayref} = $self->{arrayref};
	$self->{thumbmaxheight} = $self->{maxheight};
	$self->{thumbmaxwidth} = $self->{maxwidth};
	$self->{thumbimagetype} = $self->{imagetype};
    }



#####



####



    return $self;

}







sub setimagesize {
    my $self = shift;
    my %parameter = @_;


    unless (($parameter{width}) || ($parameter{height})) {
	die "Module ImageArray::setimagesize: no width or height given\n";
    }


    if ($parameter{width}) {
	$self->{maxwidth} = $parameter{width};
    }

    if ($parameter{height}) {
	$self->{maxheight} = $parameter{height};
    }

    if ($self->{thumbarrayref}) {
	$self->{thumbmaxheight} = int($self->{maxheight} * $self->{reduce} + 0.5);
	$self->{thumbmaxwidth} = int($self->{maxwidth} * $self->{reduce} + 0.5);
    }




    return $self;
}




sub setreduce {
    my $self = shift;
    my %parameter = @_;


    unless ($parameter{reduce}) {
	die "Module ImageArray::scaleimages: no scale-value given\n";
    }

    if ($parameter{reduce}) {
	$self->{reduce} = $parameter{reduce};
    }


    return $self;
}








return 1;





# midas $tempmrc $tempxf1


=command

my $programpath = realpath(); #Verzeichnis in dem dieses Programm liegt
my $process;
open ($process, "|schalter_man.exe") or die "schalter_man.exe nicht gestartet";
=cut
