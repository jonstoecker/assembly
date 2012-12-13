# TV Remote Firmware for MIPS R-series 
# by Jonathan Stoecker
# March 2011

	.data
mw_chan:
	.word 0, 0, 0, 0, 0
mw_timers:
	.word 0, 0, 0, 0, 0
ch_timers:
	.word 0:100				# contains space for all 100 channels 
msg_power_status_off:
	.asciiz "Power off"
msg_power_status_on:
	.asciiz "Power on"
msg_channel:
	.asciiz "Channel "
msg_volume:
	.asciiz "Volume "
msg_sleep_timer:
	.asciiz "Sleep timer "
msg_sec:
	.asciiz " sec"
msg_power_on:
	.asciiz "Power is now on.\n"
msg_power_off:
	.asciiz "Power is now off.\n"
msg_power_sleep:
	.asciiz "Power is now off (sleep).\n"
msg_go_back:
	.asciiz "Will return to channel "
msg_returning:
	.asciiz "Returning to channel "
msg_in:
	.asciiz " at "
msg_off:
	.asciiz "off."
msg_fave_channels:
	.asciiz "Favorite channels:\n"
msg_divider:
	.asciiz " : "
space:
	.asciiz " "
dash:
	.asciiz "-"
newline:
	.asciiz "\n" 


#------------------------------------------------------------------------------#
# Registers
# $s1 -- current time (second)
# $s2 -- power status
# $s3 -- current channel
# $s4 -- current volume
# $s5 -- sleep timer
# $s6 -- first digit for channel changer
# $s7 -- indexer for channel time array
#
# Stack
# Offset 0 -- timing values for sleep timer
# Offset 4 -- timing values for channel changer
# Offset 8 -- timine values for go back function
# Offset 12 -- return channel for go back function
#------------------------------------------------------------------------------#

	.text
	.globl main
main:
	li $s0, 300			# init s0 as a 10ms counter, 3000 ms (3 sec) total
	li $s1, 0			# init s1 as timer = 0 sec
	li $s2, 0			# init s2 as power status; 1=on / 0=off
	li $s3, 0			# init s3 as channel = 0
	li $s4, 50			# init s4 as volume = 50
	li $s5, 0			# init s5 as sleep timer = 0 (off)
	li $s6, 0			# init s6 as first digit for channel changer 
	la $s7, ch_timers	# init s7 as indexer for channel timers 
	addi $sp, -16		# push stack pointer for storing timers
	sw $0, 0($sp)		# offset 4 on stack for sleep timer
	sw $0, 4($sp)		# offset 8 on stack for digit timer
	sw $0, 8($sp)		# go back timer for go back function
	sw $0, 12($sp)		# go back channel
mainloop:
	# Keyboard polling loop 
	lui $t0, 0xFFFF # $t0 = 0xFFFF0000
	lw $t1, 0($t0)
	andi $t1, $t1, 0x0001 # $t1 &= 0x00000001
	beq $t1, $0, mainloop1 # if input bit is zero, continues polling loop
	lw $a0, 4($t0) 	# otherwise jump to process input function 
	jal process_input 

mainloop1:
	# delay for 10ms
	jal delay_10ms
	# timing loop -- checks for 2000, 1000 and 0 ms values for increasing time
	addi $s0, $s0, -1		
	beq $s0, 200, inc_timer
	beq $s0, 100, inc_timer
	beq $s0, 0, inc_timer
	j skip_timer
inc_timer:		# controls timing loops for sleep timer and channel change	
	addi $s1, $s1, 1
	beq $s2, $0, skip_timer		# do not change timers if power off
	# increase channel timer by one sec 
	lw $t0, 0($s7)
	la $t1, mw_timers
	lw $t2, 16($t1)
	addi $t0, $t0, 1
	sw $t0, 0($s7)
	blt $t0, $t2, inc_timer2 
	move $a0, $t0
	jal update_favorites	
	# end increase ------------------ #
inc_timer2:
	lw $t0, 4($sp)
	bne $s1, $t0, inc_timer3
	jal digit_chg_delayed		# change channel if digit timer expires
inc_timer3:
	lw $t0, 8($sp)
	bne $s1, $t0, inc_timer4
	jal go_back_chan			# change channel if go back timer expires
inc_timer4:	
	beq $s5, $0, skip_timer
	addi $s5, $s5, -1
	bne $s5, $0, skip_timer
	jal power_change_sleep
skip_timer:
	bne $s0, $0, mainloop4	# skips to end of polling loop if > 0
	li $s0, 300					# otherwise reset to 3000 ms and print status

	# check power status and jump if necessary
	beq $s2, 1, power_is_on

	# print counter and power off msg and jump to end of loop
	move $a0, $s1
	li $v0, 1
	syscall
	la $a0, msg_sec		# load and print second
	li $v0, 4
	syscall
	la $a0, msg_divider
	syscall
	la $a0, msg_power_status_off
	syscall
	la $a0, newline
	syscall
	j mainloop4

power_is_on:
	# print current time
	move $a0, $s1
	li $v0, 1
	syscall
	la $a0, msg_sec		# load and print second
	li $v0, 4
	syscall
	la $a0, msg_divider
	syscall
	
	# print power on msg
	la $a0, msg_power_status_on
	syscall
	la $a0, msg_divider
	syscall
	
	# print channel msg
	la $a0, msg_channel
	syscall

	# print channel # (stored in $s3)
	move $a0, $s3
	li $v0, 1
	syscall

	# print divider 
	la $a0, msg_divider
	li $v0, 4
	syscall
	
	# print volume msg
	la $a0, msg_volume
	syscall

	# print volume #
	move $a0, $s4
	li $v0, 1
	syscall

	# print divider 
	la $a0, msg_divider
	li $v0, 4
	syscall
	
	# print sleep timer
	la $a0, msg_sleep_timer
	syscall
	beq $s5, $0, mainloop3
	move $a0, $s5			# print # if active
	li $v0, 1
	syscall
	la $a0, msg_sec
	li $v0, 4
	syscall
	la $a0, newline
	syscall
	j mainloop4

mainloop3:
	# print sleep timer off msg
	la $a0, msg_off
	syscall
	# print newline
	la $a0, newline
	syscall
	
mainloop4:
	j mainloop

# exit program --------------------------------------------------------------#
exit:
	li $v0, 10 # exit
	syscall
#----------------------------------------------------------------------------#
delay_10ms:
	li $t0, 25000 
delay_10ms_loop:
	addi $t0, $t0, -1
	bne $t0, $0, delay_10ms_loop
	jr $ra
#----------------------------------------------------------------------------#

# process_input: checks keyboard input and acts accordingly
process_input:

	beq $a0, 112, power_change			# changes power status if nec.
	beq $s2, $0, process_input_done		# will not process input if power off 

	# digital inputs
	beq $a0, 48, digital_channel	# 48 = 0 
	beq $a0, 49, digital_channel	# 49 = 1 
	beq $a0, 50, digital_channel	# 50 = 2 
	beq $a0, 51, digital_channel	# 51 = 3 
	beq $a0, 52, digital_channel	# 52 = 4 
	beq $a0, 53, digital_channel	# 53 = 5 
	beq $a0, 54, digital_channel	# 54 = 6 
	beq $a0, 55, digital_channel	# 55 = 7 
	beq $a0, 56, digital_channel	# 56 = 8 
	beq $a0, 57, digital_channel	# 57 = 9 
	li $s6, 0						# reset first digit
	sw $0, 4($sp)					# reset digit wait timer
	# check inputs by ascii code and jump to appropriate function 
	beq $a0, 117, channel_up		# 117 = u
	beq $a0, 100, channel_down 		# 100 = d
	beq $a0, 108, volume_up			# 108 = l
	beq $a0, 107, volume_down		# 107 = k
	beq $a0, 115, sleep_timer		# 115 = s
	beq $a0, 118, view_history		# 118 = v
	beq $a0, 98, go_back			# 98 = b

process_input_done:
	jr $ra			# jump back to timer loop

# Power change functions -- changes power status ------------------------- #
power_change:
	beq $s2, $0, turn_pwr_on		# jump to turn power on if off
	li $s2, 0						# else turn off
	la $a0, msg_power_off
	li $v0, 4 
	syscall
	li $s5, 0						# reset sleep timer
	j process_input_done
turn_pwr_on:
	li $s2, 1						# sets power to on
	la $a0, msg_power_on
	li $v0, 4
	syscall 
	j process_input_done			# return to timer loop
power_change_sleep:
	li $s2, 0						# set power status = off
	li $s6, 0						# reset digit wait timer 
	sw $0, 4($sp)					 
	sw $0, 8($sp)					# reset go back timer
	la $a0, msg_power_sleep
	li $v0, 4
	syscall
	jr $ra						# return to timing loop

# Channel button functions -- controls channel up/down with print ------- #
channel_up:
	li $t0, 99		# for testing rollover
	beq $s3, $t0, channel_wrapu
	addi $s3, 1		# increases channel # by one
	j channel_print
channel_wrapu:
	li $s3, 0		# set channel to 0 if rollover
	j channel_print
channel_down:
	beq $s3, $0, channel_wrapd
	addi $s3, -1		# decreases channel # by one
	j channel_print
channel_wrapd:
	li $s3, 99		# set channel to 0 if rollover
channel_print:	
	# change channel index value
	la $t6, ch_timers
	add $t5, $s3, $s3
	add $t5, $t5, $t5	
	add	$t7, $t5, $t6
	la $s7, 0($t7)	 
	# ------------------------ #
	la $a0, msg_channel
	li $v0, 4
	syscall
	move $a0, $s3
	li $v0, 1
	syscall
	la $a0, newline
	li $v0, 4
	syscall 
	j process_input_done	

# Volume button functions -- controls volume up/down with print ------- #
# volume is contained within $s4 #
volume_up:
	beq $s4, 99, volume_print
	addi $s4, 1		# increases volume # (s4) by one
	j volume_print
volume_down:
	beq $s4, $0, volume_print 
	addi $s4, -1		# increases volume # (s4) by one
volume_print:	
	la $a0, msg_volume
	li $v0, 4
	syscall
	move $a0, $s4
	li $v0, 1
	syscall
	la $a0, newline
	li $v0, 4
	syscall 
	j process_input_done

# Sleep timer -- allows user to set a sleep timer value ---------------- #
sleep_timer:
	lw $t0, 0($sp)
# increment sleep timer count if already triggered within last 3 sec
	bgt $t0, $s1, sleep_time_increment
	
# print status
sleep_time_print:	
	la $a0, msg_sleep_timer
	li $v0, 4
	syscall
	bne $s5, $0, sleep_time_num
	la $a0, msg_off
	syscall
	la $a0, newline
	syscall
	j sleep_done

# print numbers instead of "off"
sleep_time_num:
	move $a0, $s5
	li $v0, 1
	syscall
	la $a0, msg_sec
	li $v0, 4
	syscall
	la $a0, newline
	syscall
	j sleep_done 
sleep_time_increment:
	addi $s5, $s5, 5		# add 5 sec to sleep timer
	blt $s5, 200, sleep_time_print
	li $s5, 0				# sets to zero if 200 sec exceeded
	j sleep_time_print
sleep_done:
	addi $t0, $s1, 3
	sw $t0, 0($sp)
	j process_input_done	

# Digital Channel Changer -- enables user to jump direct to channel ------- #
digital_channel:
	lw $t0, 4($sp)
	bgt $t0, $s1, second_digit	# enter second digit if timer running 
	move $s6, $a0			# store input in s6
	addi $s6, $s6, -48		# change from ascii to decima
	la $a0, msg_channel		# print status
	li $v0, 4
	syscall
	move $a0, $s6
	li $v0, 1
	syscall
	la $a0, dash
	li $v0, 4
	syscall
	la $a0, newline
	syscall
digit_done:
	addi $t0, $s1, 2		# increment wait timer for input
	sw $t0, 4($sp)
	j process_input_done
digit_done2:
	sw $0, 4($sp)
	j process_input_done
second_digit:
	move $t1, $a0			# store second input in t1
	addi $t1, $t1, -48		# convert from ascii to decimal
	li $t2, 10				# t2 as multiplier for first digit
	mult $s6, $t2			# multiply
	mflo $t0
	add $s3, $t0, $t1		# add integers and store as new channel
	# change channel index value
	la $t6, ch_timers
	add $t5, $s3, $s3
	add $t5, $t5, $t5	
	add	$t7, $t5, $t6
	la $s7, 0($t7)	 
	# -------------------------
	la $a0, msg_channel		# print result
	li $v0, 4
	syscall
	move $a0, $s3
	li $v0, 1
	syscall
	la $a0, newline
	li $v0, 4
	syscall 
	j digit_done2	
digit_chg_delayed:
	move $s3, $s6			# copy stored digit into main channel store
	# change channel index value
	la $t6, ch_timers
	add $t5, $s3, $s3
	add $t5, $t5, $t5	
	add	$t7, $t5, $t6
	la $s7, 0($t7)	 
	# ------------------------ #
	la $a0, msg_channel
	li $v0, 4
	syscall
	move $a0, $s3
	li $v0, 1
	syscall
	la $a0, newline
	li $v0, 4
	syscall
	jr $ra

# View History functions -- lists 5 most watched channels ------------------ #
view_history:
	# print greeting and list channels
	la $a0, msg_fave_channels
	li $v0, 4
	syscall
	la $a0, msg_channel		# first channel
	syscall
	la $t0, mw_chan		
	lw $a0, 0($t0)
	li $v0, 1
	syscall
	la $a0, msg_divider
	li $v0, 4
	syscall
	la $t0, mw_timers
	lw $a0, 0($t0)
	li $v0, 1
	syscall
	la $a0, msg_sec
	li $v0, 4
	syscall
	la $a0, newline
	syscall	
	la $a0, msg_channel		# second channel
	syscall
	la $t0, mw_chan
	lw $a0, 4($t0)
	li $v0, 1
	syscall
	la $a0, msg_divider
	li $v0, 4
	syscall
	la $t0, mw_timers
	lw $a0, 4($t0)
	li $v0, 1
	syscall
	la $a0, msg_sec
	li $v0, 4
	syscall
	la $a0, newline
	syscall
	la $a0, msg_channel		# third channel
	syscall
	la $t0, mw_chan		
	lw $a0, 8($t0)
	li $v0, 1
	syscall
	la $a0, msg_divider
	li $v0, 4
	syscall
	la $t0, mw_timers
	lw $a0, 8($t0)
	li $v0, 1
	syscall
	la $a0, msg_sec
	li $v0, 4
	syscall
	la $a0, newline
	syscall
	la $a0, msg_channel		# fourth channel
	syscall
	la $t0, mw_chan		
	lw $a0, 12($t0)
	li $v0, 1
	syscall
	la $a0, msg_divider
	li $v0, 4
	syscall
	la $t0, mw_timers
	lw $a0, 12($t0)
	li $v0, 1
	syscall
	la $a0, msg_sec
	li $v0, 4
	syscall
	la $a0, newline
	syscall
	la $a0, msg_channel		# fifth channel
	syscall
	la $t0, mw_chan		
	lw $a0, 16($t0)
	li $v0, 1
	syscall
	la $a0, msg_divider
	li $v0, 4
	syscall
	la $t0, mw_timers
	lw $a0, 16($t0)
	li $v0, 1
	syscall
	la $a0, msg_sec
	li $v0, 4
	syscall
	la $a0, newline
	syscall
	j process_input_done	# end process input

# ------------ #
# t0 = address of fav chan #s 
# t1 = address of fav chan timers
# ------------ #

update_favorites:				# check timer against favorites and update
	la $t1, mw_timers
	la $t0, mw_chan
uf1:	
	lw $t2, 0($t1) 
	blt $a0, $t2, uf2
	lw $t4, 0($t1)
	lw $t3, 0($t0)
	sw $a0, 0($t1)
	lw $t7, 0($t0)
	sw $s3, 0($t0)
	beq $s3, $t7, uf_done
	li $t9, 3
	j uf_push_loop
uf2:
	lw $t2, 4($t1) 
	blt $a0, $t2, uf3
	lw $t4, 4($t1)
	lw $t3, 4($t0)
	sw $a0, 4($t1)
	lw $t7, 4($t0)
	sw $s3, 4($t0)
	beq $s3, $t7, uf_done
	la $t1, 4($t1)
	la $t0, 4($t0)
	li $t9, 2
	j uf_push_loop
uf3:
	lw $t2, 8($t1) 
	blt $a0, $t2, uf4
	lw $t4, 8($t1)
	lw $t3, 8($t0)
	sw $a0, 8($t1)
	lw $t7, 8($t0)
	sw $s3, 8($t0)
	beq $s3, $t7, uf_done
	la $t1, 8($t1)
	la $t0, 8($t0)
	li $t9, 1
	j uf_push_loop
uf4:
	lw $t2, 12($t1) 
	blt $a0, $t2, uf5
	lw $t4, 12($t1)
	lw $t3, 12($t0)
	sw $a0, 12($t1)
	lw $t7, 12($t0)
	sw $s3, 12($t0)
	beq $s3, $t7, uf_done
	la $t1, 12($t1)
	la $t0, 12($t0)
	li $t9, 0
	j uf_push_loop
uf5:
	sw $a0, 16($t1)
	sw $s3, 16($t0)	
uf_done:
	jr $ra
uf_push_loop:	
	addi $t1, 4
	addi $t0, 4	
	lw $t6, 0($t1)
	lw $t5, 0($t0)
	sw $t4, 0($t1)
	lw $t7, 0($t0)
	beq $t3, $t7, uf_done
	sw $t3, 0($t0)
	move $t4, $t6
	move $t3, $t5	
	addi $t9, $t9, -1	
	bgt $t9, $0, uf_push_loop	
	j uf_done
 
# Go back -- returns to current channel after 10 seconds ------------------ #
go_back:
	sw $s3, 12($sp)		# store current channel in stack
	addi $t0, $s1, 10	# add 10 sec to current time
	sw $t0, 8($sp)		# store time + 10 in stack
	la $a0, msg_go_back
	li $v0, 4
	syscall
	move $a0, $s3
	li $v0, 1
	syscall
	la $a0, msg_in
	li $v0, 4
	syscall
	move $a0, $t0
	li $v0, 1
	syscall
	la $a0, msg_sec
	li $v0, 4
	syscall
	la $a0, newline
	syscall
	j process_input_done		
go_back_chan:			# executes when counter hits zero
	lw $t0, 12($sp)
	move $s3, $t0
	la $a0, msg_returning	
	li $v0, 4
	syscall
	move $a0, $t0
	li $v0, 1
	syscall
	la $a0, newline
	li $v0, 4
	syscall
	jr $ra
