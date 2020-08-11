<html>

<?php
//////////////////////////////////////////////////////////////////
// If you are willing to use this file in different configuration,
// please modify following 5 row with respect to your environment.
//////////////////////////////////////////////////////////////////
$target_folder="../cyclops/images/";
$mote_start=101;
$mote_end=120;
$column=4;
//////////////////////////////////////////////////////////////////

$targetfile="";
$targetftime="0000-00-00 00:00:00";
$preffile="";
$prefftime="0000-00-00 00:00:00";

function system_to_htmllink($cmd) {
    global $target_folder;
    exec("$cmd", $sysout);
    $ret .= "<p>\n";
    foreach($sysout as $line) {
        $line = htmlentities($line);
		$ret .= date("Y-m-d H:i:s", filemtime($target_folder.$line));
        $ret .= " - <a href=$target_folder$line>$line</a>\n";
        $ret .= "<br>\n";
    }   
    $ret .= "</p>\n";
    return $ret;
}   

function system_cmd($cmd) {
    exec("$cmd", $sysout);
    return $sysout;
}

function getImagePath_old($mote_num) 
{
	global $target_folder;
	global $targetfile;
    global $targetftime;
	$latesttime=0;
    $cnt = 0;

	if ($handle = opendir($target_folder)) {
	    while (($file = readdir($handle)) != false) {
		if ($file != "." && $file != "..") {
			if (substr($file, strlen($file)-3, 3)=="jpg"
			|| substr($file, strlen($file)-3, 3)=="bmp"
			|| substr($file, strlen($file)-3, 3)=="gif") {
			    $FileArray[] = $file;
			    if(preg_match("/mote$mote_num/i", $file)) {
				$targettime = date("YmdHis", filemtime($target_folder.$file));
				if ($latesttime <= $targettime) {
					$targetfile = $file;
					$latesttime = $targettime;
					$targetftime = date("Y-m-d H:i:s", filemtime($target_folder.$file));
                    $cnt = 1;
				}
				//echo $file."\n".$targetftime;
			    }
			}
		}
	    }
	}
	closedir($handle);
	return $cnt;
}

function getImagePath($mote_num) 
{
	global $target_folder;
	global $targetfile;
	global $targetftime;
	global $prevfile;
	global $prevftime;

    $motename = "mote$mote_num";
    $search = "ls $target_folder | grep $motename | grep bmp | wc -l";
    $result = system_cmd($search);
    $cnt = $result[0];
    if ($cnt != 0) {
        $search = "ls -tr $target_folder | grep $motename | grep bmp | tail -n 1";
        $result = system_cmd($search);
        $targetfile = $result[0];
        //$targetftime = date("YmdHis", filemtime($target_folder.$targetfile));
        $targetftime = date("Y-m-d H:i:s", filemtime($target_folder.$targetfile));
    }
    if ($cnt > 1) {
        $search = "ls -tr $target_folder | grep $motename | grep bmp | tail -n 2 | head -n 1";
        $result = system_cmd($search);
        $prevfile = $result[0];
        //$prevftime = date("YmdHis", filemtime($target_folder.$prevfile));
        $prevftime = date("Y-m-d H:i:s", filemtime($target_folder.$prevfile));
    }
	return $cnt;
}

function showImageTable() 
{
    global $mote_start;
    global $mote_end;
	global $target_folder;
	global $targetfile;
	global $targetftime;
	global $prevfile;
	global $prevftime;
	global $column;

    print "<table border=0 cellpadding=5 cellspacing=1>\n";
    $j = 0;

    for ($i = $mote_start; $i <= $mote_end; $i++) {
        $cnt = getImagePath($i);

        if ($cnt != 0) {
            if (($j%$column) == 0) {
                print "<tr>\n";
            }
            print "<td><center>\n";
            //print "<h3>mote$i</h3>\n";
            print "<a href=\"jrviewer.php?mote=$i\"><font color=black><h3>mote$i</h3></font></a>\n";
            print "<img src=\"$target_folder/$targetfile\"><br><br>\n";
            print "<font size=2>$targetfile<br>$targetftime<br></font>\n"; 
            print "</center></td>\n";
            if ((($j+1)%$column) == 0) {
                print "</tr>\n";
            }
            $j = $j + 1;
        }

        if ($cnt > 1) {
            if (($j%$column) == 0) {
                print "<tr>\n";
            }
            print "<td><center>\n";
            print "<h5><font color=grey>mote$i-prev</font></h5>\n";
            print "<img src=\"$target_folder/$prevfile\"><br><br>\n";
            print "<font size=2>$prevfile<br>$prevftime<br></font>\n"; 
            print "</center></td>\n";
            if ((($j+1)%$column) == 0) {
                print "</tr>\n";
            }
            $j = $j + 1;
        }
    }
    if ((($j)%$column) != 0) {
        print "</tr>\n";
    }
    print "</table>\n";
}

function showMoteImageList($mote_id) 
{
    global $target_folder;

    if ($mote_id == null) {
        $search = "ls -t $target_folder | grep mote[123456789] | grep bmp";
    } 
    else {
        $search = "ls -t $target_folder | grep mote$mote_id | grep bmp";
    }
    $result = system_cmd($search);
    if ($result != null) {
        if ($mote_id == null) {
            print "<h4> All motes, sorted by time.</h4>\n";
        } else {
            print "<h4>mote$mote_id</h4>\n";
        }
        print "<small>\n";
        print system_to_htmllink($search);
        print "</small>\n";
    }
}

function showEveryMoteImageList() 
{
    global $mote_start;
    global $mote_end;

    #$mote_array = array(101,102,103,104,105,106,107,108,109,110,111,112,113,114);
    #foreach($mote_array as $i) {
    for ($i = $mote_start; $i <= $mote_end; $i++) {
        showMoteImageList($i);
    }
}
?>


<!-- ACTUAL HTML FILE GENERATION BEGINS HERE -->
<?php

$title = "JR Tenet/Cyclops Image Viewer";

print "<head>\n";
print "<title>$title</title>\n\n";

$mote = $_GET['mote'];
if ($mote == null) {
    print "<meta http-equiv=\"refresh\" content=\"10\">\n";
    print "</head>\n<body>\n";
    print "<h2>JR Tenet/Cyclops Image Viewer</h2><hr>\n";
    showImageTable();
    print "<hr>\n";
    print "<a href=\"jrviewer.php?mote=time\"><h5>List of all image files in chronicle order</h5></a>\n";
    print "<a href=\"jrviewer.php?mote=all\"><h5>List of all image files for each mote</h5></a>\n";
    echo "<small>Last refreshed: ".date("d/m/y : H:i:s", time())."</small>";
} else if ($mote == 'all') {
    print "</head>\n<body>\n";
    print "<h2>JR Tenet/Cyclops Image List (by mote-id)</h2><hr>\n";
    showEveryMoteImageList();
    print "<hr>\n";
    print "<a href=\"jrviewer.php\"><h5>Back to View-Image</h5></a>\n";
} else if ($mote == 'time') {
    print "</head>\n<body>\n";
    print "<h2>JR Tenet/Cyclops Image List (by time)</h2><hr>\n";
    showMoteImageList(null);
    print "<hr>\n";
    print "<a href=\"jrviewer.php\"><h5>Back to View-Image</h5></a>\n";
} else {
    print "</head>\n<body>\n";
    print "<h2>JR Tenet/Cyclops Mote$mote Image List</h2><hr>\n";
    showMoteImageList($mote);
    print "<hr>\n";
    print "<a href=\"jrviewer.php\"><h5>Back to View-Image</h5></a>\n";
}

?>
</body>

