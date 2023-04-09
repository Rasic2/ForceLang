#!/usr/bin/bash

NIONS=`grep NIONS OUTCAR | awk '{print $NF}'`
selective=`sed -n '8 s/^\s*//p' POSCAR | grep -i '^s' | wc -l`
if [ $selective -gt 0 ];then
	start=10
	let end=$start+$NIONS-1
	echo "---------------------------" > .temp_TF
	sed -n "$start, $end p" POSCAR | awk '{printf "%4s %4s %4s \n", $4, $5, $6}' >> .temp_TF
	echo "---------------------------" >> .temp_TF
fi
sed -n '/TOTAL-FORCE/, /total drift/p' OUTCAR | grep -vi total > .temp_force
let length=$NIONS+2
split -l $length .temp_force -d -a 4 .temp_force_

for file in `ls .temp_force_*`
do
	paste $file .temp_TF > "$file"_TF
	rm -rf $file
done

rm -rf .temp_TF .temp_summary

# multiprocessing

tmp_fifo="/tmp/$$.fifo"
mkfifo $tmp_fifo
exec 6<>$tmp_fifo
rm -rf $tmp_fifo

threads=`ls .temp_force_* | wc -l`
#ls .temp_force_*
#echo $threads
for ((i=0;i<$threads;i++))
do
	echo >&6
done

for file in `ls .temp_force_*`
do
	read -u 6
{
	awk '{if($0!~"---"){for(i=4;i<=9;i++){a[NR-1,i]=$i}}}
		END{
			max_force=0.0;rms=0.0; count_atom=0;
			for(i=1;i<=NR-2;i++)
			{
				rms_coor=0.0;
				count_coor=0;
				for(j=4;j<=6;j++)
				{
					if(a[i,j+3]~"T")
					{
						rms_coor+=a[i,j]**2;
						count_coor+=1;
					}
				}
				if(count_coor>0)
				{
					k=(sqrt(rms_coor));
					if(k>max_force)
					{
						max_force=k;
					}
					rms+=rms_coor;			
				}
				count_atom+=1;
			}
			split(FILENAME, fstep, "_");
			printf("%4d \t FORCES: max atom, RMS\t %10.6f \t %10.6f \n", fstep[3]+1, max_force, sqrt(rms/count_atom));
		}' $file
	echo >&6
} &
done > .temp_summary
wait
exec 6>&-
exec 6<&-

cat .temp_summary | sort -n -k 1

rm -rf .temp_force*
