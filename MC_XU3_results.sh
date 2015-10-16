#!/bin/bash

#Programmable head line and column separator. By default I assume data start at line 3 (first line is descriptio, second is column heads and third is actual data). Columns separated by tab(s).
head_line=1
col_sep="\t"
time_convert=1000000000

#main loop b=big L=LITTLE s=save directory n=specify number of runs -t=benchmark directory -h=help
#requires getops, but this should not be an issue since ints built in bash
while getopts ":b:L:s:x:t:n:h" opt;
do
    case $opt in
        h)
		    echo "Available flags and options:" >&2
		    echo "-b [FREQUENCIES] -> turn on collection for big cores [benchmarks and monitors], specify frequencies in Hz separated by commas. Range is [500000;1200000]"
		    echo "-L {FREQUENCIES] -> turn on collection for LITTLE cores [benchmarks and monitors], specify frequencies in Hz, separated by commas. Range is [175000;500000]."
		    echo "-s [DIRECTORY] -> specify a save directory for the results of the different runs. If flag is not specified program uses current directory"
		    echo "-n [NUMBER] -> specify number of runs. Results from different runs are saved in subdirectories Run_RUNNUM"
		    echo "Mandatory options are: -b and/or -L; -t [DIR]; -n [NUM]"
		    echo "You can group flags with no options together, flags are separated with spaces"
		    echo "Recommended input: ./MC.sh -b {FREQEUNCY LIST} -L {FREQUENCY LIST} -s Results/{NAME}/ -t Benchmarks/{EXEC} -n {RUNS}"
		    echo "Average time per 1 run of the complete benchmark set: UPDATE!"
		    echo "You can control which benchmarks of the whole cBench soute are run by editing the bench_list file in the Benchmarks/cBench/ directory and commenting out/in the ones you want."
		    exit 0 
        	;;
        
        b|L)
            #Make sure command has not already been processed (flag is unset)
			if [[ -n $CORE_CHOSEN ]]; then
				echo "Invalid input: option -b or -L has already been used!" >&2
				exit 1
			fi
		            
			if ! [[ "$OPTARG" =~ ^[1-4]$ ]]; then
				echo "Invalid input: $OPTARG needs to be 1-4 (number of cores)!" >&2
				exit 1
			fi

			if [[ $opt == b ]]; then
				MAX_CORE=7
				MIN_CORE=4
				CORE_COLLECT_FREQ=1400000
		        MAX_F=2000000
				MIN_F=200000
			else
				MAX_CORE=3
				MIN_CORE=0
				CORE_COLLECT_FREQ=2000000
				MAX_F=1400000
				MIN_F=200000
			fi
		           	
			CORE_CHOSEN="$OPTARG"
			;;

		f)
                if [[ -n $CORE_FREQ ]]; then
                        echo "Invalid input: option -f has already been used!" >&2
                        exit 1
                fi

            	spaced_OPTARG="${OPTARG//,/ }"

            	#Go throught the selected frequecnies and make sure they are not out of bounds
	    	#Also make sure they are present in the frequency table located at /sys/devices/system/cpu/cpufreq/iks-cpufreq/freq_table because the kernel rounds up
            	#Specifying a higher/lower frequency or an odd frequency is now wrong, jsut the kernel handles it in the background and might lead to collection of unwanted resutls
            	for FREQ_SELECT in $spaced_OPTARG
            	do
            		if [[ $FREQ_SELECT -gt $MAX_F || $FREQ_SELECT -lt $MIN_F ]]; then 
		    		echo "selected frequency $FREQ_SELECT for -$opt is out of bounds. Range is [$MAX_F;$MIN_F]"
                    		exit 1
                	else
				[[ -z "$CORE_FREQ" ]] && CORE_FREQ="$FREQ_SELECT" || CORE_FREQ+=" $FREQ_SELECT"
                    	fi
            	done
            	;;
            	
#save location to get results
#events file wwith 3 options: randomly split, use previous split, use whole set
#specify save file for resutls
			
#specify model type (in file format)
        #Specify the save directory, if no save directory is chosen the results are saved in the $PWD
        s)
            if (( $SAVE_DIR_CHOSEN )); then
                echo "Invalid input: option -s has already been used!" >&2
                exit 1                
            fi
            #If the directory exists, ask the user if he really wants to reuse it. I do not accept symbolic links as a save directory.
            if [[ ! -d $OPTARG ]]; then
                    echo "Directory specified with -s flag does not exist" >&2
                    exit 1
            else
                #directory does exists and we can analyse results
                save_dir=$OPTARG
                SAVE_DIR_CHOSEN=1
            fi
            ;;

        n)
            #Choose the number of runs. Data from different runs is saved in Run_(run number) subfolders in the save directory
            if (( $NUM_RUNS )); then
                echo "Invalid input: option -n has already been used!" >&2
                exit 1                
            fi
            if (( !$OPTARG )); then
                echo "Invalid input: option -n needs to have a positive integer!" >&2
                exit 1
            else        
                NUM_RUNS=$OPTARG                        
            fi
            ;;
        :)
            echo "Option: -$OPTARG requires an argument" >&2
            exit 1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

#Check if user has specified something to run
if (( !$big_CHOSEN && !$LITTLE_CHOSEN )); then
    echo "Nothing to run. Expected -b or -L" >&2
    exit 1
fi

if (( !$NUM_RUNS )); then
    echo "Nothing to run. Expected -n NUM_RUNS" >&2
    exit 1
fi

#loop to run benchmarks
core_choices="big LITTLE"


for core_select in $core_choices;
do
    #Process only the cores the user has chosen 
    if (( "$core_select"_CHOSEN )); then
    
    	if [[ $core_select == "big" ]]; then 
			CPU_P_col=11
			CPU_V_col=9
			CPU_T_col=8
        else	
			CPU_P_col=6
			CPU_V_col=4
			CPU_T_col=3
		fi
    
		freq_list="$(eval echo \$$(eval echo "$core_select"_FREQ))"
		freq_list="${freq_list//,/ }"
		
		echo -e "#Benchmark\tRuntime\tCPU Power(W)\tCPU Voltage(V)\tCPU Frequency(MHz)\tCPU Temperature(C)\tCycles\tL1 DCache Access\tL1 ICache Access\tInstructions\tRAM Access\tCPU User(%)\tCPU Sys(%)\tCPU Idle(%)\tCPU I/O Wait(%)\tCPU IRQ(%)\tCPU Soft IQ(%)"
								
		for freq_select in $freq_list
		do 
			
			for runnum in `seq 1 $NUM_RUNS`;
		    do

		    	sensors_file="$save_dir/""Run_$runnum/""$core_select$freq_select/""sensors_""$core_select$freq_select"".data"
		    	#usage_file="$save_dir/Run_$runnum/""$core_select$freq_select/""usage_""$core_select$freq_select"".data"
		        benchmarks_file="$save_dir/Run_$runnum/""$core_select$freq_select/""benchmarks_""$core_select$freq_select"".data"
		        #events_raw_file="$save_dir/Run_$runnum/""$core_select$freq_select/""events_raw_""$core_select$freq_select"".data"
			    
			    starttime=$(awk -v START=1 -v SEP='\t' 'BEGIN{FS = SEP}{ if (NR == START){print $2;}}' $events_raw_file)
			    ev1_name=$(awk -v START=2 -v SEP='\t' 'BEGIN{FS = SEP}{ if (NR == START){print $2;}}' $events_raw_file)
			    ev2_name=$(awk -v START=3 -v SEP='\t' 'BEGIN{FS = SEP}{ if (NR == START){print $2;}}' $events_raw_file)
			    ev3_name=$(awk -v START=4 -v SEP='\t' 'BEGIN{FS = SEP}{ if (NR == START){print $2;}}' $events_raw_file)
			    ev4_name=$(awk -v START=5 -v SEP='\t' 'BEGIN{FS = SEP}{ if (NR == START){print $2;}}' $events_raw_file)
			    ev5_name=$(awk -v START=6 -v SEP='\t' 'BEGIN{FS = SEP}{ if (NR == START){print $2;}}' $events_raw_file)		        
			  
			  	#Preprep events data
			    events_file="$save_dir/Run_$runnum/""$core_select$freq_select/""events_""$core_select$freq_select"".data"
			    echo -e "#Timestamp\t$ev1_name\t$ev2_name\t$ev3_name\t$ev4_name\t$ev5_name" > $events_file 
			   
			    for linenum in $(seq 7 5 $(wc -l $events_raw_file | awk '{print $1}')) 
				do
					time=$(awk -v START=$linenum -v SEP=$col_sep '
						BEGIN{
							FS = SEP
						}{
							if(NR==START){
								print $1
								exit
							}
						}' $events_raw_file)
					ev1_data=$(awk -v START=$linenum -v SEP=$col_sep '
						BEGIN{
							FS = SEP
						}{
							if(NR==START){
								print $2;
								exit;
							}
						}' $events_raw_file)
					ev2_data=$(awk -v START=$linenum -v SEP=$col_sep '
						BEGIN{
							FS = SEP
						}{
							if(NR==(START+1)){
								print $2;
								exit;
							}
						}' $events_raw_file)
					ev3_data=$(awk -v START=$linenum -v SEP=$col_sep '
						BEGIN{
							FS = SEP
						}{
							if(NR==(START+2)){
								print $2;
								exit;
							}
						}' $events_raw_file)
					ev4_data=$(awk -v START=$linenum -v SEP=$col_sep '
						BEGIN{
							FS = SEP
						}{
							if(NR==(START+3)){
								print $2;
								exit;
							}
						}' $events_raw_file) 
					ev5_data=$(awk -v START=$linenum -v SEP=$col_sep '
						BEGIN{
							FS = SEP
						}{
							if(NR==(START+4)){
								print $2;
								exit;
							}
						}' $events_raw_file)
					nanotime=$(echo "scale = 0; ($starttime+($time*$time_convert))/1;" | bc )
					echo -e "$nanotime\t$ev1_data\t$ev2_data\t$ev3_data\t$ev4_data\t$ev5_data" >> $events_file
				done

				
				#Extract energy consumption information
				for linenum in $(seq 2 $(wc -l $benchmarks_file | awk '{print $1}'))
				do 

					#Get start and end of each benchmark
					func=$(awk -v START=$linenum -v SEP=$col_sep '
							BEGIN{
								FS = SEP
							}{
								if (NR == START){
								     print $1;
								     exit;
								} 
							}' $benchmarks_file)
					func_start=$(awk -v START=$linenum -v SEP=$col_sep '
							BEGIN{
								FS = SEP
							}{
								if (NR == START){
								     print $2;
								     exit;
								} 
							}' $benchmarks_file)
					func_end=$(awk -v START=$linenum -v SEP=$col_sep '
							BEGIN{
								FS = SEP
							}{
								if (NR == START){
								     print $3;
								     exit;
								} 
							}' $benchmarks_file)
							
					runtime=$(echo "scale = 10; ($func_end-$func_start)/$time_convert;" | bc) 

					
					for timestamp_line in $(awk -v START=$head_line -v SEP=' ' -v F_ST=$func_start -v F_ND=$func_end 'BEGIN{FS = SEP} {if (NR > START && $1 >= F_ST && $1 <= F_ND) print NR }' $sensors_file)
					do
						timestamp=$(awk -v START=$timestamp_line -v SEP=' ' '
									    BEGIN{
									    	FS = SEP
									    }{
											if (NR == (START)){
												print $1
												exit
											}
									    }' $sensors_file)
									    
						timestamp_nxt=$(awk -v START=$timestamp_line -v SEP=' ' '
									    BEGIN{
									    	FS = SEP
									    }{
											if (NR == (START+1)){
												print $1
												exit
											}
									    }' $sensors_file)

									    
						#CPU Power, CPU Voltage, CPU Temperature, Ev1, Ev2, Ev3, Ev4, Ev5, User, Sys, Idle
						
						CPU_P=$(awk -v START=$timestamp_line -v SEP=' ' -v COL=$CPU_P_col '
									    BEGIN{
									    	FS = SEP
									    }{
											if (NR == START){
												print $COL
												exit
											}
									    }' $sensors_file)
						CPU_V=$(awk -v START=$timestamp_line -v SEP=' ' -v COL=$CPU_V_col '
									    BEGIN{
									    	FS = SEP
									    }{
											if (NR == START){
												print $COL
												exit
											}
									    }' $sensors_file)
						CPU_T=$(awk -v START=$timestamp_line -v SEP=' ' -v COL=$CPU_T_col '
									    BEGIN{
									    	FS = SEP
									    }{
											if (NR == START){
												print $COL
												exit
											}
									    }' $sensors_file)	  


		    
						event_line=$(awk -v START=$head_line -v SEP=$col_sep -v TIMEST=$timestamp -v TIMEND=$timestamp_nxt '
								    BEGIN{
								    	FS = SEP
								    }{
										if (NR > START && $1 >= TIMEST && $1 <= TIMEND){ 
										  	print NR;
										  	exit;
										  }
								    }' $events_file)
								
						if (( event_line > 0 )); then
						
							EV1=$(awk -v START=$event_line -v SEP=$col_sep -v COL=2 '
								    BEGIN{
								    	FS = SEP
								    }{
										if (NR == START){ 
										  	print $COL;
										  	exit;
										  }
								    }' $events_file)
							EV2=$(awk -v START=$event_line -v SEP=$col_sep -v COL=3 '
								    BEGIN{
								    	FS = SEP
								    }{
										if (NR == START){ 
										  	print $COL;
										  	exit;
										  }
								    }' $events_file)
							EV3=$(awk -v START=$event_line -v SEP=$col_sep -v COL=4 '
								    BEGIN{
								    	FS = SEP
								    }{
										if (NR == START){ 
										  	print $COL;
										  	exit;
										  }
								    }' $events_file)
							EV4=$(awk -v START=$event_line -v SEP=$col_sep -v COL=5 '
								    BEGIN{
								    	FS = SEP
								    }{
										if (NR == START){ 
										  	print $COL;
										  	exit;
										  }
								    }' $events_file)
							EV5=$(awk -v START=$event_line -v SEP=$col_sep -v COL=6 '
								    BEGIN{
								    	FS = SEP
								    }{
										if (NR == START){ 
										  	print $COL;
										  	exit;
										  }
								    }' $events_file)
								    
							usage_line=$(awk -v START=$head_line -v SEP=$col_sep -v TIMEST=$timestamp -v TIMEND=$timestamp_nxt '
								    BEGIN{
								    	FS = SEP
								    }{
										if (NR > START && $1 >= TIMEST && $1 <= TIMEND){ 
										  	print NR;
										  	exit;
										  }
								    }' $usage_file)
								
							if (( usage_line > 0 )); then
						
								USER=$(awk -v START=$usage_line -v SEP=$col_sep -v COL=3 '
											BEGIN{
												FS = SEP
											}{
												if (NR == START){ 
												  	print $COL
												  	exit;
												  }
											}' $usage_file)
								SYS=$(awk -v START=$usage_line -v SEP=$col_sep -v COL=5 '
											BEGIN{
												FS = SEP
											}{
												if (NR == START){ 
												  	print $COL
												  	exit;
												  }
											}' $usage_file)
								IDLE=$(awk -v START=$usage_line -v SEP=$col_sep -v COL=6 '
											BEGIN{
												FS = SEP
											}{
												if (NR == START){ 
												  	print $COL
												  	exit;
												  }
											}' $usage_file)
								IOWAIT=$(awk -v START=$usage_line -v SEP=$col_sep -v COL=7 '
											BEGIN{
												FS = SEP
											}{
												if (NR == START){ 
												  	print $COL
												  	exit;
												  }
											}' $usage_file)
								IRQ=$(awk -v START=$usage_line -v SEP=$col_sep -v COL=8 '
											BEGIN{
												FS = SEP
											}{
												if (NR == START){ 
												  	print $COL
												  	exit;
												  }
											}' $usage_file)
								SOFTIQ=$(awk -v START=$usage_line -v SEP=$col_sep -v COL=9 '
											BEGIN{
												FS = SEP
											}{
												if (NR == START){ 
												  	print $COL
												  	exit;
												  }
											}' $usage_file)


							
								[[ $EV1 && $EV2 && $EV3 && $EV4 && $EV5 && $USER && $SYS && $IDLE ]] && echo -e "$func\t$CPU_P\t$CPU_V\t$freq_select\t$CPU_T\t$EV1\t$EV2\t$EV3\t$EV4\t$EV5\t$USER\t$SYS\t$IDLE\t$IOWAIT\t$IRQ\t$SOFTIQ"
							fi
						fi
							
						EV1=0
						EV2=0
						EV3=0
						EV4=0
						EV5=0
						USER=0
						SYS=0
						IDLE=0
						IOWAIT=0
						IRQ=0
						SOFTIQ=0	    

					echo -e "$func\t$runtime\t$freq_select\t$CPU_V\t$CPU_P\t$CPU_T"
					
					done	
				done   
		    done
		done
    fi
done
