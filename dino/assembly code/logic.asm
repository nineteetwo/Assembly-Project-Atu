# =================================================================
# MODULE: LOGIC & PHYSICS
# DESCRIPTION: Handles Input, Physics, Game State, and Collision.
# UPDATES: Ducking, Pterodactyl, Pause toggle
# =================================================================

# -----------------------------------------------------------------
# Procedure: Update_Game_Logic
# Purpose:   Master function that runs all logic for one frame.
# -----------------------------------------------------------------
Update_Game_Logic:
    addi  $sp, $sp, -4
    sw    $ra, 0($sp)

    # --- 1. Input Handling ---
    li    $t0, MMIO_KEY_CTRL
    lw    $t1, 0($t0)
    andi  $t1, $t1, 1
    beqz  $t1, Logic_PhysicsStep

    li    $t0, MMIO_KEY_DATA
    lw    $t1, 0($t0)

    # Check 's' to START
    beq   $t1, 115, Input_StartGame   # 's'

    # Check 'p' to PAUSE/UNPAUSE
    li    $t2, 112                     # 'p'
    beq   $t1, $t2, Input_TogglePause

    # Check Down-Arrow (ASCII 40 in MMIO) or 's' when already playing for duck
    # MARS MMIO sends 10 for down arrow in some configs; use 40 (down) or 's'=115
    # We'll use 40 (ASCII for '(') as down — actually MARS sends raw key code
    # Standard approach: check for character codes. Down arrow = not easily detected.
    # Use 'x' (ASCII 120) as duck key instead (accessible, different from space/s/p)
    li    $t2, 120                     # 'x' = duck
    beq   $t1, $t2, Input_Duck

    # Check Spacebar to jump
    bne   $t1, 32, Logic_PhysicsStep  # 32 = Space
    j     Input_CheckJump

Input_StartGame:
    lw    $t2, state_game_active
    bnez  $t2, Logic_PhysicsStep

    li    $t2, 1
    sw    $t2, state_game_active

    li    $a0, STOPLAY_X
    li    $a2, STOPLAY_Y
    jal   Gfx_EraseStoplay
    b     Logic_PhysicsStep

Input_TogglePause:
    # Only toggle if game is active
    lw    $t2, state_game_active
    beqz  $t2, Logic_PhysicsStep

    lw    $t2, state_is_paused
    xori  $t2, $t2, 1
    sw    $t2, state_is_paused

    # Print pause status to console
    li    $v0, 4
    la    $a0, str_paused
    syscall

    b     Logic_PhysicsStep

Input_Duck:
    # Can only duck when on ground and not jumping
    bnez  $s3, Logic_PhysicsStep      # Ignore if jumping
    lw    $t2, state_game_active
    beqz  $t2, Logic_PhysicsStep

    # Toggle duck state
    lw    $t2, state_is_duck
    xori  $t2, $t2, 1
    sw    $t2, state_is_duck
    b     Logic_PhysicsStep

Input_CheckJump:
    # Cannot jump if ducking or already jumping
    lw    $t2, state_is_duck
    bnez  $t2, Logic_PhysicsStep      # Can't jump while ducking
    bnez  $s3, Logic_PhysicsStep      # Already jumping

    lw    $t2, state_game_active
    beqz  $t2, Logic_PhysicsStep

    jal   Play_Sound_Jump
    li    $s3, 1
    move  $s4, $s7

Logic_PhysicsStep:
    # --- 2. Dino Physics ---
    # If ducking, stay on ground (no jump physics)
    lw    $t0, state_is_duck
    bnez  $t0, Logic_DinoOnGround

    beqz  $s3, Logic_DinoOnGround

    sub   $t0, $s7, $s4
    lw    $t1, cfg_jump_duration
    lw    $t2, cfg_jump_height

    bge   $t0, $t1, Logic_DinoLand

    sub   $t3, $t1, $t0
    mul   $t4, $t0, $t3
    sll   $t5, $t2, 2
    mul   $t6, $t5, $t4
    mul   $t7, $t1, $t1
    div   $t6, $t7
    mflo  $t8

    li    $t9, POS_GROUND_Y
    sub   $t9, $t9, $t8
    sw    $t9, state_dino_y_next
    j     Logic_ObstacleStep

Logic_DinoLand:
    li    $s3, 0
    # Check duck state: land at duck Y or ground Y
    lw    $t5, state_is_duck
    bnez  $t5, LD_SetDuckY
    li    $t5, POS_GROUND_Y
    sw    $t5, state_dino_y_next
    j     Logic_ObstacleStep
LD_SetDuckY:
    li    $t5, POS_DUCK_Y
    sw    $t5, state_dino_y_next
    j     Logic_ObstacleStep

Logic_DinoOnGround:
    # Set Y based on whether we are ducking
    lw    $t5, state_is_duck
    bnez  $t5, DOG_DuckY
    li    $t5, POS_GROUND_Y
    sw    $t5, state_dino_y_next
    j     Logic_ObstacleStep
DOG_DuckY:
    li    $t5, POS_DUCK_Y
    sw    $t5, state_dino_y_next

Logic_ObstacleStep:
    # --- 3. Ground Obstacle Logic ---
    lw    $t0, state_game_active
    beqz  $t0, Logic_ObstacleIdle

    lw    $t0, state_obst_active
    bnez  $t0, Logic_MoveObstacle

    lw    $t1, state_last_spawn
    sub   $t2, $s7, $t1
    lw    $t3, state_next_delay
    blt   $t2, $t3, Logic_ObstacleIdle

    li    $t0, 1
    sw    $t0, state_obst_active
    li    $t0, 256
    sw    $t0, state_obst_x_next
    j     Logic_PteroStep

Logic_ObstacleIdle:
    li    $t0, 256
    sw    $t0, state_obst_x_next
    j     Logic_PteroStep

Logic_MoveObstacle:
    lw    $t2, state_obst_x_curr
    lw    $t1, cfg_speed_curr
    sub   $t2, $t2, $t1

    li    $t3, -32
    bge   $t2, $t3, Logic_FinalizeObstacle

    # Reset
    li    $t0, 0
    sw    $t0, state_obst_active
    li    $t2, 256

    sw    $t1, -4($sp)
    jal   Gfx_CleanLeftBoundary
    lw    $t1, -4($sp)

    sw    $t2, state_obst_x_curr
    sw    $s7, state_last_spawn

    # Random sprite selection
    li    $v0, 42
    li    $a0, 0
    li    $a1, 2
    syscall

    beqz   $a0, Select_Sprite_1
    la     $t0, sprite_obstacle_2
    j      Store_Sprite_Selection

Select_Sprite_1:
    la     $t0, sprite_obstacle

Store_Sprite_Selection:
    sw     $t0, state_obst_sprite_addr

    # Next spawn delay
    lw     $a1, cfg_spawn_rng_ms
    li     $v0, 42
    syscall
    lw     $t0, cfg_spawn_min_ms
    add    $a0, $a0, $t0
    sw     $a0, state_next_delay

Logic_FinalizeObstacle:
    sw     $t2, state_obst_x_next

# -----------------------------------------------------------------
# Pterodactyl (Flying Enemy) Logic
# -----------------------------------------------------------------
Logic_PteroStep:
    lw    $t0, state_game_active
    beqz  $t0, Logic_PteroIdle

    lw    $t0, state_ptero_active
    bnez  $t0, Logic_MovePtero

    # Check spawn time
    lw    $t1, state_ptero_last_spawn
    sub   $t2, $s7, $t1
    lw    $t3, state_ptero_next_delay
    blt   $t2, $t3, Logic_PteroIdle

    li    $t0, 1
    sw    $t0, state_ptero_active
    li    $t0, 256
    sw    $t0, state_ptero_x_next
    j     Logic_Collisions

Logic_PteroIdle:
    li    $t0, 256
    sw    $t0, state_ptero_x_next
    j     Logic_Collisions

Logic_MovePtero:
    lw    $t2, state_ptero_x_curr
    lw    $t1, cfg_speed_curr
    sub   $t2, $t2, $t1

    li    $t3, -32
    bge   $t2, $t3, Logic_FinalizePtero

    # Reset pterodactyl
    li    $t0, 0
    sw    $t0, state_ptero_active
    li    $t2, 256

    # Clean left boundary at ptero height
    addi  $sp, $sp, -4
    sw    $t1, 0($sp)
    jal   Gfx_CleanPteroLeftBoundary
    lw    $t1, 0($sp)
    addi  $sp, $sp, 4

    sw    $t2, state_ptero_x_curr
    sw    $s7, state_ptero_last_spawn

    # Next ptero spawn delay: 3000-6000ms
    li    $v0, 42
    li    $a0, 0
    li    $a1, 3000
    syscall
    addi  $a0, $a0, 3000
    sw    $a0, state_ptero_next_delay

Logic_FinalizePtero:
    sw    $t2, state_ptero_x_next

Logic_Collisions:
    # --- 4. Collision Detection ---
    lw     $t0, state_game_active
    beqz   $t0, Logic_Return

    # --- Ground Obstacle Collision ---
    lw     $t0, state_obst_x_curr
    lw     $t1, state_dino_y_curr

    # X range: obstacle overlapping dino (x in 5..28)
    ble    $t0, 5,  Logic_CheckPteroCollision
    bge    $t0, 28, Logic_CheckPteroCollision

    # If ducking, dino hitbox is lower (rows 104..116), obstacle at y=97..116
    lw     $t2, state_is_duck
    bnez   $t2, Logic_GroundCollision_Duck

    # Standing: Y range 86..116 = collision
    ble    $t1, 86, Logic_CheckPteroCollision
    j      Game_Over

Logic_GroundCollision_Duck:
    # Ducking: ground obstacle still hits dino at duck height
    # duck dino occupies rows 104..116, obstacle occupies 97..116
    # they overlap -> always collision if X matches
    j      Game_Over

Logic_CheckPteroCollision:
    # --- Flying Enemy Collision ---
    lw     $t0, state_ptero_active
    beqz   $t0, Logic_Return

    lw     $t0, state_ptero_x_curr
    ble    $t0, 5,  Logic_Return
    bge    $t0, 28, Logic_Return

    # Ptero at Y=78..94, dino standing at Y=66..91
    # If jumping high (dino_y <= 78) OR standing/ducking at ground -> check
    lw     $t1, state_dino_y_curr

    # If ducking (dino at y=104..116), ptero is at y=78 -> no collision
    lw     $t2, state_is_duck
    bnez   $t2, Logic_Return        # Duck under ptero -> safe!

    # If jumping high enough (dino_y < 78) -> above ptero -> safe
    li     $t3, 78
    blt    $t1, $t3, Logic_Return   # Jumped over ptero -> safe

    # On ground (y=91) and ptero at y=78 -> COLLISION
    j      Game_Over

Logic_Return:
    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

# =================================================================
# GAME OVER ROUTINE (Terminal State)
# =================================================================
Game_Over:
    # Update High Score before showing game over
    lw    $t0, score
    li    $t1, 100
    div   $t0, $t1
    mflo  $t0                    # real score
    lw    $t1, high_score
    ble   $t0, $t1, GO_NoNewHS
    sw    $t0, high_score
    jal   Save_HighScore

GO_NoNewHS:
    # 1. Draw final obstacle
    lw     $a0, state_obst_x_curr
    li     $t0, OBST_WIDTH
    li     $t1, 0
    li     $t2, SCREEN_WIDTH

    bltz   $a0, GO_Clip_Left
    addi   $t3, $a0, OBST_WIDTH
    bgt    $t3, SCREEN_WIDTH, GO_Clip_Right
    j      GO_Store_Params

GO_Clip_Left:
    sub    $t1, $zero, $a0
    addi   $t0, $a0, OBST_WIDTH
    li     $a0, 0
    j      GO_Store_Params

GO_Clip_Right:
    sub    $t0, $t2, $a0

GO_Store_Params:
    li     $t4, MMIO_VIDEO_BASE
    li     $t5, POS_OBSTACLE_Y
    mul    $t5, $t5, SCREEN_WIDTH
    add    $t5, $t5, $a0
    sll    $t5, $t5, 2
    add    $t4, $t4, $t5
    sw     $t4, buf_render_addr

    lw     $t5, state_obst_sprite_addr
    mul    $t6, $t1, 4
    add    $t5, $t5, $t6
    sw     $t5, buf_sprite_addr
    sw     $t0, buf_render_width

    jal    Gfx_DrawObstacle

    # 2. Draw final dino
    li     $a0, POS_DINO_X
    lw     $a2, state_dino_y_curr

    li     $t0, POS_GROUND_Y
    beq    $a2, $t0, GO_DrawRun
    la     $a1, sprite_dino_jump
    j      GO_ExecuteDraw

GO_DrawRun:
    la     $a1, sprite_dino_run_1

GO_ExecuteDraw:
    jal    Gfx_DrawDino

    # 3. Play Crash Sound
    jal    Play_Sound_Crash

    # 4. Draw "Game Over" Sprite
    li     $a0, 93
    li     $a2, 44
    jal    Gfx_DrawGameOver

    # 5. Draw score
    jal    Show_OnScreen_Score

    # 6. Draw "Press S to Start"
    li     $a0, STOPLAY_X
    li     $a2, STOPLAY_Y
    jal    Gfx_Drawstoplay

    # 7. Console output
    li     $v0, 4
    la     $a0, msg_final_score
    syscall

    lw     $t0, score
    li     $t1, 100
    div    $t0, $t1
    mflo   $a0
    li     $v0, 1
    syscall

    li     $v0, 4
    la     $a0, msg_highscore
    syscall

    lw     $a0, high_score
    li     $v0, 1
    syscall

    # 8. Wait for 'S' to restart
Freeze:
    li    $t0, 0xFFFF0000

freeze_wait:
    lw    $t1, 0($t0)
    beq   $t1, $zero, freeze_wait

    lw    $t2, 4($t0)
    li    $t3, 's'
    beq   $t2, $t3, main         # Restart

    j     freeze_wait
