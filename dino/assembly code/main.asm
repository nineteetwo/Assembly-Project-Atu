# =================================================================
# PROJECT: DINO RUN (MIPS ASSEMBLY)
# FILE: main.asm (Entry Point)
# GitHub: https://github.com/abdelrhman1040/Assembly-Dino.git
# UPDATES: Ducking, Flying Enemies, High Score (File I/O), Pause
# =================================================================

.data

# -----------------------------------------------------------------
# 1. INCLUDE SPRITES
# -----------------------------------------------------------------
.include "sprites.asm"

# -----------------------------------------------------------------
# 2. CONSTANTS (.eqv)
# -----------------------------------------------------------------
.eqv COLOR_SKY          0x87CEEB    # Sky Blue
.eqv COLOR_HORIZON      0x006400    # Dark Green
.eqv COLOR_GROUND       0x32CD32    # Light Green
.eqv COLOR_TRANSPARENT  0x00FFFFFF  # Transparency Key (White)
.eqv COLOR_RED          0xFF0000    # Game Over Color

.eqv SCREEN_WIDTH       256
.eqv SCREEN_HEIGHT      128
.eqv SPRITE_WIDTH       24
.eqv SPRITE_HEIGHT      25
.eqv SPRITE_DUCK_HEIGHT 13          # Duck sprite height (shorter)
.eqv OBST_WIDTH         32
.eqv OBST_HEIGHT        19

# Flying enemy (Pterodactyl) dimensions — same sprite size as obstacle
.eqv PTERO_WIDTH        32
.eqv PTERO_HEIGHT       16
.eqv PTERO_Y            78          # Y position of flying enemy (mid-air)

# Memory Mapped I/O
.eqv MMIO_VIDEO_BASE    0x10040000
.eqv MMIO_KEY_CTRL      0xffff0000
.eqv MMIO_KEY_DATA      0xffff0004

# Entity Fixed Positions
.eqv POS_DINO_X         5
.eqv POS_GROUND_Y       91
.eqv POS_OBSTACLE_Y     97
.eqv POS_DUCK_Y         104         # Dino Y when ducking (lower on ground)

# Logo & Sun Dimensions
.eqv STOPLAY_WIDTH      69
.eqv STOPLAY_HEIGHT     5
.eqv STOPLAY_X          93
.eqv STOPLAY_Y          80

.eqv GAMEOVER_WIDTH     69
.eqv GAMEOVER_HEIGHT    40

# Sun Dimensions
.eqv SUN_WIDTH          32
.eqv SUN_HEIGHT         31

# -----------------------------------------------------------------
# 3. GLOBAL VARIABLES
# -----------------------------------------------------------------

# Strings
str_debug_fps:     .asciiz " FPS: "
str_newline:       .asciiz "\n"
msg_final_score:   .asciiz "\nGame Over! Final Score: "
msg_highscore:     .asciiz "  |  High Score: "
highscore_file:    .asciiz "highscore.dat"
str_paused:        .asciiz "\n[PAUSED] Press P to resume\n"

# Configuration: Physics & Difficulty
cfg_jump_duration: .word 700
cfg_jump_height:   .word 45

# Speed Control
cfg_speed_curr:    .word 2
cfg_speed_max:     .word 15
cfg_speed_next_ts: .word 0
cfg_speed_inc_int: .word 5000

# Spawn Control
cfg_spawn_min_ms:  .word 1000
cfg_spawn_rng_ms:  .word 1500

# Animation Control
cfg_anim_base_del: .word 250
cfg_anim_speed_fac:.word 15

# Game State Variables
state_dino_y_curr: .word 97
state_dino_y_next: .word 97
state_obst_x_curr: .word 256
state_obst_x_next: .word 256
state_obst_active: .word 0
state_last_spawn:  .word 0
state_next_delay:  .word 0
state_obst_sprite_addr: .word sprite_obstacle

state_game_active: .word 0         # 0=Menu, 1=Playing
state_is_paused:   .word 0         # 0=Not paused, 1=Paused
state_is_duck:     .word 0         # 0=Standing, 1=Ducking

score:             .word 0
high_score:        .word 0

# Flying Enemy State
state_ptero_active: .word 0        # 0=Inactive, 1=Active
state_ptero_x_curr: .word 256
state_ptero_x_next: .word 256
state_ptero_last_spawn: .word 0
state_ptero_next_delay: .word 0
state_ptero_sprite_addr: .word sprite_pterodactyl

# System State
sys_frame_count:   .word 0
sys_fps_timer:     .word 0
sys_time_curr:     .word 0
sys_time_prev:     .word 0

# Rendering Buffers (Shared with graphics.asm)
buf_render_addr:   .word 0
buf_sprite_addr:   .word 0
buf_render_width:  .word 0

# High score file buffer
hs_buf:            .space 16       # buffer for reading/writing score string

# =================================================================
# TEXT SECTION (MAIN LOGIC)
# =================================================================
.text
.globl main

# =================================================================
# MAIN ENTRY POINT
# =================================================================
main:
    # Load High Score from file first
    jal   Load_HighScore

    # 1. Initialize Static Graphics
    jal Init_StaticBackground

    # 2. Draw "STOPLAY" Logo initially
    li    $a0, STOPLAY_X
    li    $a2, STOPLAY_Y
    jal   Gfx_Drawstoplay

    # 3. Initialize Game State
    sw    $zero, state_game_active
    sw    $zero, state_is_paused
    sw    $zero, state_is_duck
    sw    $zero, state_ptero_active

    # 4. Initialize System Timers
    li    $v0, 30
    syscall
    move $s6, $a0
    sw    $a0, state_last_spawn
    sw    $a0, state_ptero_last_spawn
    sw    $a0, sys_fps_timer
    sw    $zero, sys_frame_count

    # 5. Initialize Difficulty
    lw    $t0, cfg_speed_inc_int
    add   $t0, $t0, $s6
    sw    $t0, cfg_speed_next_ts

    # 6. Initialize First Spawn Delays
    lw    $a1, cfg_spawn_rng_ms
    li    $v0, 42
    syscall
    lw    $t0, cfg_spawn_min_ms
    add   $a0, $a0, $t0
    sw    $a0, state_next_delay

    # Pterodactyl first spawn delay (longer, 3000-6000ms)
    li    $a1, 3000
    li    $v0, 42
    syscall
    addi  $a0, $a0, 3000
    sw    $a0, state_ptero_next_delay

    # 7. Initialize Registers & Positions
    li    $s2, 0
    li    $s3, 0                   # Jump Flag
    li    $s4, 0                   # Jump Start Time
    li    $s5, 0                   # Dead Flag

    li    $t0, POS_GROUND_Y
    sw    $t0, state_dino_y_curr
    sw    $t0, state_dino_y_next
    li    $t0, 256
    sw    $t0, state_obst_x_curr
    sw    $t0, state_obst_x_next
    li    $t0, 256
    sw    $t0, state_ptero_x_curr
    sw    $t0, state_ptero_x_next
    sw    $zero, score
    li    $t0, 2
    sw    $t0, cfg_speed_curr

    j     Game_Loop

# =================================================================
# MAIN GAME LOOP
# =================================================================
Game_Loop:

    # --- 1. Delta Time Calculation ---
    li    $v0, 30
    syscall
    move $s7, $a0
    sub   $t9, $s7, $s6
    move $s6, $s7

    # --- 2. Check Pause State ---
    lw    $t8, state_is_paused
    bnez  $t8, Game_Loop_PausedCheck

    # --- 3. Update Score & Difficulty (only when playing & not paused) ---
    lw    $t8, state_game_active
    beqz $t8, Skip_Score_And_Diff

    # Score Update
    lw    $t0, score
    lw    $t1, cfg_speed_curr
    add   $t0, $t0, $t1
    sw    $t0, score

    # Difficulty Progression
    lw    $t0, cfg_speed_next_ts
    blt   $s7, $t0, Skip_Score_And_Diff

    lw    $t1, cfg_speed_inc_int
    add   $t0, $s7, $t1
    sw    $t0, cfg_speed_next_ts

    lw    $t2, cfg_speed_curr
    lw    $t3, cfg_speed_max
    bge   $t2, $t3, Skip_Score_And_Diff

    addi $t2, $t2, 1
    sw   $t2, cfg_speed_curr

Skip_Score_And_Diff:

    # --- 4. FPS Debug ---
    lw    $t0, sys_frame_count
    addi $t0, $t0, 1
    sw    $t0, sys_frame_count

    lw    $t1, sys_fps_timer
    sub   $t2, $s7, $t1
    blt   $t2, 1000, System_SkipFPSPrint

    li    $v0, 4
    la    $a0, str_debug_fps
    syscall
    li    $v0, 1
    lw    $a0, sys_frame_count
    syscall
    li    $v0, 4
    la    $a0, str_newline
    syscall

    sw    $zero, sys_frame_count
    sw    $s7, sys_fps_timer

System_SkipFPSPrint:

    # =============================================================
    # LOGIC UPDATE
    # =============================================================
    jal   Update_Game_Logic

    # =============================================================
    # RENDER PREPARATION (Ground Obstacle Clipping)
    # =============================================================
    lw    $a0, state_obst_x_next
    li    $t0, OBST_WIDTH
    li    $t1, 0
    li    $t2, SCREEN_WIDTH

    bltz $a0, Clip_Left
    addi $t3, $a0, OBST_WIDTH
    bgt   $t3, SCREEN_WIDTH, Clip_Right
    j     Store_RenderParams

Clip_Left:
    sub   $t1, $zero, $a0
    addi $t0, $a0, OBST_WIDTH
    li    $a0, 0
    j     Store_RenderParams

Clip_Right:
    sub   $t0, $t2, $a0

Store_RenderParams:
    li    $t4, MMIO_VIDEO_BASE
    li    $t5, POS_OBSTACLE_Y
    mul   $t5, $t5, SCREEN_WIDTH
    add   $t5, $t5, $a0
    sll   $t5, $t5, 2
    add   $t4, $t4, $t5
    sw    $t4, buf_render_addr

    lw    $t5, state_obst_sprite_addr
    mul   $t6, $t1, 4
    add   $t5, $t5, $t6
    sw    $t5, buf_sprite_addr

    sw    $t0, buf_render_width

    # =============================================================
    # DRAWING PHASE
    # =============================================================

    # 1. Erase & Draw Ground Obstacle
    lw    $a0, state_obst_x_curr
    jal   Gfx_EraseObstacle

    jal   Gfx_DrawObstacle

    # 2. Erase & Draw Pterodactyl
    lw    $a0, state_ptero_x_curr
    lw    $t0, state_ptero_active
    beqz  $t0, Skip_Ptero_Erase
    jal   Gfx_ErasePtero

Skip_Ptero_Erase:
    # Clip and draw pterodactyl
    lw    $a0, state_ptero_x_next
    li    $t0, PTERO_WIDTH
    li    $t1, 0
    li    $t2, SCREEN_WIDTH

    bltz  $a0, PClip_Left
    addi  $t3, $a0, PTERO_WIDTH
    bgt   $t3, SCREEN_WIDTH, PClip_Right
    j     PStore_RenderParams

PClip_Left:
    sub   $t1, $zero, $a0
    addi  $t0, $a0, PTERO_WIDTH
    li    $a0, 0
    j     PStore_RenderParams

PClip_Right:
    sub   $t0, $t2, $a0

PStore_RenderParams:
    li    $t4, MMIO_VIDEO_BASE
    li    $t5, PTERO_Y
    mul   $t5, $t5, SCREEN_WIDTH
    add   $t5, $t5, $a0
    sll   $t5, $t5, 2
    add   $t4, $t4, $t5
    sw    $t4, buf_render_addr

    lw    $t5, state_ptero_sprite_addr
    mul   $t6, $t1, 4
    add   $t5, $t5, $t6
    sw    $t5, buf_sprite_addr
    sw    $t0, buf_render_width

    lw    $t0, state_ptero_active
    beqz  $t0, Skip_Ptero_Draw
    jal   Gfx_DrawPtero

Skip_Ptero_Draw:

    # 3. Erase Old Dino
    # ALWAYS use full-height erase (Gfx_EraseDino) so there are no
    # ghost pixels when transitioning between standing and ducking.
    li    $a0, POS_DINO_X
    lw    $a2, state_dino_y_curr
    jal   Gfx_EraseDino
    # Also erase the duck Y band in case we transitioned from duck
    # to stand this frame (the duck sits lower on screen)
    li    $a0, POS_DINO_X
    li    $a2, POS_DUCK_Y
    jal   Gfx_EraseDinoDuck

Erase_Done:

    # 4. Draw New Dino
    li    $a0, POS_DINO_X
    lw    $a2, state_dino_y_next

    # Check duck state first
    lw    $t0, state_is_duck
    bnez  $t0, Anim_DuckFrame

    # Check if jumping
    lw    $t0, state_dino_y_next
    bne   $t0, POS_GROUND_Y, Anim_JumpFrame

    # Running animation
    lw    $t5, cfg_anim_base_del
    lw    $t6, cfg_speed_curr
    lw    $t7, cfg_anim_speed_fac
    mul   $t8, $t6, $t7
    sub   $t1, $t5, $t8

    li    $t9, 30
    bge   $t1, $t9, Anim_SkipClamp
    move $t1, $t9

Anim_SkipClamp:
    divu $s7, $t1
    mflo $t0
    andi $t0, $t0, 1

    beqz $t0, Anim_RunFrame1
    la    $a1, sprite_dino_run_2
    j     Anim_ExecuteDraw

Anim_RunFrame1:
    la    $a1, sprite_dino_run_1
    j     Anim_ExecuteDraw

Anim_JumpFrame:
    la    $a1, sprite_dino_jump
    j     Anim_ExecuteDraw

Anim_DuckFrame:
    la    $a1, sprite_dino_duck
    # Adjust Y for duck position (dino sits lower)
    li    $a2, POS_DUCK_Y
    jal   Gfx_DrawDinoDuck
    j     Anim_DrawDone

Anim_ExecuteDraw:
    jal   Gfx_DrawDino

Anim_DrawDone:

    # 5. Commit State
    lw    $t0, state_dino_y_next
    sw    $t0, state_dino_y_curr
    lw    $t0, state_obst_x_next
    sw    $t0, state_obst_x_curr
    lw    $t0, state_ptero_x_next
    sw    $t0, state_ptero_x_curr

    # =============================================================
    # FRAME CAP (TARGET 60 FPS)
    # =============================================================
    li    $v0, 30
    syscall
    sub   $t0, $a0, $s7
    li    $t1, 16
    sub   $a0, $t1, $t0
    blez $a0, Loop_End
    li    $v0, 32
    syscall

Loop_End:
    j     Game_Loop

# -----------------------------------------------------------------
# Pause check subroutine (inside game loop when paused)
# -----------------------------------------------------------------
Game_Loop_PausedCheck:
    # Poll input for 'p' to unpause
    li    $t0, MMIO_KEY_CTRL
    lw    $t1, 0($t0)
    andi  $t1, $t1, 1
    beqz  $t1, Game_Loop_StillPaused

    li    $t0, MMIO_KEY_DATA
    lw    $t1, 0($t0)
    li    $t2, 112               # 'p'
    bne   $t1, $t2, Game_Loop_StillPaused

    # Unpause
    sw    $zero, state_is_paused
    # Reset loop timer so delta time doesn't explode
    li    $v0, 30
    syscall
    move  $s6, $a0
    j     Game_Loop

Game_Loop_StillPaused:
    # Sleep briefly to not burn CPU while paused
    li    $v0, 32
    li    $a0, 16
    syscall
    j     Game_Loop

# =================================================================
# SAVE / LOAD HIGH SCORE (File I/O)
# =================================================================

# -----------------------------------------------------------------
# Load_HighScore: Reads "highscore.dat" and sets high_score var
# -----------------------------------------------------------------
Load_HighScore:
    addi  $sp, $sp, -4
    sw    $ra, 0($sp)

    # Open file for reading (syscall 13)
    li    $v0, 13
    la    $a0, highscore_file
    li    $a1, 0               # O_RDONLY
    li    $a2, 0
    syscall
    move  $t0, $v0             # file descriptor

    bltz  $t0, LHS_NoFile     # file doesn't exist

    # Read up to 12 bytes into hs_buf
    li    $v0, 14
    move  $a0, $t0
    la    $a1, hs_buf
    li    $a2, 12
    syscall

    # Close file (syscall 16)
    li    $v0, 16
    move  $a0, $t0
    syscall

    # Parse ASCII integer from hs_buf
    la    $t1, hs_buf
    li    $t2, 0               # accumulator

LHS_ParseLoop:
    lb    $t3, 0($t1)
    beqz  $t3, LHS_ParseDone  # null terminator
    li    $t4, 10
    beq   $t3, $t4, LHS_ParseDone  # newline
    li    $t4, 13
    beq   $t3, $t4, LHS_ParseDone  # carriage return
    li    $t4, '0'
    sub   $t3, $t3, $t4        # digit value
    bltz  $t3, LHS_ParseDone
    li    $t4, 9
    bgt   $t3, $t4, LHS_ParseDone
    li    $t4, 10
    mul   $t2, $t2, $t4
    add   $t2, $t2, $t3
    addi  $t1, $t1, 1
    j     LHS_ParseLoop

LHS_ParseDone:
    sw    $t2, high_score
    j     LHS_Done

LHS_NoFile:
    sw    $zero, high_score

LHS_Done:
    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

# -----------------------------------------------------------------
# Save_HighScore: Converts high_score to ASCII and writes file
# -----------------------------------------------------------------
Save_HighScore:
    addi  $sp, $sp, -4
    sw    $ra, 0($sp)

    # Convert high_score integer to ASCII string in hs_buf
    lw    $t0, high_score
    la    $t1, hs_buf
    addi  $t1, $t1, 11         # point to end of buffer
    sb    $zero, 0($t1)        # null terminator

    # Handle zero case
    bnez  $t0, SHS_ConvertLoop
    li    $t2, '0'
    addi  $t1, $t1, -1
    sb    $t2, 0($t1)
    j     SHS_WriteFile

SHS_ConvertLoop:
    beqz  $t0, SHS_WriteFile
    li    $t3, 10
    div   $t0, $t3
    mfhi  $t2                  # remainder = digit
    mflo  $t0                  # quotient
    addi  $t2, $t2, '0'        # to ASCII
    addi  $t1, $t1, -1
    sb    $t2, 0($t1)
    j     SHS_ConvertLoop

SHS_WriteFile:
    # Count string length
    move  $t2, $t1
    li    $t3, 0
SHS_LenLoop:
    lb    $t4, 0($t2)
    beqz  $t4, SHS_LenDone
    addi  $t2, $t2, 1
    addi  $t3, $t3, 1
    j     SHS_LenLoop
SHS_LenDone:
    # t1 = start of string, t3 = length

    # Open/create file for writing (syscall 13, O_WRONLY|O_CREAT|O_TRUNC = 769)
    li    $v0, 13
    la    $a0, highscore_file
    li    $a1, 1               # O_WRONLY
    li    $a2, 0644
    syscall
    move  $t4, $v0             # fd

    bltz  $t4, SHS_Done

    # Write string
    li    $v0, 15
    move  $a0, $t4
    move  $a1, $t1
    move  $a2, $t3
    syscall

    # Close
    li    $v0, 16
    move  $a0, $t4
    syscall

SHS_Done:
    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

# =================================================================
# INCLUDE MODULES
# =================================================================
.include "graphics.asm"
.include "logic.asm"
.include "sound.asm"
