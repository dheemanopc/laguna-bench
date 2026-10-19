#!/bin/bash
# Phase 0g capacity curve (runs in tmux on the instance). Baseline serve config (no tuning flags adopted).
cd /opt/bench; P=/opt/bench/bench_point.sh; L=/opt/bench/curve/progress.log
for c in 1 2 4 8 16 32; do $P curve 32768 $c $((c*2)) >> $L; echo "done 32k c$c $(date -u +%T)" >> $L; done
for c in 1 2 4 8 16; do $P curve 131072 $c $((c<2?2:c)) >> $L; echo "done 128k c$c $(date -u +%T)" >> $L; done
for c in 1 2 4 8; do $P curve 300000 $c $((c<2?2:c)) >> $L; echo "done 300k c$c $(date -u +%T)" >> $L; done
python3 /opt/bench/prefix_test.py >> $L 2>&1
echo CURVE-DONE >> $L
