#####################################################################
#
# CSCB58 Winter 2025 Assembly Final Project
# University of Toronto, Scarborough
#
# Student: ShenYi Wang, 1010016536, Wangs852, shenyi.wang@mail.utoronto.ca
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 512 
# - Display height in pixels: 512
# - Base Address for Display: 0x10008000
#
# Which milestoneshave been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1/2/3/4 (choose the one the applies)
#
# Which approved features have been implemented for milestone 3?
# (See the assignment handout for the list of additional features)
# 1. (fill in the feature, if any)
# 2. (fill in the feature, if any)
# 3. (fill in the feature, if any)
# ... (add more if necessary)
#
# Link to video demonstration for final submission:
# - (insert YouTube / MyMedia / other URL here). Make sure we can view it!
#
# Are you OK with us sharing the video with people outside course staff?
# - yes / no / yes, and please share this project github link as well!
#
# Any additional information that the TA needs to know:
# - (write here, if any)
#
#####################################################################

.data
background:          .word 0xD9D286   # background Color
base_address:        .word 0x10008000 # base Address
pixel_size:          .word 8          # aize of pixel
display_dimension:   .word 64         # display pixels
platform_width:      .word 16          # width of a platform
frame_time:     .word 40 
doodle_colour:       .word 0x32A852
platform_colour:     .word 0x00ff00
num_platforms: .word 4
platforms:
    # Platform 0
    .word 63     # row
    .word 6       # col
    .word 0        # type (0 = static)
    .word 0        # direction (0 = no movement)

    # Platform 1
    .word 21
    .word 0
    .word 1        # type = moving
    .word 1        # direction = right

    # Platform 2
    .word 11
    .word 0
    .word 0
    .word 0

    # Platform 3
    .word 1
    .word 0
    .word 1
    .word -1       # direction = left

character_doodle_size: .word 6
doodle_position: .space 8		# row col
coin_colour:         .word 0xFFFF00     # yellow coin
enemy_colour:        .word 0xAA00FF     # purple enemy
coin_colour_center:  .word 0xCCAA00     # darker gold for center
coin_position:    .word 18, 14   # row, col for coin
enemy_position:   .word 26, 20   # row, col for enemy
keypress: .word 0xffff0000
keyvalue: .word 0xffff0004
gravity_counter: .word 0      # Tracks how many frames have passed
gravity_threshold: .word 12    # Apply gravity every 3 frames
jump_counter:    .word 0      # how many frames of jump left
jump_height:     .word 20      # max jump duration in frames
score:           .word 0:4
last_platform_index: .word 0
font_colour:         .word 0x000000
white_colour:        .word 0xFFFFFF
digit_positions:
    .word 0x10008104   # ones at col 63
    .word 0x10008114   # tens at col 57
    .word 0x10008124   # hundreds at col 51
    .word 0x10008134   # thousands at col 45
    
scroll_counter: .word 0
coin_base_row:            .word 0           # original base row (set at spawn)
coin_animation_counter:   .word 0
coin_animation_threshold: .word 20


.globl main
.text

main:
        	la  $s0, base_address   # Load the address of base_address
	lw  $s0, 0($s0)         # Load the actual value (0x10008000) into $s0
        # Initialize draw flag
        jal randomise_platforms
        jal draw_bg_and_plat
	jal init_draw_doodle
	jal spawn_coin_above_platform
#	li $t0, 16        # row
#	li $t1, 31        # col (safe, no wrapping)
#	la $t2, doodle_position
#	sw $t0, 0($t2)
#	sw $t1, 4($t2)

game_loop:
	jal clear_doodle
	jal read_input
	jal clear_score

	#Gravity timing logic
	la $s7, gravity_counter
	lw $s6, 0($s7)
	addi $s6, $s6, 1
	la $t2, gravity_threshold
	lw $t3, 0($t2)
	blt $s6, $t3, skip_gravity

	li $t1, 0            # Reset counter
	jal apply_gravity
	
skip_gravity:
	sw $s6, 0($s7)       # Update counter
	jal maybe_scroll_camera
	jal check_coin_pickup
	jal draw_platforms
	lw $t2, doodle_colour
	jal draw_character_doodle
	jal draw_score
	jal animate_coin
	jal delay_frame
	j game_loop

check_coin_pickup:
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	# Load doodle position
	la $t0, doodle_position
	lw $t1, 0($t0)         # doodle row
	lw $t2, 4($t0)         # doodle col

	# Load coin position
	la $t3, coin_position
	lw $t4, 0($t3)         # coin row
	lw $t5, 4($t3)         # coin col

	li $t6, 3
	add $t7, $t4, $t6     # $t7 = coin_row + 3
	blt $t1, $t4, end_coin_check
	bge $t1, $t7, end_coin_check

	# Check if doodle col is within coin area (3x3)
	add $t7, $t5, $t6      # right edge
	blt $t2, $t5, end_coin_check   # if doodle col < coin left
	bge $t2, $t7, end_coin_check   # if doodle col >= coin right

	#### PICKUP LOGIC ####
	jal clear_coin       # erase the coin
	jal update_score_no_scroll     # score++

	# Generate new random row (0–50)
	li $v0, 42
	li $a1, 50
	syscall
	la $t8, coin_position
	sw $a0, 0($t8)           # update coin row
	la $t9, coin_base_row
	sw $a0, 0($t9)           # update coin base row

	# Generate new random col (1–60)
	li $v0, 42
	li $a1, 60
	syscall
	addi $a0, $a0, 1
	sw $a0, 4($t8)           # update coin col

	jal draw_coin

end_coin_check:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

update_score_no_scroll:
	# Load base address of score array
	la $t2, score

	# Load current digits
	lw $t3, 0($t2)    # ones
	lw $t4, 4($t2)    # tens
	lw $t5, 8($t2)    # hundreds
	lw $t6, 12($t2)   # thousands

	# Increment
	addi $t3, $t3, 1
	li $t7, 10

	blt $t3, $t7, store_score_ns

	li $t3, 0
	addi $t4, $t4, 1
	blt $t4, $t7, store_score_ns

	li $t4, 0
	addi $t5, $t5, 1
	blt $t5, $t7, store_score_ns

	li $t5, 0
	addi $t6, $t6, 1
	blt $t6, $t7, store_score_ns

	li $t6, 9        # max out at 9999

store_score_ns:
	sw $t3, 0($t2)
	sw $t4, 4($t2)
	sw $t5, 8($t2)
	sw $t6, 12($t2)

	jr $ra

animate_coin:
	# Load and increment counter
	la $t6, coin_animation_counter
	lw $t7, 0($t6)
	addi $t7, $t7, 1
	sw $t7, 0($t6)

	 # Compare to threshold
	la $t8, coin_animation_threshold
	lw $t9, 0($t8)
	blt $t7, $t9, skip_coin_anim

	# Reset counter if threshold reached
	li $t7, 0
	sw $t7, 0($t6)
	# Load current coin row and base row
	la $t0, coin_position
	lw $t1, 0($t0)            # current coin row
	lw $t2, 4($t0)            # coin col

	la $t3, coin_base_row
	lw $t4, 0($t3)            # base row


	addi $sp, $sp, -24
	sw $t0, 0($sp)
	sw $t1, 4($sp)
	sw $t2, 8($sp)
	sw $t3, 12($sp)
	 sw $t4, 16($sp)
	sw $ra, 20($sp)
	# Clear current coin
	jal clear_coin

	lw $t0, 0($sp)
	lw $t1, 4($sp)
	lw $t2, 8($sp)
	lw $t3, 12($sp)
	lw $t4, 16($sp)
	lw $ra, 20($sp)
	addi $sp, $sp, 24
	# Toggle: if current row == base row → move up, else → move back to base
	beq $t1, $t4, move_up

move_down:
    sw $t4, 0($t0)            # move coin to base row
    j draw_coin

move_up:
    subi $t5, $t4, 1
    sw $t5, 0($t0)            # move coin up by 1
    j draw_coin
    
    
skip_coin_anim:
    jr $ra

spawn_coin_above_platform:
	addi $sp, $sp, -4
	sw   $ra, 0($sp)

	li $v0, 42            # syscall: random int
	li $a1, 4             # range: [0, 3] for 4 platforms
	syscall
	move $t0, $a0         # $t0 = random platform index

	# Compute platform address
	li $t1, 16          # size of each platform = 4 words = 16 bytes
	la $t2, platforms
	mul $t3, $t0, $t1
	add $t4, $t2, $t3    # t4 = &platform[i]

	lw $t5, 0($t4)      # platform row
	lw $t6, 4($t4)      # platform col

	# Coin row = platform_row - 2
	subi $t5, $t5, 4

	# Coin col = platform_col + 7 (roughly centered for 16-wide platform)
	addi $t6, $t6, 7

	# Write to coin_position
	la   $t7, coin_position
	sw   $t5, 0($t7)     # store row
	sw   $t6, 4($t7)     # store col
	la   $t7, coin_base_row
	sw   $t5, 0($t7)     # store base row
	
	jal draw_coin

	lw   $ra, 0($sp)
	addi $sp, $sp, 4
	jr   $ra
			

maybe_scroll_camera:
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	# Check scroll counter
	la $t0, scroll_counter
	lw $t1, 0($t0)
	blez $t1, done_scroll

	addi $t1, $t1, -1
	sw $t1, 0($t0)

	# Move doodle down
	jal clear_doodle
	la $t0, doodle_position
	lw $t1, 0($t0)
	addi $t1, $t1, 1
	sw $t1, 0($t0)
	lw $t2, doodle_colour
	jal draw_character_doodle
	
	# Move coin down
	jal clear_coin
	la $t0, coin_position
	la $t2, coin_base_row
	lw $t1, 0($t2)        # coin row
	addi $t1, $t1, 1
	sw $t1, 0($t0)        # update row
	sw $t1, 0($t2)
	
	li $t3, 64
	bge $t1, $t3, respawn_coin

	jal draw_coin
	# Setup platform loop
	la $t3, platforms         # base address
	lw $t4, num_platforms     # number of platforms
	li $t5, 0                 # index counter




scroll_loop:

	bge $t5, $t4, done_scroll

	li $t6, 16
	mul $t7, $t5, $t6         # offset = index * 16
	add $t8, $t3, $t7         # t8 = platform[i] address

	lw $t9, 0($t8)            # row
	lw $s1, 4($t8)            # col

	#### Clear old platform ####
	lw $s2, background        # background color

	mul $s3, $t9, 64
	add $s3, $s3, $s1
	sll $s3, $s3, 2
	add $s4, $s3, $s0         # $s4 = pixel address
	move $t7, $s2             # color
	move $t9, $s4             # address
	li $t6, 0                 # draw counter
	jal draw_line

	#### Move down ####
	lw $t9, 0($t8)            # reload row
	addi $t9, $t9, 1
	sw $t9, 0($t8)
	
	li $t0, 64
	blt $t9, $t0, skip_respawn

	li $t9, 0
	sw $t9, 0($t8)

	li $v0, 42
	li $a1, 49
	syscall
	sw $a0, 4($t8)
	move $s1, $a0

	skip_respawn:
	
	#### Draw new platform ####
	lw $t7, platform_colour

	mul $s3, $t9, 64
	add $s3, $s3, $s1
	sll $s3, $s3, 2
	add $s4, $s3, $s0         # $s4 = pixel address
	move $t9, $s4             # address
	li $t6, 0                 # reset draw counter
	jal draw_line

	addi $t5, $t5, 1
	j scroll_loop

done_scroll:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
respawn_coin:
	# Generate random column (1–60)
	li $v0, 42
	li $a1, 60
	syscall
	addi $a0, $a0, 1             # ensure 1–61 range
	   la $t0, coin_position
	sw $a0, 4($t0)               # store col

	# Generate random row (0–50)
	li $v0, 42
	li $a1, 50
	syscall
	sw $a0, 0($t0)               # store new row
	la $t2, coin_base_row
	sw $a0, 0($t2)               # update base row

	jal draw_coin
	
	addi $t5, $t5, 1
	j scroll_loop
    
clear_coin:
	lw $t0, background          # background color
	la $t1, coin_position
	lw $t2, 0($t1)              # coin row
	lw $t3, 4($t1)              # coin col

	li $t4, 0                   # row offset
clear_coin_row:
	bge $t4, 3, clear_coin_done
	li $t5, 0                   # col offset
clear_coin_col:
	bge $t5, 3, clear_next_row

	# Calculate pixel address
	add $t6, $t2, $t4           # row = base + offset
	add $t7, $t3, $t5           # col = base + offset
	mul $t8, $t6, 64
	add $t8, $t8, $t7
	sll $t8, $t8, 2             # byte offset = row * 64 + col, then * 4
	add $t8, $t8, $s0           # add base address

	sw $t0, 0($t8)              # write background color

	addi $t5, $t5, 1
	j clear_coin_col
clear_next_row:
	addi $t4, $t4, 1
	j clear_coin_row
clear_coin_done:
	jr $ra


clear_score:
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	la $t0, background       # Load background color
	lw $a0, 0($t0)           # Store in $t6 (color to draw over digits)

	la $t1, digit_positions  # $t1 = base of digit_positions

	li $t2, 0                # digit index
	li $t3, 4                # total digits
	li $t9, 256              # row stride

digit_clear_loop:
	bge $t2, $t3, clear_done

	# Load base address of current digit
	mul $t4, $t2, 4
	add $t5, $t1, $t4
	  lw $t6, 0($t5)         # $t6 = base address for this digit

	# Row 0
	sw $a0, 0($t6)
	sw $a0, 4($t6)
	sw $a0, 8($t6)

	# Row 1
	add $t7, $t6, $t9
	sw $a0, 0($t7)
	sw $a0, 4($t7)
	sw $a0, 8($t7)

	# Row 2
	add $t7, $t7, $t9
	sw $a0, 0($t7)
	sw $a0, 4($t7)
	sw $a0, 8($t7)

	# Row 3
	add $t7, $t7, $t9
	sw $a0, 0($t7)
	sw $a0, 4($t7)
	sw $a0, 8($t7)

	# Row 4
	add $t7, $t7, $t9
	sw $a0, 0($t7)
	sw $a0, 4($t7)
	sw $a0, 8($t7)

	addi $t2, $t2, 1
	j digit_clear_loop

clear_done:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
draw_score:
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	la $a0, font_colour
	lw $a0, 0($a0)              # font colour

	la $s1, score               # base of score array
	la $s2, digit_positions     # base of digit_positions array
	li $s3, 0                   # loop counter
	
loop_digits:
	bge $s3, 4, end_print_score

	li $t4, 3                 # max index
	sub $t5, $t4, $s3         # reverse index = 3 - s3
	mul $t0, $t5, 4           # offset = (3 - s3) * 4

	add $t1, $s1, $t0         # address of current score digit
	lw $a2, 0($t1)            # $a2 = digit value (0–9)

	mul $t6, $s3, 4           # forward index for digit_positions
	add $t2, $s2, $t6
	lw $a1, 0($t2)            # $a1 = base address for drawing this digit
	
	la $t0, font_colour     # Load address of font_colour
	lw $a0, 0($t0)          # Load actual color into $a0
	jal draw_digit

	addi $s3, $s3, 1
	j loop_digits
    
    
end_print_score:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
    
draw_digit:
	beq $a2, 0, draw_zero
	beq $a2, 1, draw_one
	beq $a2, 2, draw_two
	beq $a2, 3, draw_three
	beq $a2, 4, draw_four
	beq $a2, 5, draw_five
	beq $a2, 6, draw_six
	beq $a2, 7, draw_seven
	beq $a2, 8, draw_eight
	beq $a2, 9, draw_nine
	
	
draw_zero:
	li $t9, 256         # Row stride (each row is 256 bytes apart)
	move $t8, $a1       # $t8 = current drawing address (top-left of digit)

	# Row 0: Top bar
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 1: sides
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 8($t8)

	# Row 2: sides
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 8($t8)
	
	# Row 3: sides
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 8($t8)

	# Row 4: Bottom bar
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	jr $ra
	
draw_one:
	li $t9, 256
	move $t8, $a1

	# Right column only
	sw $a0, 8($t8)
	add $t8, $t8, $t9
	sw $a0, 8($t8)
	add $t8, $t8, $t9
	sw $a0, 8($t8)
	add $t8, $t8, $t9
	sw $a0, 8($t8)
	add $t8, $t8, $t9
	sw $a0, 8($t8)

	jr $ra

draw_two:
	li $t9, 256
	move $t8, $a1

	# Top row
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 1: right
	add $t8, $t8, $t9
	sw $a0, 8($t8)

	# Row 2: middle row
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 3: left
	add $t8, $t8, $t9
	sw $a0, 0($t8)

	# Bottom row
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	 sw $a0, 4($t8)
	sw $a0, 8($t8)

	jr $ra

draw_three:
	li $t9, 256
	move $t8, $a1

	# Top row
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 1: right
	add $t8, $t8, $t9
	sw $a0, 8($t8)

	# Row 2: middle row
	add $t8, $t8, $t9
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 3: right
	add $t8, $t8, $t9
	sw $a0, 8($t8)

	# Bottom row
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	 sw $a0, 4($t8)
	sw $a0, 8($t8)

	jr $ra

draw_four:
	li $t9, 256
	move $t8, $a1

	# Row 0: left and right
	sw $a0, 0($t8)
	sw $a0, 8($t8)

	# Row 1
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 8($t8)

	# Row 2: full middle
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 3 and 4: right
	add $t8, $t8, $t9
	sw $a0, 8($t8)
	add $t8, $t8, $t9
	sw $a0, 8($t8)

	jr $ra

draw_five:
	li $t9, 256
	move $t8, $a1

	# Top row
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 1: left
	add $t8, $t8, $t9
	sw $a0, 0($t8)

	# Row 2: full middle
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 3: right
	add $t8, $t8, $t9
	sw $a0, 8($t8)

	# Bottom row
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	jr $ra

draw_six:
	li $t9, 256
	move $t8, $a1

	# Top row
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 1: left
	add $t8, $t8, $t9
	sw $a0, 0($t8)

	# Row 2: full middle
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 3: left and right
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 8($t8)

	# Bottom row
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	jr $ra

draw_seven:
	li $t9, 256       # Row stride (each row is 256 bytes apart)

    # Row 0: Top bar
	move $t8, $a1
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 1: right side
	li $t1, 1
	mul $t2, $t1, $t9
	add $t8, $a1, $t2
	sw $a0, 8($t8)

	# Row 2: right side
	li $t1, 2
	mul $t2, $t1, $t9
	add $t8, $a1, $t2
	sw $a0, 8($t8)

	# Row 3: right side
	li $t1, 3
	mul $t2, $t1, $t9
	add $t8, $a1, $t2
	sw $a0, 8($t8)

	# Row 4: right side
	li $t1, 4
	mul $t2, $t1, $t9
	add $t8, $a1, $t2
	sw $a0, 8($t8)

	jr $ra
draw_eight:
	li $t9, 256
	move $t8, $a1

	# Top row
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 1: sides
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 8($t8)

	# Row 2: full middle
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 3: sides
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 8($t8)

	# Bottom row
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	jr $ra

draw_nine:
	  li $t9, 256
	move $t8, $a1

	# Top row
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

    # Row 1: sides
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 8($t8)

	# Row 2: full middle
	add $t8, $t8, $t9
	sw $a0, 0($t8)
	sw $a0, 4($t8)
	sw $a0, 8($t8)

	# Row 3: right
	add $t8, $t8, $t9
	sw $a0, 8($t8)

	# Row 4: bottom right
	add $t8, $t8, $t9
	sw $a0, 8($t8)

	jr $ra
	
	
randomise_platforms:
	la $t0, platforms
	#### Platform 0 ####
	li $t1, 63        # row
	li $t2, 6         # col
	sw $t1, 0($t0)    # storage
	sw $t2, 4($t0)   
	#### Platform 1 ####	
	
	li $t1, 47
	sw $t1, 16($t0)   # row offset = 4 words = 16 bytes

	li $v0, 42
	li $a1, 48        # random col ∈ [0, 64 - 12]
	syscall
	sw $a0, 20($t0)   # col for platform 1   16 + 4
	
       #### Platform 2 ####
	li $t1, 31
	sw $t1, 32($t0)

	li $v0, 42
	li $a1, 48
	syscall
	sw $a0, 36($t0)   # 32 + 4

	#### Platform 3 ####
	li $t1, 15
	sw $t1, 48($t0)

	li $v0, 42
	li $a1, 48
	syscall
	sw $a0, 52($t0)  # 48 + 4

	jr $ra
    
apply_gravity:
	addi $sp, $sp, -4
	sw $ra, 0($sp)     # Store ra on stack
	
	# Load doodle position
	la $t0, doodle_position
	lw $t1, 0($t0)           # $t1 = doodle row
	lw $t2, 4($t0)           # $t2 = doodle column
	
	# check if jump
	la $a0, jump_counter
	lw $a1, 0($a0)
	bgtz $a1, jump_up

	addi $t3, $t1, 1           # $t3 = row below doodle
	
	# If already at bottom row, game ends
	li $t4, 63               # t4 = bottom row limit
	bge $t1, $t4, end_game  # If doodle == row 31, skip falling
	
	# Setup loop variables for checking platforms
	li $t5, 0                # $t5 = platform index
	la $t6, platforms        # $t6 = address of platforms array
	lw $t7, num_platforms    # $t7 = total number of platforms
	li $t8, 16               # $t8 = size of one platform in bytes (4 words)
	
check_each_platform:
	bge $t5, $t7, apply_fall      # if index >= num_platforms, fall

	mul $t9, $t5, $t8             # offset = i * 16 bytes
	add $t9, $t6, $t9             # $t9 = &platforms[i]

	lw $s1, 0($t9)                # platform row
	lw $s2, 4($t9)                # platform col

	bne $s1, $t3, next_plat       # if doodle row != plat row

	la $s3, platform_width
	lw $s3, 0($s3)                # platform width

	add $s4, $s2, $s3             # plat_col + width
	addi $s2, $s2, -2             # left edge tolerance

	blt $t2, $s2, next_plat       # if doodle col < platform left
	bge $t2, $s4, next_plat       # if doodle col >= platform right

	# Jump reset
	la $a0, jump_counter
	la $s5, jump_height
	lw $s6, 0($s5)
	sw $s6, 0($a0)

	# Check and update score if new platform
	la $t0, last_platform_index
	lw $t1, 0($t0)                # last_platform_index
	bne $t1, $t5, update_score    # if current ≠ last
	
	j done_gravity
	
update_score:
	la $t0, last_platform_index
	sw $t5, 0($t0)   # $t5 = current platform index 
	  # Load base address of score array
	la $t2, score

	# Load current digits
	lw $t3, 0($t2)    # ones
	lw $t4, 4($t2)    # tens
	lw $t5, 8($t2)    # hundreds
	lw $t6, 12($t2)   # thousands

	# Increment
	addi $t3, $t3, 1
	li $t7, 10

	blt $t3, $t7, store_score

	li $t3, 0
	addi $t4, $t4, 1
	blt $t4, $t7, store_score

	li $t4, 0
	addi $t5, $t5, 1
	blt $t5, $t7, store_score

	li $t5, 0
	addi $t6, $t6, 1
	blt $t6, $t7, store_score

	li $t6, 9        # max out at 9999

	
store_score:
	sw $t3, 0($t2)
	sw $t4, 4($t2)
	sw $t5, 8($t2)
	sw $t6, 12($t2)

    # Update last platform index
	li $t0, 16
	la $t1, scroll_counter
	sw $t0, 0($t1)

end_update_score:
	j done_gravity
    
next_plat:
	addi $t5, $t5, 1         # platform index++
	j check_each_platform
	
apply_fall:
	sw $t3, 0($t0)           # update doodle row = row + 1 (move down)
	j done_gravity
	
	
jump_up:
	subi $t1, $t1, 1
	sw   $t1, 0($t0)         # row--
	subi $a1, $a1, 1
	sw   $a1, 0($a0)         # jump_counter--
	
done_gravity:
	lw $ra, 0($sp)             # Restore return address
	addi $sp, $sp, 4           # Reset stack
	jr $ra                     # Return	
	
	
clear_doodle:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	lw $t2, background
	jal draw_character_doodle
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

delay_frame:
	li $v0, 32        # syscall for sleep
	li $a0, 40        # 40 milliseconds
	syscall
	jr $ra

read_input:
	lw $t0, keypress
	lw $t0, 0($t0)
	beq $t0, 1, handle_input
	
	j unknown_input
	
handle_input:
	lw $t1, keyvalue
	lw $t1, 0($t1)
	beq $t1, 0x61, handle_a
	beq $t1, 0x64, handle_d
	beq $t1, 0x72, handle_restart 
	beq $t1, 0x71, handle_quit   
	j unknown_input
	
handle_restart:
	jal randomise_platforms
	jal spawn_coin_above_platform
	li $t0, 0
	la $t1, score
	sw $t0, 0($t1)     # ones
	sw $t0, 4($t1)     # tens
	sw $t0, 8($t1)     # hundreds
	sw $t0, 12($t1)    # thousands
	sw $t0, gravity_counter
	sw $t0, jump_counter
	sw $t0, last_platform_index
	jal draw_bg_and_plat
	jal init_draw_doodle
	j game_loop

handle_quit:
	lw $t0, font_colour          # Load background color into $t0
	lw $t1, display_dimension
	mul $t2, $t1, $t1           # total_pixels = 32 * 32
	li $t3, 0                   # index = 0
	jal fill_loop
	li $t2, 8        # row
	li $t3, 4       # col
	mul $t4, $t2, 256
	mul $t5, $t3, 4
	add $t6, $t1, $t4
	add $t6, $t6, $t5   # $t6 = base pixel of 'R'
	add $t6, $t6, $s0
	lw $t7, white_colour	
	li $v0, 10     # syscall to exit program
	syscall

handle_a:
	la   $t0, doodle_position
	lw   $t1, 0($t0)        # row
	lw   $t2, 4($t0)        # col

    # Decrease col with wrap-around
	li   $t3, 0
	beq  $t2, $t3, wrap_left
	subi $t2, $t2, 1
	j save_doodle_pos

wrap_left:
	li $t2, 63
	j save_doodle_pos

handle_d:
	la $t0, doodle_position
	lw $t1, 0($t0)        # row
	lw $t2, 4($t0)        # col

	# Increase col with wrap-around
	li $t3, 63
	beq $t2, $t3, wrap_right
	addi $t2, $t2, 1
	j save_doodle_pos
	
	
wrap_right:
	li $t2, 0
	j save_doodle_pos
    
unknown_input:
	jr $ra
                
save_doodle_pos:
	sw $t1, 0($t0)
	sw $t2, 4($t0)
	jr $ra
                
# Draw coin object (9 pixels)
draw_coin:
	lw $t0, coin_colour
	lw $t9, coin_colour_center
	la $t1, coin_position
	lw $t2, 0($t1)   # row
	lw $t3, 4($t1)   # col

	li $t4, 0       # row offset
coin_row_loop:
	bge $t4, 3, coin_done
	li $t5, 0       # col offset
coin_col_loop:
	bge $t5, 3, coin_next_row
	add $t6, $t2, $t4   # row
	add $t7, $t3, $t5   # col
	mul $t8, $t6, 64
	add $t8, $t8, $t7
	sll $t8, $t8, 2
	add $t8, $t8, $s0

    # If center pixel (row offset = 1, col offset = 1), use darker color
	li $v0, 1
	beq $t4, $v0, check_col_center
	sw $t0, 0($t8)
	j skip_store
check_col_center:
	beq $t5, $v0, store_darker
	sw $t0, 0($t8)
    j skip_store
store_darker:
	sw $t9, 0($t8)
skip_store:
	addi $t5, $t5, 1
	j coin_col_loop
coin_next_row:
	addi $t4, $t4, 1
	j coin_row_loop
coin_done:
	jr $ra

# Draw enemy object (3x2 block)
draw_enemy:
	lw $t0, enemy_colour
	la $t1, enemy_position
	lw $t2, 0($t1)   # row
	lw $t3, 4($t1)   # col

	li $t4, 0       # row offset
enemy_row_loop:
	bge $t4, 2, enemy_done
	li $t5, 0       # col offset
enemy_col_loop:
	bge $t5, 3, enemy_next_row
	add $t6, $t2, $t4   # row
	add $t7, $t3, $t5   # col
	mul $t8, $t6, 32
	add $t8, $t8, $t7
	sll $t8, $t8, 2
	add $t8, $t8, $s0
	sw $t0, 0($t8)
	addi $t5, $t5, 1
	j enemy_col_loop
enemy_next_row:
	addi $t4, $t4, 1
	j enemy_row_loop
enemy_done:
	jr $ra
init_draw_doodle:
	addi $sp, $sp, -4      # make space on stack
    	sw   $ra, 0($sp)       # save return address
	la $t0, platforms         # base address of platform array
	lw $a0, 0($t0)            # row of platform 0
	lw $t1, 4($t0)            # col of platform 0

	addi $a0, $a0, -1           # row = platform row - doodle height (3)
	addi $a1, $t1, 2            # col = center of 4-unit-wide platform

	# Save base row and col to memory (for tracking address)
	la $t2, doodle_position
	sw $a0, 0($t2)            # store row
	sw $a1, 4($t2)            # store col
	lw $t2, doodle_colour          # doodle color
	jal draw_character_doodle
	lw   $ra, 0($sp)       # restore return address
	addi $sp, $sp, 4       # clean up stack
	jr $ra
draw_character_doodle:
	addi $sp, $sp, -4      # make space on stack
    	sw   $ra, 0($sp)       # save return address
	la $t0, doodle_position
	lw $a0, 0($t0)            # base row
	lw $a1, 4($t0)            # base col
	
	# Check if col == 63 → left on edge
	li $t4, 63
	beq $a1, $t4, left_on_edge
	
   	# Check if col == 62 → middle on edge
	li $t4, 62
	beq $a1, $t4, middle_on_edge
	
	jal draw_normal
	lw   $ra, 0($sp)       # restore return address
	addi $sp, $sp, 4       # clean up stack
	jr $ra
	

# Draw a single pixel at (row=$t3, col=$t4) with color=$t2
# Requires $s0 = base address of display

middle_on_edge:
	#left block (col = 30)
	li $t4, 62	  #a0 is row  a1 is col
	move $t3, $a0
	jal draw_pixel

	# middle block (col = 31)
	move $t3, $a0
	li $t4, 63
	jal draw_pixel
	
	addi $t3, $a0, -1
	jal draw_pixel
	addi $t3, $a0, -2
	jal draw_pixel

	# right block (col = 0)
	li $t4, 0
	move $t3, $a0
	jal draw_pixel
	addi $t3, $t3, -2
	jal draw_pixel

	j end_draw


left_on_edge:
	#left block (col = 31)
	li $t4, 63 	  #a0 is row  a1 is col
	move $t3, $a0
	jal draw_pixel

	# middle block (col = 0)
	move $t3, $a0
	li $t4, 0  
	jal draw_pixel
	
	addi $t3, $a0, -1
	jal draw_pixel
	addi $t3, $a0, -2
	jal draw_pixel

	# right block (col = 1)
	li $t4, 1
	move $t3, $a0
	jal draw_pixel
	addi $t3, $t3, -2
	jal draw_pixel

	j end_draw

end_draw:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

draw_normal:
	addi $sp, $sp, -4      # make space on stack
    	sw   $ra, 0($sp)       # save return address
	# Top row (base - 2): col +1 and col +2
	addi $t3, $a0, -2           # row
	addi $t4, $a1, 1            # col
	jal draw_pixel
	addi $t4, $a1, 2
	jal draw_pixel
	
	# Middle row (base - 1): col +1
	addi $t3, $a0, -1
	addi $t4, $a1, 1
	jal draw_pixel

	# Bottom row (base): col, col +1, col +2
	move $t3, $a0
	move $t4, $a1
	jal draw_pixel
	addi $t4, $a1, 1
	jal draw_pixel
	addi $t4, $a1, 2
	jal draw_pixel
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

# Draw a single pixel at (row=$t3, col=$t4) with color=$t2
# Requires $s0 = base address of display

draw_pixel:
	mul $t5, $t3, 64           # row * 32
	add $t5, $t5, $t4          # + col
	sll $t5, $t5, 2            # * 4
	add $t5, $t5, $s0          # final address
	sw $t2, 0($t5)            # draw pixel
	jr $ra
	
	
	#def draw bg_plat
		#draw_background()
		#draw_platform()	
draw_bg_and_plat:
	addi $sp, $sp, -4
	sw   $ra, 0($sp)
	jal draw_background	    # background is now drawn
	jal draw_platforms    
	lw   $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
draw_platforms:
	addi $sp, $sp, -4
	sw   $ra, 0($sp)
	la $t0, platforms         # base of platform array
	lw $t1, num_platforms     # total number of platforms
	li $t2, 0                 # platform index
	li $t3, 16                # bytes per platform entry
	li $t4, 64                # screen width in units
	lw $t7, platform_colour

platform_loop:
	bge $t2, $t1, done_drawing # if index of platform > 4

	mul $t5, $t2, $t3         # offset = i * 16, change platform
	add $t8, $t0, $t5         # $t8 = platform[i] address

	lw $a0, 0($t8)            # row
	lw $a1, 4($t8)            # col

    # Compute offset = (row * 64 + col) * 4
	mul $t9, $a0, $t4         # row * 32
	add $t9, $t9, $a1         # + col
	sll $t9, $t9, 2           # * 4 (bytes per word)
	add $t9, $t9, $s0         # final address

	jal draw_line

	addi $t2, $t2, 1          # i++
	j platform_loop

done_drawing:
	lw   $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

draw_line:
	li $t6, 0            # counter = 0
	
line_loop:
	bge $t6, 16, done_line
	sw $t7, 0($t9)       # draw pixel at address
	addi $t9, $t9, 4     # move to next horizontal pixel (1 word)
	addi $t6, $t6, 1
	j line_loop
    
done_line:
	jr $ra
    
one_drawing:
	jr $ra
	
draw_background:
	lw $t0, background          # Load background color into $t0
	lw $t1, display_dimension
	mul $t2, $t1, $t1           # total_pixels = 32 * 32
	li $t3, 0                   # index = 0

fill_loop:
	bge $t3, $t2, done_fill     # if index >= total_pixels, finish
	sll $t4, $t3, 2             # offset = index * 4 (each pixel is 4 bytes)
	add $t5, $s0, $t4           # address = base + offset
	sw $t0, 0($t5)              # store background color at address
	addi $t3, $t3, 1            # index++
	j fill_loop

done_fill:
	jr $ra                       # return
	

quit_game:
	li $v0, 10
	syscall     
	
end_game:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	lw $t0, font_colour          # Load black color into $t0
	lw $t1, display_dimension
	mul $t2, $t1, $t1           # total_pixels = 32 * 32
	li $t3, 0                   # index = 0
	jal fill_loop
	li $t2, 8        # row
	li $t3, 4       # col
	mul $t4, $t2, 256
	mul $t5, $t3, 4
	add $t6, $t1, $t4
	add $t6, $t6, $t5   # $t6 = base pixel of 'R'
	add $t6, $t6, $s0
	lw $t7, white_colour	
	
	jal draw_RESET
	jal draw_WITH

wait_for_restart:
	li $v0, 32           # Sleep for 30ms to prevent spamming
	li $a0, 30
	syscall

	lw $t0, keypress     # Check if key is pressed
	lw $t0, 0($t0)
	beq $t0, 1, check_restart_key  # if key is pressed, check value

	j wait_for_restart	
    
check_restart_key:
	lw $t1, keyvalue     # Get key value
	lw $t1, 0($t1)
	li $t2, 0x72         # ASCII for 'r'
	beq $t1, $t2, handle_restart

	j wait_for_restart 
	
draw_RESET:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# Draw R
	move $t8, $t6
	jal draw_R

	# Draw E
	addi $t8, $t6, 24
	jal draw_E

	# Draw S
	 addi $t8, $t6, 48
	jal draw_S

	# Draw E
	 addi $t8, $t6, 72
	jal draw_E

	# Draw T
	 addi $t8, $t6, 96
	jal draw_T
	 lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

draw_R:
	# Row 0
	sw $t7, 0($t8)
	sw $t7, 4($t8)
	sw $t7, 8($t8)
	sw $t7, 12($t8)
	sw $t7, 16($t8)

	# Row 1
	add $t8, $t8, $t9
	sw $t7, 0($t8)
	sw $t7, 16($t8)

	# Row 2
	add $t8, $t8, $t9
	 sw $t7, 0($t8)
	sw $t7, 16($t8)

	# Row 3
	add $t8, $t8, $t9
	sw $t7, 0($t8)
	sw $t7, 4($t8)
	sw $t7, 8($t8)
	sw $t7, 12($t8)
	
	# Row 4	
	add $t8, $t8, $t9
	sw $t7, 0($t8)
	sw $t7, 8($t8)

	# Row 5: X  X
	   add $t8, $t8, $t9
	sw $t7, 0($t8)
	sw $t7, 12($t8)

    	# Row 6: X   X
	add $t8, $t8, $t9
	sw $t7, 0($t8)
	sw $t7, 16($t8)

	jr $ra

draw_E:
	# Row 0	
	sw $t7, 0($t8)
	sw $t7, 4($t8)
	sw $t7, 8($t8)
	sw $t7, 12($t8)
	sw $t7, 16($t8)

	# Row 1	
	   add $t8, $t8, $t9
	sw $t7, 0($t8)

	# Row 2	
	  add $t8, $t8, $t9
	sw $t7, 0($t8)

	# Row 3	
	add $t8, $t8, $t9
	sw $t7, 0($t8)
	sw $t7, 4($t8)
	sw $t7, 8($t8)
	sw $t7, 12($t8)
	sw $t7, 16($t8)

	# Row 4	
	add $t8, $t8, $t9
	sw $t7, 0($t8)

	# Row 5	
	add $t8, $t8, $t9
	sw $t7, 0($t8)

	# Row 6	
	add $t8, $t8, $t9
	sw $t7, 0($t8)
	sw $t7, 4($t8)
	sw $t7, 8($t8)
	sw $t7, 12($t8)
	sw $t7, 16($t8)

	jr $ra
    
draw_S:
	# Row 0	
	sw $t7, 0($t8)
	sw $t7, 4($t8)
	sw $t7, 8($t8)
	  sw $t7, 12($t8)
	sw $t7, 16($t8)

	# Row 1	
	add $t8, $t8, $t9
	sw $t7, 0($t8)

	# Row 2	
	 add $t8, $t8, $t9
	  sw $t7, 0($t8)

	# Row 3	
	add $t8, $t8, $t9
	sw $t7, 0($t8)
	sw $t7, 4($t8)
	sw $t7, 8($t8)
	sw $t7, 12($t8)
	sw $t7, 16($t8)

	# Row 4	
	add $t8, $t8, $t9
	sw $t7, 16($t8)

	# Row 5	
	add $t8, $t8, $t9
	sw $t7, 16($t8)

	# Row 6	
	add $t8, $t8, $t9
	sw $t7, 0($t8)
	sw $t7, 4($t8)
	sw $t7, 8($t8)
	sw $t7, 12($t8)
	sw $t7, 16($t8)

	jr $ra

draw_T:
	# Row 0	
	sw $t7, 0($t8)
	sw $t7, 4($t8)
	sw $t7, 8($t8)
	sw $t7, 12($t8)
	sw $t7, 16($t8)

	# Row 1–6	
	li $t1, 1
	
draw_T_loop:
	bgt $t1, 6, done_draw_T
	add $t8, $t8, $t9
	sw $t7, 8($t8)     # middle column (3rd pixel)
	addi $t1, $t1, 1
	j draw_T_loop

done_draw_T:
	jr $ra
    
    
draw_WITH:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# Move to next line for 'WITH'
	li $t9, 256         # row stride
	li $t8, 8           # move down 8 rows
	mul $t8, $t8, $t9
	add $t6, $t6, $t8   # move base to row + 8

	# Draw W
	move $t8, $t6
	jal draw_W

	# Draw I
	addi $t8, $t6, 24
	jal draw_I

	# Draw T
	addi $t8, $t6, 48
	jal draw_T

	# Draw H
	addi $t8, $t6, 72
	jal draw_H

	# Move to another line for 'R'
	li $t8, 256
	mul $t8, $t8, 8
	add $t6, $t6, $t8     # move base to row + 16

	move $t8, $t6
	jal draw_R
	lw $ra, 0($sp)
	addi $sp, $sp, 4

	jr $ra
    
    
draw_W:
	li $t9, 256        # row stride
	move $t1, $t8      # base address

	# Row 0
	sw $t7, 0($t1)
	sw $t7, 16($t1)

	# Row 1
	add $t1, $t1, $t9
	sw $t7, 0($t1)
	sw $t7, 16($t1)

	# Row 2
	add $t1, $t1, $t9
	sw $t7, 0($t1)
	sw $t7, 8($t1)
	sw $t7, 16($t1)

	# Row 3
	add $t1, $t1, $t9
	sw $t7, 0($t1)
	sw $t7, 8($t1)
	sw $t7, 16($t1)

	# Row 4
	add $t1, $t1, $t9
	sw $t7, 0($t1)
	sw $t7, 8($t1)
	sw $t7, 16($t1)

	# Row 5
	add $t1, $t1, $t9
	sw $t7, 0($t1)
	sw $t7, 16($t1)

	# Row 6
	add $t1, $t1, $t9
	sw $t7, 8($t1)

	jr $ra
    
draw_I:
	li $t9, 256
	  move $t1, $t8

	# Top bar
	sw $t7, 0($t1)
	sw $t7, 4($t1)
	sw $t7, 8($t1)

	# Rows 1–5: center column
	li $t2, 0
draw_I_loop:
	beq $t2, 5, draw_I_bottom
	add $t1, $t1, $t9
	sw $t7, 4($t1)
	addi $t2, $t2, 1
	j draw_I_loop

draw_I_bottom:
	add $t1, $t1, $t9
	sw $t7, 0($t1)
	sw $t7, 4($t1)
	sw $t7, 8($t1)
	jr $ra    
    
    
draw_H:
	li $t9, 256
	move $t1, $t8

	# Rows 0–6
	li $t2, 0
draw_H_loop:
	beq $t2, 3, draw_H_middle
	sw $t7, 0($t1)
	sw $t7, 16($t1)
	add $t1, $t1, $t9
	addi $t2, $t2, 1
	j draw_H_loop

draw_H_middle:
	sw $t7, 0($t1)
	sw $t7, 4($t1)
	sw $t7, 8($t1)
	sw $t7, 12($t1)
	sw $t7, 16($t1)
	add $t1, $t1, $t9
	addi $t2, $t2, 1

    # Remaining rows
draw_H_rest:
	bge $t2, 7, done_H
	sw $t7, 0($t1)
	sw $t7, 16($t1)
	add $t1, $t1, $t9
	addi $t2, $t2, 1
	j draw_H_rest

done_H:
	jr $ra
