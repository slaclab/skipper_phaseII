# Dump command is used to select which traces to save. Depth selects the
# # how many levels of hierarchy to save, 0 = all (problem for large designs :)
source ../session.tcl
dump -depth 0
dump -aggregates -add /
run 1s
