#!/bin/csh -x
set FILEPROTOCOL = "file:"
set FRE_VERSION = fre/test
set FRECHECKOPS = ""
set DATE =  `date +%Y%m%d%H%M%S`
set num = 1
set help = 0
set EXPLIST = ()
set refresh = 0
set target_list = (repro,openmp prod,openmp debug,openmp)
set platform_list = (ncrc.intel ncrc.pgi)
set myreftag = ""
set xml_list = ()
set xml_dir = ""
set list = "mom4p1_solo.xml mom4p1_cpld.xml CM2M_Control-1900.xml ESM2_Control.xml ICCMp1.xml GOLD_SIS.xml"

set ignore_var_list = "NONE"

set argv = (`getopt -u -o hrd:p:t:x: -l reference_tag: -l frecheck_ops: --  $*`)


while ("$argv[1]" != "--")
    switch ($argv[1])
        case -h:
            set help   = 1;  breaksw
        case -r:
            set refresh   = 1;  breaksw
        case -d:
            set xml_dir   = $argv[2]; shift argv; breaksw
        case --reference_tag:
            set myreftag = $argv[2]; shift argv; breaksw
        case --frecheck_ops:
            set FRECHECKOPS = $argv[2]; shift argv
	    set FRECHECKOPS = `echo $FRECHECKOPS | awk  '{gsub(/;/," ");print}'`
	    set FRECHECKOPS = `echo $FRECHECKOPS | awk  '{gsub(/++/,"--");print}'`
            breaksw
	case -p:
	    set platform_list = $argv[2]; shift argv
	    set platform_list = `echo $platform_list | awk  '{gsub(/,/," ");print}'`
            breaksw
	case -t:
	    set target_list = $argv[2]; shift argv
	    set target_list = `echo $target_list | awk  '{gsub(/,/," ");print}'`
            breaksw
	case -x:
	    set xml_list =  $argv[2]; shift argv
	    set xml_list =  `echo $xml_list | awk  '{gsub(/,/," ");print}'`
            breaksw
    endsw
    shift argv
end
shift argv

foreach EXP ( $argv )    
    set EXPLIST = ($EXPLIST $EXP)
end

echo EXPLIST: $EXPLIST




if ( $help ) then
HELP:
cat << EOF
Name:      frerts_status.csh

Synopsis:  Publishes the status for experiments in a list of xmls in html.

Usage:     frerts_status.csh space_separated_list_of_xmls > path_to_output_html_file

	   -d the path to directory that contains the latest run xmls. Defaults to "." if not given
	   -r force refresh the frecheck results
	   -p comma separated platform list
	   -t comma separated target list
	   -x comma separated xml file list

Examples:
frerts_status.csh -r --reference_tag siena_201202 -p ncrc2.intel -t prod-openmp -x /ncrc/home2/Niki.Zadeh/autorts/siena_mom4p1_siena_22feb2012_smg/c2/_FEB23/CM2M_Control-1900.xml.20120223102951 --frecheck_ops "++ignore_var_list=eta_nonsteric,eta_steric,eta_dynamic,eta_water,eta_source,eta_surf_temp,eta_surf_salt,eta_surf_water,eta_bott_temp,eta_nonbouss;++ignore_file_list=_crash"

/ncrc/home2/Niki.Zadeh/fre/testing_fre_20120214/fre-commands/bin/frerts_status.csh -r --reference_tag siena_201202 -p ncrc2.intel -t prod-openmp -x /ncrc/home2/Niki.Zadeh/autorts/siena_201202_mom4p1_siena_22feb2012_smg/c2/_FEB24/mom4p1_solo.xml.20120224115309  mk3p51 

EOF
exit 1
endif


if(! $#xml_list ) then
    set xml_dir = "/ncrc/home2/$USER/autorts/"
    set xml_list = "mom4p1_cpld.xml.latest CM2M_Control-1900.xml.latest ESM2_Control.xml.latest ICCMp1.xml.latest GOLD_SIS.xml.latest"
endif

set FRECHECK = frerts_check

foreach xml ( $xml_list )

    set xml_file = $xml_dir$xml

    if( ! -e $xml_file ) then
    echo xml file $xml_file not found
    exit 1;
    endif
    set html_file = "$xml_file.html"

    echo "</br>DATE: $DATE </br>\n">> $html_file 
    echo "<table BORDER cellspacing=1 cellpadding=3>">> $html_file


    if( $myreftag != "" ) then
	sed 's/<property name.*"reference_tag.*value.*\/>/  <property name=\"reference_tag\"  value=\"somethingnoonewouldthinkofever\"\/>/g' -i $xml_file
	sed  "s/somethingnoonewouldthinkofever/$myreftag/g" -i $xml_file
    endif  

    set RELEASE = `grep 'name="RELEASE"' $xml_file | grep -o 'value=".*"' | grep -o '".*"'`
    
    echo "<tr><td><a href="$FILEPROTOCOL//$xml_file" title="xml:$xml,release:$RELEASE">EXPERIMENT</a></td>" >> $html_file
    
    foreach i ( $platform_list )
    echo "<td colspan=$#target_list>$i</td>">> $html_file
    end
    echo "</tr>">> $html_file
    
    
    
    echo "<tr><td></td>">> $html_file
    foreach i ( $platform_list )
    foreach j ( $target_list ) 
    echo "<td>$j</td>">> $html_file
    end
    end
    echo "</tr>">> $html_file


    if(! $#EXPLIST ) set EXPLIST = `frelist --no-inherit -x $xml_file | egrep -v "_compile|_base|_1thread|noRTS" `
    echo "<tr>">> $html_file
    foreach k ( $EXPLIST ) 
    echo "<td>$k</td>">> $html_file
    
#if ( 
#set x=`{awk 'g/thread/$k/m ;print $1'}`
# ) @ j = $j.",openmp"
#echo $x

    foreach i ( $platform_list )
      foreach j ( $target_list ) 

        set run_status = "<td bgcolor='#FFFFFF'></td>" # White to indicate not compiled yet.

        set stdout_dir = `frelist --directory stdout -p $i -target $j -x $xml_file $k`

        set cnt=0

        if ( -x $stdout_dir/run ) then 
          cd $stdout_dir/run
	  set outputlist = $stdout_dir/outputlist.html
	  echo "stdouts: </br>" > $outputlist
          set cnt_fail = 0
          set error = 0
          foreach file (`ls -1 |egrep -v "output.stager|file_sender|chain|workDir.cleaner"`)
#            @ cnt_fail = $cnt_fail + `grep -c "ERROR.: Any" $file`      
	    grep -qc "ERROR: Any" $file 
	    if( ! $status ) then
		@ cnt_fail = $cnt_fail + 1
		echo "ERROR. : <a href=$FILEPROTOCOL//$stdout_dir/run/$file><nobr>$stdout_dir/run/$file</nobr></a></br>" >> $outputlist
	    else
		echo "OK :  <a href=$FILEPROTOCOL//$stdout_dir/run/$file><nobr>$stdout_dir/run/$file</nobr></a></br>" >> $outputlist
            endif
          end


          if ( $cnt_fail > 0 ) set run_status = "<td bgcolor='#FF0000' <a href=$FILEPROTOCOL//$outputlist title='ERROR. in stdout'>$cnt_fail</a></td>" # Red to indicate failure

          foreach file (`ls -1 |egrep -v "output.stager|file_sender|chain|workDir.cleaner"`)
            @ cnt = $cnt + `grep -c "Natural end-of-script" $file`
          end
         
	  if ( $cnt > 0 ) set run_status = "<td bgcolor='#FFFF00' <a href=$FILEPROTOCOL//$outputlist title='Something ran'>$cnt ($cnt_fail)</a></td>" # Yellow to indicate some successful runs
          cd -
        endif


	if ( $cnt == 0 ) then
	    echo $run_status>> $html_file
	    continue
	endif

	set archivedir  = `frelist --directory archive -p $i -target $j -x $xml_file $k`
	set frecheckout = $archivedir/frecheck.out
	set old_number = 0
	if( -d $archivedir ) then 
	   if( -e $frecheckout ) then
	       set old_number = `grep "NumberOfRuns=" $frecheckout | awk '{ print $2}'`
	   endif

           if( $cnt != $old_number || $refresh  ) then
	       echo "NumberOfRuns= $cnt" >  $frecheckout 
	       echo "<a href=$FILEPROTOCOL//$outputlist title=$outputlist >Outputlist: $cnt OK, $cnt_fail ERROR runs</a>" >>  $frecheckout 
	       echo Restarts: >>  $frecheckout 
	       ( $FRECHECK -l  -p $i -target $j -x $xml_file $k >> $frecheckout ) >& /dev/null
	       echo >>  $frecheckout 

#              set ignore_var_list = con_temp #changes between riga_201104 and siena in MOM4p1 
#	       set ignore_var_list = "eta_nonsteric,eta_steric,eta_dynamic,eta_water,eta_source,eta_surf_temp,eta_surf_salt,eta_surf_water,eta_bott_temp,eta_nonbouss"   #Missing in post siena MOM4p1
#	       set FRECHECKOPS = "--ignore_var_list $ignore_var_list --ignore_file_list _crash --Attribute=missing_value,_FillValue" #Needed for comparing siena to pre-siena
	       set cmd = "$FRECHECK -p $i -target $j -x $xml_file $FRECHECKOPS $k" #Needed for comparing siena to pre-siena
	       echo $cmd >> $frecheckout 
	       ( $cmd  > $archivedir/frecheck.stdout ) >& $archivedir/frecheck.stderr
	       cat $archivedir/frecheck.stderr $archivedir/frecheck.stdout >> $frecheckout  
           endif

	   set CROSSOVER_PASSED = 0
	   set REFERENTIALLY_PASSED = 0
	   set CROSSOVER_FAILED = 0
	   set REFERENTIALLY_FAILED = 0
	   set CRASH_DETECTED = 0
 	   set NO_RUNS_TO_COMPARE = 0

	   grep -q "CROSSOVER PASSED:.*$k.*"     $frecheckout
	   if( ! $status ) set CROSSOVER_PASSED = 1
	   grep -q "REFERENTIALLY PASSED:.*$k.*" $frecheckout
	   if( ! $status ) set REFERENTIALLY_PASSED = 1
	   grep -q "CROSSOVER FAILED:.*$k.*"     $frecheckout
	   if( ! $status ) set CROSSOVER_FAILED = 1
	   grep -q "REFERENTIALLY FAILED:.*$k.*" $frecheckout
	   if( ! $status ) set REFERENTIALLY_FAILED = 1
	   grep -q "CRASH DETECTED:.*$k.*"       $frecheckout
	   if( ! $status ) set CRASH_DETECTED = 1
	   grep -q "NO RUNS TO COMPARE:.*$k.*"   $frecheckout
	   if( ! $status ) set NO_RUNS_TO_COMPARE = 1

	   grep DIFFER $frecheckout | egrep -q -v "iceberg|blobs.res|GOLD_IC|ocean_geometry|timestats|Vertical_coordinate|WARNING"
	   if( $status ) then #only icebergs DIFFER, flip the failures if any
		if( $CROSSOVER_FAILED )     then 
		    set CROSSOVER_FAILED = 0
		    set CROSSOVER_PASSED = 1
		endif
		if( $REFERENTIALLY_FAILED ) then
		    set REFERENTIALLY_FAILED = 0
		    set REFERENTIALLY_PASSED = 1
		endif
	   endif

	   set color = '#FFFFFF' 
	   set title='NO_COMPARISONS'

	   if( $NO_RUNS_TO_COMPARE ) then
	       	set color='#FFFF00' 
		set title='NO_RUNS_TO_COMPARE'
	   else
		if( $CROSSOVER_PASSED ) then
		    if( $REFERENTIALLY_PASSED ) then
			set color='#00FF00'
			set title='CROSSOVER_PASSED,REFERENTIALLY_PASSED '
		    else
		      if( $REFERENTIALLY_FAILED ) then
			set color='#00FFFF'
			set title='CROSSOVER_PASSED,REFERENTIALLY_FAILED'
		      else #NO_REFERENCE_COMPARED
			set color='#808000'
			set title='CROSSOVER_PASSED,NO_REFERENCE_FOUND'			
                      endif                   
		    endif
		else
		  if( $CROSSOVER_FAILED ) then 
		      if( $REFERENTIALLY_PASSED ) then
			set color='#FFA500'
			set title='CROSSOVER_FAILED,REFERENTIALLY_PASSED '
	    	      else
		        if( $REFERENTIALLY_FAILED ) then
			  set color='#800000'
			  set title='CROSSOVER_FAILED,REFERENTIALLY_FAILED' 
		        else #NO_REFERENCE_COMPARED
			  set color='#800000'
			  set title='CROSSOVER_FAILED,NO_REFERENCE_FOUND'			
                        endif
		      endif
		  else #No crossover
		      if( $REFERENTIALLY_PASSED ) then
			set color='#FFA500'
			set title='NO_CROSSOVER,REFERENTIALLY_PASSED '
	    	      else
		        if( $REFERENTIALLY_FAILED ) then
			  set color='#800000'
			  set title='NO_CROSSOVER,REFERENTIALLY_FAILED' 
		        else #NO_REFERENCE_COMPARED
			  set color='#800000'
			  set title='NO_CROSSOVER,NO_REFERENCE_FOUND'			
                        endif
                      endif
		  endif		    
		endif
                
		if( $CRASH_DETECTED ) then
			set color='#FF0000' 
			set title='CRASH_DETECTED,'$title
     		endif
	   endif

	   set run_status = "<td bgcolor=$color <a href="$FILEPROTOCOL//$frecheckout" title=$title>$cnt </a> , (<a href=$FILEPROTOCOL//$outputlist title=$outputlist>$cnt_fail</a>)</td>"
      	 endif

       echo $run_status>> $html_file
      end # end of j loop 
    end # end of i loop
  echo "</tr>">> $html_file
  end # loop over EXPLIST
echo "</tr>">> $html_file
end # loop over xml_list

#Legends
#echo "<tr><td>bgcolor='#FF0000'>CRASH</td></tr>"
#echo "<tr><td>bgcolor='#FFFF00'>RAN</td></tr>"
#echo "<tr><td>bgcolor='#FF0080'>FAILED RESTART/SCALING</td></tr>"
#echo "<tr><td>bgcolor='#00FFFF'>PASSED RESTART/SCALING</td></tr>"
#echo "<tr><td>bgcolor='#00FF00'>PASSED RESTART/SCALING AND REPRODUCED OLD ANSWERS</td></tr>"

echo "</table>">> $html_file

    echo "NOTES:</br>\n" >> $html_file
    echo "reference tag: $myreftag</br> \n" >> $html_file
    echo "FRECHECKOPS: $FRECHECKOPS</br> \n" >> $html_file


