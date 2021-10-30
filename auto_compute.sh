#!/bin/bash

# get script directory
DIR=$(dirname "$0")
TEMPLATE_DIR="$DIR/templates"
DATA_PARSER="$DIR/lammps_data_parser/lammps_data_parser"
# string for printing stars
STARS="******"
# log file name
LOG=log.lammps
# output file name
OUTPUT=fall.output.data
# in file name
IN=fall.in
IN_TEMPLATE="$TEMPLATE_DIR/template.in"
# input file name
INPUT_TEMPLATE="$TEMPLATE_DIR/template.input.data"
INPUT=fall.input.data
# dump file names
DUMP_ALL=all.dump
DUMP_LAST10=last_10.dump
DUMP_LAST_STEP=last_step.dump
DUMP_VOR=vor_time.dump
# zero level
ZERO_LVL="-0.0184635"
# computes speeds
SPEEDS=("115.7" "163.6" "231.4" "283.4" "365.88")

clean() {
  # rm input.data
  rm $DIR/$INPUT
  # rm output.data
  rm $DIR/$OUTPUT
  # rm .in file
  rm $DIR/$IN 
  # rm dumps
  rm $DIR/$DUMP_LAST_STEP
  rm $DIR/$DUMP_LAST10
  rm $DIR/$DUMP_ALL
  rm $DIR/$DUMP_VOR
  # rm log.lammps
  rm $DIR/$LOG
}

get_parser() {
  rm -rf "lammps_data_parser"
  git clone https://github.com/denisstrizhkin/lammps_data_parser
  cd lammps_data_parser
  cmake .
  make lammps_data_parser
}

begin() {
  # print title
  echo "### LAMMPS AUTOCOMPUTE SCRIPT ###"; echo; echo "$STARS"
  
  # set number of OpenMP threads
  export OMP_NUM_THREADS=8
  echo "set number of OpenMP threads to $OMP_NUM_THREADS"; echo; echo "$STARS"
  
  # make a directory to store results
  rm -rf result
  mkdir result
  
  # variants loop
  for speed_i in "${SPEEDS[@]}"
  do
    for move_i in {1..5}
    do
      echo "compute: moved_${move_i}_speed_${speed_i}"; echo; echo "$STARS"
    
      RESULTS_DIR="$DIR/result/moved_${move_i}_speed_${speed_i}"
      NEW_INPUT_DATA="$RESULTS_DIR/$INPUT"
      NEW_IN_DATA="$RESULTS_DIR/$IN"
    
      mkdir $RESULTS_DIR
      
      echo "moving carbon"
      $DATA_PARSER 'r' $INPUT_TEMPLATE $NEW_INPUT_DATA "temp"
      cp $NEW_INPUT_DATA $DIR/$INPUT
      echo; echo "$STARS"
  
      echo "changing .in file"
      echo "# CONSTANTS" > $DIR/$IN
      echo 'variable zero_lvl equal "'$ZERO_LVL'"' >> $DIR/$IN 
      echo 'variable carbon_vz equal "'-${speed_i}'"' >> $DIR/$IN
      echo 'variable carbon_vx equal "'0'"' >> $DIR/$IN
      awk "NR >= 5" $IN_TEMPLATE >> $DIR/$IN
      echo; echo "$STARS"
      
      # run lammps script
      echo "running lammps script"; echo " ---"
      lmp -sf omp -in fall.in
  
      ### COPY OUTPUT ###
      # cp output.data
      cp $DIR/$OUTPUT $RESULTS_DIR/$OUTPUT
      # cp .in file
      cp $DIR/$IN $RESULTS_DIR/$IN 
      # cp dumps
      cp $DIR/$DUMP_LAST_STEP $RESULTS_DIR/$DUMP_LAST_STEP
      cp $DIR/$DUMP_LAST10 $RESULTS_DIR/$DUMP_LAST10
      cp $DIR/$DUMP_ALL $RESULTS_DIR/$DUMP_ALL
      cp $DIR/$DUMP_VOR $RESULTS_DIR/$DUMP_VOR
      # cp log.lammps
      cp $DIR/$LOG $RESULTS_DIR/$LOG
      echo; echo "$STARS"
      
      # parse carbon z distribution dump
      echo "last 10 steps carbon distribution average calculation"
      $DATA_PARSER "c" $DIR/$DUMP_LAST10 $RESULTS_DIR/C_z_dist.vals "temp"
      echo; echo "$STARS"
      
      # parse voro dump
      echo "parsing voronoi time relation dump"
      $DATA_PARSER "v" $DIR/$DUMP_VOR $RESULTS_DIR/Voro_time.vals "temp"
      echo; echo "$STARS"

      #clean temp files
      clean
    done
  done
}

if declare -f "$1" > /dev/null
then
  # call arguments verbatim
  "$@"
else
  # Show a helpful error
  echo "'$1' is not a known function name" >&2
  exit 1
fi
