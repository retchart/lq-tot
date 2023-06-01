f0 = open('test_xdc.txt', 'w')
# Trigger A.
pos_y_start = 49
pos_x_start = 36
y_ref = 0
# 32 channels
for i in range(32):
    # 8 phase clocks.
    if(i < 8):
        y_ref = pos_y_start - i * 6
    elif(i < 16):
        y_ref = pos_y_start - 42 + (i % 8) * 6
    elif(i < 24):
        y_ref = pos_y_start - (i % 8) * 6
    elif(i < 32):
        y_ref = pos_y_start - 42 + (i % 8) * 6
    for j in range(8):
        if(j < 4):
            # maintain 4 colum space.
            pos_x = pos_x_start + int(i / 8) * 8 + j
            pos_y_hit = y_ref - 1
            pos_y_latch = y_ref
            pos_y_latch_n = y_ref - 2
        else:
            # maintain 4 colum space.
            pos_x = pos_x_start + int(i / 8) * 8 + 7 - j
            pos_y_hit = y_ref - 4
            pos_y_latch = y_ref - 3
            pos_y_latch_n = y_ref - 5
        f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerA/tdc_mpcs%d/tdc_fine_inst/tdc_hit%d/q1_reg}]\n'%(pos_x, pos_y_hit, i, j))
        f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerA/tdc_mpcs%d/tdc_fine_inst/tdc_hit%d/q2_reg}]\n'%(pos_x, pos_y_hit, i, j))
        if(j == 0):
            f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerA/tdc_mpcs%d/tdc_fine_inst/phase_count_reg}]\n'%(pos_x, pos_y_hit, i))
        else :
            f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerA/tdc_mpcs%d/tdc_fine_inst/dff_cnt%d/q_reg}]\n'%(pos_x, pos_y_hit, i, j))
            # f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerA/tdc_mpcs%d/tdc_fine_inst/dff_cnt%d/q_n_reg}]\n'%(pos_x, pos_y_hit, i, j))
        f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerA/tdc_mpcs%d/tdc_fine_inst/phase_latch_reg[%d]}]\n'%(pos_x, pos_y_latch, i, j))
        f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerA/tdc_mpcs%d/tdc_fine_inst/phase_n_latch_reg[%d]}]\n'%(pos_x, pos_y_latch_n, i, j))
    f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerA/tdc_mpcs%d/LUT1_inst_level0}]\n'%(pos_x_start + (i / 8) * 4 + 2, y_ref - 4, i))
# Trigger B
pos_y_start = 50
pos_x_start = 36
y_ref = 0
# 32 channels
for i in range(32):
    # 8 phase clocks.
    if(i < 8):
        y_ref = pos_y_start + i * 6
    elif(i < 16):
        y_ref = pos_y_start + 42 - (i % 8) * 6
    elif(i < 24):
        y_ref = pos_y_start + (i % 8) * 6
    elif(i < 32):
        y_ref = pos_y_start + 42 - (i % 8) * 6
    for j in range(8):
        if(j < 4):
            # maintain 4 colum space.
            pos_x = pos_x_start + int(i / 8) * 8 + j
            pos_y_hit = y_ref + 1
            pos_y_latch = y_ref
            pos_y_latch_n = y_ref+2
        else:
            # maintain 4 colum space.
            pos_x = pos_x_start + int(i / 8) * 8 + 7 - j
            pos_y_hit = y_ref + 4
            pos_y_latch = y_ref + 3
            pos_y_latch_n = y_ref + 5
        f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerB/tdc_mpcs%d/tdc_fine_inst/tdc_hit%d/q1_reg}]\n'%(pos_x, pos_y_hit, i, j))
        f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerB/tdc_mpcs%d/tdc_fine_inst/tdc_hit%d/q2_reg}]\n'%(pos_x, pos_y_hit, i, j))
        if(j == 0):
            f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerB/tdc_mpcs%d/tdc_fine_inst/phase_count_reg}]\n'%(pos_x, pos_y_hit, i))
        else :
            f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerB/tdc_mpcs%d/tdc_fine_inst/dff_cnt%d/q_reg}]\n'%(pos_x, pos_y_hit, i, j))
            # f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerA/tdc_mpcs%d/tdc_fine_inst/dff_cnt%d/q_n_reg}]\n'%(pos_x, pos_y_hit, i, j))
        f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerB/tdc_mpcs%d/tdc_fine_inst/phase_latch_reg[%d]}]\n'%(pos_x, pos_y_latch, i, j))
        f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerB/tdc_mpcs%d/tdc_fine_inst/phase_n_latch_reg[%d]}]\n'%(pos_x, pos_y_latch_n, i, j))
    f0.write('set_property LOC SLICE_X%dY%d [get_cells {triggerB/tdc_mpcs%d/LUT1_inst_level0}]\n'%(pos_x_start + (i / 8) * 4 + 2, y_ref + 4, i))

f0.close()
