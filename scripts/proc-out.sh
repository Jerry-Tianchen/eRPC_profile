#!/bin/bash
# Process the output of each machine in /tmp/autorun_stat_file
#
# Each stat file begins with the name of the stats like so:
# stat_name_1 stat_name_2 ... stat_name_N
# Then, there are lines containing the values of the stats, like so:
# val_1 val_2 ... val_N
#
# The names and values must be space-separated. Names should be a single word.
# The bash maps in this scripts are indexed from one !!!!

source $(dirname $0)/utils.sh

# We need the node list, but don't overwrite the nodemap generated by run-all.sh
autorun_gen_nodes=1
overwrite_nodemap=0
source $(dirname $0)/autorun.sh

# Temporary directory for storing scp-ed files
tmpdir="/tmp/${autorun_app}_proc"
rm -rf $tmpdir
mkdir $tmpdir

node_index=0
for node in $autorun_nodes; do
  # Keeping destination file name = node name helps in debugging.
	echo "proc-out: Fetching $autorun_stat_file from $node to $tmpdir/$node"
  scp $node:$autorun_stat_file $tmpdir/$node \
		1>/dev/null 2>/dev/null &

  ((node_index+=1))
done
wait
echo "proc-out: Finished fetching files."

header_line=`cat $tmpdir/* | head -1`
blue "proc-out: Header = [$header_line]"

# Create a map of column names in the stats file, indexed from 1
col_name[1]=""
col_index="1"
for name in $header_line; do
  col_name[$col_index]=$name
  echo "Column $col_index = ${col_name[$col_index]}"
  ((col_index+=1))
done

num_columns=`echo $header_line | wc -w`
echo "proc-out: Detected $num_columns columns"

avg[1]="" # Map for per-column averages, indexed from 1
for col in `seq 1 $num_columns`; do
  avg[$col]="0.0"
done

# Process the accumulated output files. This assumes that the files have
# space-separated numbers in columns.

tot_rows="0" # Total rows processed, for rolling average
for filename in $tmpdir/*; do
  echo "proc-out: Processing file $filename."

  # Ignore files with less than 12 lines
  lines_in_file=`cat $filename | wc -l`
  if [ $lines_in_file -le 12 ]; then
    blue "proc-out: Ignoring $filename. Too short ($lines_in_file lines), 12 required."
    continue;
  fi

  # Cut out the first 6 and last 6 lines into compute_temp - use this for stats
  awk -v nr="$(wc -l < $filename)" 'NR > 6 && NR < (nr - 6)' $filename > proc_out_tmp
  remaining_rows=`cat proc_out_tmp | wc -l`

  for col in `seq 1 $num_columns`; do
    file_avg=`awk -v col=$col '{ total += $col } END { printf "%.3f", total / NR  }' proc_out_tmp`
    prev_sum=`echo "scale=3; ${avg[$col]} * $tot_rows" | bc -l`
    cur_sum=`echo "scale=3; $file_avg * $remaining_rows" | bc -l`
    avg[$col]=`echo "scale=3; ($prev_sum + $cur_sum) / ($tot_rows + $remaining_rows)" | bc -l`
    echo "proc-out: Column ${col_name[$col]} average for $filename = $file_avg. Current running average = ${avg[$col]}"
  done

  ((tot_rows+=$remaining_rows))
done

for col in `seq 1 $num_columns`; do
  blue "proc-out: Final column ${col_name[$col]} average = ${avg[$col]}"
done

rm -f proc_out_tmp
