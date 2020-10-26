########################################################################
# COMP1521 20T2 --- assignment 1: a cellular automaton renderer
#
# Written by Nina Chen (z5209365), July 2020.


# Maximum and minimum values for the 3 parameters.

MIN_WORLD_SIZE	=    1
MAX_WORLD_SIZE	=  128
MIN_GENERATIONS	= -256
MAX_GENERATIONS	=  256
MIN_RULE	=    0
MAX_RULE	=  255

# Characters used to print alive/dead cells.

ALIVE_CHAR	= '#'
DEAD_CHAR	= '.'

# Maximum number of bytes needs to store all generations of cells.

MAX_CELLS_BYTES	= (MAX_GENERATIONS + 1) * MAX_WORLD_SIZE

	.data

# `cells' is used to store successive generations.  Each byte will be 1
# if the cell is alive in that generation, and 0 otherwise.

# each cell is one byte... space n bytes
cells:	.space MAX_CELLS_BYTES


# Some strings you'll need to use:

prompt_world_size:	.asciiz "Enter world size: "
error_world_size:	.asciiz "Invalid world size\n"
prompt_rule:		.asciiz "Enter rule: "
error_rule:		.asciiz "Invalid rule\n"
prompt_n_generations:	.asciiz "Enter how many generations: "
error_n_generations:	.asciiz "Invalid number of generations\n"

	.text

	#	REGISTERS USED IN MAIN
	#	
	#	$s0 world size
	#	$s1 rule
	#	$s2 n_generations
	#	$s3 g
	#	$s4 original return address
	#	$s5 reverse
	#
	#	$t0 temporary world size
	#	$t1 temporary number generations
	#	$t2 temporary rule
	#	$t4, $t5 used for calculations
	#
	#	$a0-$a2 arguments used for syscall and function calls
	#	$v0 function returns for syscall
	#
	#	$ra return address reverted after function calling

	#	REGISTERS WITHOUT ORIGINAL VALUE (FROM BEFORE MAIN CALL IS RUN)
	#	$s0-$s5
	#	$t0=$t7 (used in functions as well)
	#	$a0-$a2
	#	$v0

	#	THE ONLY REGISTERS WITH ORIGINAL VALUE (FROM BEFORE MAIN CALL IS RUN)
	#	$ra, $fp, $sp
	# 	all unused variables e.g. $s6-$s7, $a3, $v1

main:
	move $s4 $ra					# save return address


	la $a0, prompt_world_size		# printf("Enter world size: ");
	li $v0, 4
	syscall

	li $v0, 5						# scanf("%d", &world_size);
	syscall

	move $t0, $v0

	blt $t0, MIN_WORLD_SIZE, invalid_world_error
	bgt $t0, MAX_WORLD_SIZE, invalid_world_error


	la $a0, prompt_rule				# printf("Enter rule: ");
	li $v0, 4
	syscall

	li $v0, 5						# scanf("%d", &rule);
	syscall

	move $t1, $v0		

	blt $t1, MIN_RULE, invalid_rule_error
	bgt $t1, MAX_RULE, invalid_rule_error


	la $a0, prompt_n_generations	# printf("Enter how many generations: ");
	li $v0, 4						
	syscall

	li $v0, 5						# scanf("%d", &n_generations);
	syscall

	move $t2, $v0	

	blt $t2, MIN_GENERATIONS, invalid_generations_error
	bgt $t2, MAX_GENERATIONS, invalid_generations_error


    li   $a0, '\n'					# putchar('\n');
    li   $v0, 11
    syscall


	li $s5, 0						# reverse = 0
	bltz $t2, update_reverse		# if (n_generations < 0) goto update_reverse


generations_section:
	li $t4, 1
	div $t5, $t0, 2					# world size / 2 
	sb $t4 cells($t5)				# cells[0][world_size / 2] = 1;
	
	move $s0, $t0					# $s0 = world size
	move $s1, $t1					# $s1 = rule
	move $s2, $t2					# $s2 = n_gens
	li $s3, 1						# g = 1

loop1:
	bgt $s3, $s2, end1

	move $a0, $s0					# int world_size
	move $a1, $s3					# int which_generation
	move $a2, $s1					# int rule 

	jal run_generation				# run_generation(world_size, g, rule);
	
	add $s3, $s3, 1
	b loop1
end1:

	beq $s5, 1, reverse_print		# if reverse, reverse_print
	beq $s5, 0, normal_print		# if not reverse, normal_print
reverse_print:			
	move $s3, $s2					# int g = n_generations
loop2:
	bltz $s3, end2

	move $a0, $s0					# int world_size
	move $a1, $s3					# int which_generation
	jal print_generation			# print_generation(world_size, g)

	sub $s3, $s3, 1					# g--
	b loop2
normal_print:
	li $s3, 0						# int g = 0
loop3:
	bgt $s3, $s2, end2

	move $a0, $s0					# int world_size
	move $a1, $s3					# int which_generation
	jal print_generation			# print_generation(world_size, g)

	add $s3, $s3, 1					# g++
	b loop3
end2:

	move $ra $s4					# restore return address
	j end


	#
	# Given `world_size', `which_generation', and `rule', calculate
	# a new generation according to `rule' and store it in `cells'.
	#
	#	REGISTERS USED IN run_generation
	#	$a0 world size
	#	$a1 which_generation
	#	$a2 rule
	#
	#	$t0 counter x
	#	$t5 index for cells
	#	$t1-$t4 and $t6-$t7 used for calculations
	#
	#	$fp changed to create of stack frame 
	#	$sp changed with $fp to create stack frame
	#	$ra changed to call back to return address in main function

	#	REGISTERS WITHOUT ORIGINAL VALUE
	#	$t0-$t7

run_generation:
	sw $fp, -4($sp)					# function prologue
	sw $ra, -8($sp)
	la $fp, -4($sp)
	add $sp, $sp, -8


	li $t0, 0						# int x = 0
loop_run_generation:	
	bge $t0, $a0, end_loop_run_generation

	sub $t2, $a1, 1					# which_generation - 1
	mul $t3, $a0, $t2 				# offset = world_size * (which_generation - 1)

									# CALCULATIONS FOR LEFT
	li $t1, 0						# int left = 0

	blez $t0, end_if_left			# if (x > 0) goto end_if_left

	sub $t4, $t0, 1					# x - 1
	add $t5, $t3, $t4				# index = offset + x - 1
	lb $t1, cells($t5)				# left = cells[index]
end_if_left:

									# CALCULATIONS FOR CENTRE
	add $t5, $t3, $t0				# index = offset + x
	lb $t6, cells($t5) 				# centre = cells[index]

									# CALCULATIONS FOR RIGHT
	li $t7, 0						# int right = 0

	sub $t2, $a0, 1
	bge $t0, $t2, end_if_right		# if (x < world_size - 1) goto end_if_right

	add $t5, $t5, 1					# index = offset + x + 1
	lb $t7, cells($t5)				# right = cells[index]
end_if_right:

									# CALCULATIONS FOR STATE
	sll $t1, $t1, 2					# left <<= 2
	sll $t6, $t6, 1					# centre <<= 1

	or $t1, $t1, $t6				# state = left | centre
	or $t1, $t1, $t7				# state = left | centre | right

	li $t4, 1
	sllv $t2, $t4, $t1				# int bit = 1 << state
	and $t3, $a2, $t2				# int set = rule & bit

	mul $t5, $a0, $a1 				# offset = world_size * which_generation
	add $t5, $t5, $t0				# index = offset + x

	beqz $t3, else_set				# if (set == 0) goto else_set

	sb $t4, cells($t5)				# cells[which_generation][x] = 1

	b end_if_set
else_set:
	li $t4, 0
	sb $t4, cells($t5)				# cells[which_generation][x] = 0
end_if_set:

	add $t0, $t0, 1
	b loop_run_generation			# loop

end_loop_run_generation:
	lw $ra, -4($fp)					# function epilogue
	la $sp, 4($fp)
	lw $fp, ($fp)					

	jr	$ra	


	#
	# Given `world_size', and `which_generation', print out the
	# specified generation.
	#
	#
	#	REGISTERS USED IN print_generation
	#	$a0 world_size entering argument, also used for syscall
	#	$a1 which_generation entering argument
	#	$v0 function returns for syscall
	#
	#	$t0 world_size
	#	$t1 which_generation
	#	$t2 counter x
	#	$t3 cells[which_generation][x]
	#	$t5	index for cells
	#
	#	$fp changed to create of stack frame 
	#	$sp changed with $fp to create stack frame
	#	$ra changed to call back to return address in main function

	#	REGISTERS WITHOUT ORIGINAL VALUE
	#	$a0
	#	$v0
	#	$t0-$t3 & $t5

print_generation:
	sw $fp, -4($sp)					# function prologue
	sw $ra, -8($sp)
	la $fp, -4($sp)
	add $sp, $sp, -8

	move $t0, $a0					# world_size
	move $t1, $a1					# which_generation

	move $a0, $t1
	li $v0, 1
	syscall							# printf("%d", which_generation);

    li   $a0, '\t'
    li   $v0, 11
    syscall							# putchar('\t');


	li $t2, 0						# int x = 0
loop_print:
	bge $t2, $t0, loop_print_end

	mul $t5, $t0, $t1 				# offset = world_size * which_generation
	add $t5, $t5, $t2				# index = offset + x

	lb $t3, cells($t5)				# cells[index]


	beqz $t3, else_cells			# if (cells[index] == 0) goto else_cells
    li   $a0, ALIVE_CHAR
    li   $v0, 11
    syscall							# putchar(ALIVE_CHAR);

	b end_if_cells
else_cells:
    li   $a0, DEAD_CHAR
    li   $v0, 11
    syscall							# putchar(DEAD_CHAR);
end_if_cells:


	add $t2, $t2, 1					# x++
	b loop_print
loop_print_end:

    li   $a0, '\n'
    li   $v0, 11
    syscall							# putchar('\n');

	
	lw $ra, -4($fp)					# function epilogue
	la $sp, 4($fp)
	lw $fp, ($fp)

	jr	$ra


invalid_world_error:
	la $a0, error_world_size
	li $v0, 4
	syscall							# printf("Invalid world size\n");

	j error_end

invalid_rule_error:
	la $a0, error_rule
	li $v0, 4
	syscall							# printf("Invalid rule\n");

	j error_end

invalid_generations_error:
	la $a0, error_n_generations
	li $v0, 4
	syscall							# printf("Invalid number of generations\n");

	j error_end

update_reverse:
	li $s5, 1						# reverse = 1
	mul $t2, $t2, -1				# n_genenerations -= 1

	j generations_section

end:
	li	$v0, 0
	jr	$ra

error_end:
	li	$v0, 1
	jr	$ra	