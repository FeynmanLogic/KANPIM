read_verilog parallel_cubic_spline.v

synth_design \
    -top parallel_cubic_spline \
    -part xc7a100tcsg324-1 \
    -mode out_of_context

report_utilization -file utilization.rpt
report_timing_summary -file timing_summary.rpt
report_methodology -file methodology.rpt
report_drc -file drc.rpt

write_checkpoint -force parallel_cubic_spline_synth.dcp
