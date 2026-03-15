;24L-0694 & 24L-0843

org 0x100

BALLOON_SIZE    equ 1100
MAX_BALLOONS    equ 5
MAX_MISSES      equ 5
SPRITE_W        equ 32
SPRITE_H        equ 32
COLOR_BASE      equ 240
GAME_TIME_TICKS equ 2184 ; 2 mins (120 x 18.2)

section .text
start:
    jmp menu_init

menu_init:
    mov ax, 0x0013
    int 0x10
    call menu_install_interrupts
    call menu_clear_screen
    call menu_draw_perspective_grid
    call menu_draw_tech_decoration
    call menu_draw_big_title
    call menu_draw_static_menu_base
    mov byte [menu_redraw_flag], 1
    mov byte [menu_blink_state], 1
    mov byte [menu_exit_flag], 0
	mov byte [menu_start_game_flag], 0  
    call menu_update_brackets_only

menu_loop:
    cmp byte [menu_exit_flag], 1
    je menu_exit_to_dos
    cmp byte [menu_start_game_flag], 1
    je transition_to_game
    cmp byte [menu_redraw_flag], 1
    jne .menu_wait_cpu
    call vsync_wait
    call menu_update_brackets_only
    mov byte [menu_redraw_flag], 0
.menu_wait_cpu:
    hlt
    jmp menu_loop

menu_exit_to_dos:
    call menu_restore_interrupts
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4C00
    int 0x21

transition_to_game:
    call menu_restore_interrupts
    jmp game_init

menu_new_int9:
    push ax
    push ds
    push cs
    pop ds
    in al, 0x60
    test al, 0x80
    jnz .m_ack
    cmp al, 0x48
    je .m_up
    cmp al, 0x50
    je .m_down
    cmp al, 0x1C
    je .m_enter
    cmp al, 0x01
    je .m_esc
    jmp .m_ack
.m_up:
    mov al, [menu_selection_index]
    mov [menu_old_selection], al
    dec byte [menu_selection_index]
    cmp byte [menu_selection_index], 0
    jge .m_done_move
    mov byte [menu_selection_index], 2
    jmp .m_done_move
.m_down:
    mov al, [menu_selection_index]
    mov [menu_old_selection], al
    inc byte [menu_selection_index]
    cmp byte [menu_selection_index], 2
    jle .m_done_move
    mov byte [menu_selection_index], 0
.m_done_move:
    mov byte [menu_blink_state], 1
    mov byte [menu_redraw_flag], 1
    jmp .m_ack
.m_enter:
    cmp byte [menu_selection_index], 1
    je .m_ack
    cmp byte [menu_selection_index], 0
    je .m_start_game
    mov byte [menu_exit_flag], 1
    jmp .m_ack
.m_start_game:
    mov byte [menu_start_game_flag], 1
    jmp .m_ack
.m_esc:
    mov byte [menu_exit_flag], 1
    jmp .m_ack
.m_ack:
    mov al, 0x20
    out 0x20, al
    pop ds
    pop ax
    iret

menu_new_int1c:
    push ax
    push ds
    push cs
    pop ds
    inc byte [menu_blink_timer]
    cmp byte [menu_blink_timer], 8
    jl .m_done_timer
    mov byte [menu_blink_timer], 0
    xor byte [menu_blink_state], 1
    mov byte [menu_redraw_flag], 1
.m_done_timer:
    pop ds
    pop ax
    iret

menu_draw_static_menu_base:
    mov bx, 130
    mov cx, 128
    mov dx, 60
    mov si, 12
    mov al, 0x00
    call menu_draw_rect_color
    mov byte [menu_current_color], 0x0F
    mov bx, 144
    mov cx, 130
    mov si, str_play
    call menu_draw_string
    mov bx, 120
    mov cx, 146
    mov dx, 80
    mov si, 12
    mov al, 0x00
    call menu_draw_rect_color
    mov bx, 132
    mov cx, 148
    mov si, str_options
    call menu_draw_string
    mov bx, 130
    mov cx, 164
    mov dx, 60
    mov si, 12
    mov al, 0x00
    call menu_draw_rect_color
    mov bx, 144
    mov cx, 166
    mov si, str_exit
    call menu_draw_string
    ret

menu_update_brackets_only:
    mov al, [menu_selection_index]
    cmp al, [menu_old_selection]
    je .m_draw_new
    mov byte [menu_current_color], 0x00
    mov al, [menu_old_selection]
    call menu_draw_brackets_at_index
    mov al, [menu_selection_index]
    mov [menu_old_selection], al
.m_draw_new:
    cmp byte [menu_blink_state], 1
    je .m_on
    mov byte [menu_current_color], 0x00
    jmp .m_do
.m_on:
    mov byte [menu_current_color], 0x0E
.m_do:
    mov al, [menu_selection_index]
    call menu_draw_brackets_at_index
    ret

menu_draw_brackets_at_index:
    cmp al, 0
    je .m_sel_play
    cmp al, 1
    je .m_sel_options
    jmp .m_sel_exit
.m_sel_play:
    mov bx, 130
    mov cx, 130
    call .m_render_br
    ret
.m_sel_options:
    mov bx, 118
    mov cx, 148
    call .m_render_br
    ret
.m_sel_exit:
    mov bx, 130
    mov cx, 166
    call .m_render_br
    ret
.m_render_br:
    push bx
    push cx
    mov si, str_l_bracket
    call menu_draw_string
    pop cx
    pop bx
    cmp al, 1
    je .m_off_opt
    add bx, 52
    jmp .m_draw_r
.m_off_opt:
    add bx, 76
.m_draw_r:
    mov si, str_r_bracket
    call menu_draw_string
    ret

menu_draw_perspective_grid:
    mov bx, 0
    mov cx, 100
    mov dx, 320
    mov si, 1
    mov al, 0x09
    call menu_draw_rect_color
    mov al, 0x03
    mov cx, 199
    mov bx, 20  
.mh_loop:
    cmp cx, 100
    jle .mv_start
    push bx
    call .mdraw_h
    pop bx
    sub cx, bx
    cmp bx, 2
    jle .mgap_ok
    dec bx
    dec bx
.mgap_ok:
    jmp .mh_loop
.mv_start:
    mov cx, -2000
.mv_loop:
    cmp cx, 2320
    jge .mg_done
    push cx
    call .mdraw_v
    pop cx
    add cx, 100
    jmp .mv_loop
.mg_done:
    ret
.mdraw_h:
    push ax
    push bx
    push cx
    push dx
    push si
    mov bx, 0
    mov dx, 320
    mov si, 1
    call menu_draw_rect_color
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.mdraw_v:
    push ax
    push bx
    push dx
    push si
    mov ax, 160
    mov bx, 100
    mov dx, 200
    mov si, 0x03
    call menu_draw_line
    pop si
    pop dx
    pop bx
    pop ax
    ret

menu_draw_tech_decoration:
    mov si, 0x0B
    mov ax, 0
    mov bx, 145
    mov cx, 110
    mov dx, 145
    call menu_draw_line
    mov ax, 110
    mov bx, 145
    mov cx, 110
    mov dx, 185
    call menu_draw_line
    mov ax, 110
    mov bx, 185
    mov cx, 210
    mov dx, 185
    call menu_draw_line
    mov ax, 210
    mov bx, 185
    mov cx, 210
    mov dx, 145
    call menu_draw_line
    mov ax, 210
    mov bx, 145
    mov cx, 319
    mov dx, 145
    call menu_draw_line
    ret

menu_draw_big_title:
    mov bx, 20
    mov cx, 30
    mov si, str_bitbloom
.mt_next:
    lodsb
    cmp al, 0
    je .mt_done
    push bx
    push cx
    add bx, 2
    add cx, 2
    mov byte [menu_current_color], 0x01
    call menu_draw_char_scaled
    pop cx
    pop bx
    mov byte [menu_current_color], 0x09
    call menu_draw_char_scaled
    add bx, 35
    jmp .mt_next
.mt_done:
    ret

menu_draw_rect_color:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    mov bp, ax
    mov ax, 0xA000
    mov es, ax
.mr_row:
    mov ax, cx
    push dx
    mov dx, 320
    mul dx
    pop dx
    add ax, bx
    mov di, ax
    push cx
    mov cx, dx
    mov ax, bp
    rep stosb
    pop cx
    inc cx
    dec si
    jnz .mr_row
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

menu_draw_line:
    mov [menu_line_x1], ax
    mov [menu_line_y1], bx
    mov [menu_line_x2], cx
    mov [menu_line_y2], dx
    sub cx, ax
    jge .ml_dx_p
    neg cx
    mov word [menu_line_sx], -1
    jmp .ml_calc_dy
.ml_dx_p:
    mov word [menu_line_sx], 1
.ml_calc_dy:
    mov [menu_line_dx], cx
    mov dx, [menu_line_y2]
    sub dx, bx
    jge .ml_dy_p
    neg dx
    neg dx
    mov word [menu_line_sy], -1
    jmp .ml_init
.ml_dy_p:
    neg dx
    mov word [menu_line_sy], 1
.ml_init:
    mov [menu_line_dy], dx
    add cx, dx
    mov [menu_line_err], cx
.ml_loop:
    mov cx, [menu_line_x1]
    mov dx, [menu_line_y1]
    mov ax, si
    call menu_put_pixel
    mov ax, [menu_line_x1]
    cmp ax, [menu_line_x2]
    jne .ml_cont
    mov ax, [menu_line_y1]
    cmp ax, [menu_line_y2]
    je .ml_ret
.ml_cont:
    mov ax, [menu_line_err]
    mov bx, ax
    add bx, bx
    mov cx, [menu_line_dy]
    cmp bx, cx
    jl .ml_step_y
    add [menu_line_err], cx
    mov dx, [menu_line_sx]
    add [menu_line_x1], dx
.ml_step_y:
    mov cx, [menu_line_dx]
    cmp bx, cx
    jg .ml_loop
    add [menu_line_err], cx
    mov dx, [menu_line_sy]
    add [menu_line_y1], dx
    jmp .ml_loop
.ml_ret:
    ret

menu_put_pixel:
    push ax
    push bx
    push di
    push es
    cmp cx, 0
    jl .mp_skip
    cmp cx, 320
    jge .mp_skip
    cmp dx, 0
    jl .mp_skip
    cmp dx, 200
    jge .mp_skip
    mov bx, 0xA000
    mov es, bx
    mov bx, 320
    push ax
    mov ax, dx
    mul bx
    add ax, cx
    mov di, ax
    pop ax
    stosb
.mp_skip:
    pop es
    pop di
    pop bx
    pop ax
    ret

menu_draw_char_scaled:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    call menu_get_font
    mov bp, 8
.ms_sr:
    lodsb
    mov dl, al
    push cx
    push bx
    mov dh, 8
.ms_sb:
    test dl, 0x80
    jz .ms_ss
    push ax
    push bx
    push cx
    push dx
    push si
    mov dx, 4
    mov si, 4
    mov al, [menu_current_color]
    call menu_draw_rect_color
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
.ms_ss:
    add bx, 4
    shl dl, 1
    dec dh
    jnz .ms_sb
    pop bx
    pop cx
    add cx, 4
    dec bp
    jnz .ms_sr
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

menu_draw_string:
    push ax
    push bx
    push cx
    push si
.mstr_char:
    lodsb
    cmp al, 0
    je .mstr_end
    call menu_draw_char
    add bx, 8
    jmp .mstr_char
.mstr_end:
    pop si
    pop cx
    pop bx
    pop ax
    ret

menu_draw_char:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    call menu_get_font
    mov bp, 8
.mdc_r:
    mov ax, cx
    push dx
    mov dx, 320
    mul dx
    pop dx
    add ax, bx
    mov di, ax
    mov ax, 0xA000
    mov es, ax
    lodsb
    mov dl, al
    mov dh, 8
.mdc_p:
    test dl, 0x80
    jz .mdc_skip
    push ax
    mov al, [menu_current_color]
    mov [es:di], al
    pop ax
.mdc_skip:
    inc di
    shl dl, 1
    dec dh
    jnz .mdc_p
    inc cx
    dec bp
    jnz .mdc_r
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

menu_get_font:
    cmp al, 'B'
    je .gf_b
    cmp al, 'I'
    je .gf_i
    cmp al, 'T'
    je .gf_t
    cmp al, 'L'
    je .gf_l
    cmp al, 'O'
    je .gf_o
    cmp al, 'M'
    je .gf_m
    cmp al, 'P'
    je .gf_p
    cmp al, 'A'
    je .gf_a
    cmp al, 'Y'
    je .gf_y
    cmp al, 'N'
    je .gf_n
    cmp al, 'S'
    je .gf_s
    cmp al, 'E'
    je .gf_e
    cmp al, 'X'
    je .gf_x
    cmp al, '['
    je .gf_lb
    cmp al, ']'
    je .gf_rb
    ret
.gf_b: mov si, mf_b
    ret
.gf_i: mov si, mf_i
    ret
.gf_t: mov si, mf_t
    ret
.gf_l: mov si, mf_l
    ret
.gf_o: mov si, mf_o
    ret
.gf_m: mov si, mf_m
    ret
.gf_p: mov si, mf_p
    ret
.gf_a: mov si, mf_a
    ret
.gf_y: mov si, mf_y
    ret
.gf_n: mov si, mf_n
    ret
.gf_s: mov si, mf_s
    ret
.gf_e: mov si, mf_e
    ret
.gf_x: mov si, mf_x
    ret
.gf_lb: mov si, mf_lb
    ret
.gf_rb: mov si, mf_rb
    ret

menu_clear_screen:
    push es
    push di
    push ax
    push cx
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov cx, 32000
    xor ax, ax
    rep stosw
    pop cx
    pop ax
    pop di
    pop es
    ret

menu_install_interrupts:
    cli
    mov ax, 0x3509
    int 0x21
    mov [menu_old_int9_seg], es
    mov [menu_old_int9_off], bx
    mov ax, 0x2509
    mov dx, menu_new_int9
    int 0x21
    mov ax, 0x351C
    int 0x21
    mov [menu_old_int1c_seg], es
    mov [menu_old_int1c_off], bx
    mov ax, 0x251C
    mov dx, menu_new_int1c
    int 0x21
    sti
    ret

menu_restore_interrupts:
    push ds
    cli
    mov dx, [cs:menu_old_int9_off]
    mov ax, [cs:menu_old_int9_seg]
    mov ds, ax
    mov ax, 0x2509
    int 0x21
    mov dx, [cs:menu_old_int1c_off]
    mov ax, [cs:menu_old_int1c_seg]
    mov ds, ax
    mov ax, 0x251C
    int 0x21
    pop ds
    sti
    ret


game_init:
    call game_clear_active_balloons
    mov word [game_score_val], 0
    mov word [game_missed_count], 0
    call game_reset_balloons
    call game_get_tick
    mov [game_start_tick_low], ax
    mov [game_start_tick_high], dx
    mov [game_seed], ax

game_reload_graphics:
    mov ax, 0x0013
    int 0x10

    mov dx, str_filename        
    mov ax, 0x3D00          
    int 0x21
    jc game_file_error_msg
    mov [game_file_handle], ax  

    mov bx, [game_file_handle]
    mov cx, 768            
    mov dx, game_palette_buffer  
    mov ah, 0x3F            
    int 0x21

    mov si, game_palette_buffer
    mov dx, 0x03C8
    xor al, al
    out dx, al              
    inc dx                  
    mov cx, 768
    rep outsb              

    call game_set_palette

    push ds                
    mov ax, 0xA000
    mov ds, ax              
    xor dx, dx              
    mov cx, 64000          
    mov bx, [cs:game_file_handle]
    mov ah, 0x3F            
    int 0x21
    pop ds                  

    mov bx, [game_file_handle]
    mov ah, 0x3E
    int 0x21

    call game_draw_bottom_bar    
    call game_draw_hud_static


game_loop:
    call vsync_wait

    call game_get_tick
    sub ax, [game_start_tick_low]
    cmp ax, GAME_TIME_TICKS
    jae game_trigger_game_over

    push ax
    call game_update_timer
    pop ax

    mov bx, ax
    sub bx, [game_last_tick]
    cmp bx, 1              
    jb .g_input_check

    mov [game_last_tick], ax
    call game_spawn_balloon      
    call game_update_balloons    
   
    cmp word [game_missed_count], MAX_MISSES
    jae game_trigger_game_over

.g_input_check:
    mov ah, 0x01            
    int 0x16
    jz .g_loop_end            
   
    mov ah, 0x00            
    int 0x16
   
    cmp ah, 0x01            
	
    je game_trigger_pause
   
    cmp al, 'a'
    jb .g_check_pop
    cmp al, 'z'
    ja .g_check_pop
    sub al, 32              

.g_check_pop:
    call game_check_pop  

.g_loop_end:
    jmp game_loop

game_trigger_pause:
    call game_get_tick          
    mov [game_pause_time_store], ax 
    jmp pause_init
	
game_trigger_game_over:
    jmp gov_init

game_file_error_msg:
    jmp menu_init

game_reset_balloons:
    mov si, game_balloons
    mov cx, 5500
    mov al, 0
.gr_loop:
    mov [si], al
    inc si
    loop .gr_loop
    ret

game_clear_active_balloons:
    mov si, game_balloons
    mov cx, MAX_BALLOONS
.gca_loop:
    cmp byte [si+4], 1      
    jne .gca_next
    call game_restore_bg    
.gca_next:
    add si, BALLOON_SIZE
    loop .gca_loop
    ret

game_play_pop_sound:
    push ax
    push bx
    push cx
    push dx
    mov al, 0xB6    
    out 0x43, al
    in al, 0x61
    or al, 3        
    out 0x61, al
    mov bx, 2000    
.gp_sweep:
    mov ax, bx
    out 0x42, al    
    mov al, ah
    out 0x42, al    
    mov cx, 150    
.gp_del:
    loop .gp_del
    sub bx, 100    
    cmp bx, 500    
    ja .gp_sweep
    in al, 0x61
    and al, 0xFC    
    out 0x61, al
    pop dx
    pop cx
    pop bx
    pop ax
    ret

game_set_palette:
    mov dx, 0x3C8
    mov al, 240            
    out dx, al
    inc dx
    xor al, al
    out dx, al
    out dx, al
    out dx, al
    mov al, 63
    out dx, al
    xor al, al
    out dx, al
    out dx, al
    mov al, 63
    out dx, al
    mov al, 30
    out dx, al
    mov al, 30
    out dx, al
    mov al, 63
    out dx, al
    out dx, al
    out dx, al
    out dx, al
    out dx, al
    out dx, al
    xor al, al
    out dx, al
    out dx, al
    out dx, al
    xor al, al
    out dx, al
    mov al, 63
    out dx, al
    xor al, al
    out dx, al
    mov al, 30
    out dx, al
    mov al, 63
    out dx, al
    mov al, 30
    out dx, al
    mov al, 63
    out dx, al
    out dx, al
    out dx, al
    out dx, al
    out dx, al
    out dx, al
    xor al, al
    out dx, al
    out dx, al
    out dx, al
    xor al, al
    out dx, al
    out dx, al
    mov al, 63
    out dx, al
    mov al, 30
    out dx, al
    mov al, 30
    out dx, al
    mov al, 63
    out dx, al
    mov al, 63
    out dx, al
    out dx, al
    out dx, al
    out dx, al
    out dx, al
    out dx, al
    mov al, 63
    out dx, al
    out dx, al
    xor al, al
    out dx, al
    ret

game_spawn_balloon:
    call game_get_random
    and ax, 0x0F
    cmp ax, 0
    jne .gs_ret
    mov si, game_balloons
    mov cx, MAX_BALLOONS
.gs_find:
    cmp byte [si+4], 0      
    je .gs_found
    add si, BALLOON_SIZE            
    loop .gs_find
    ret                    
.gs_found:
    mov bp, 10              
.gs_pos:
    call game_get_random
    xor dx, dx
    mov bx, 260            
    div bx
    add dx, 10
    mov di, dx              
    push cx
    push si
    mov bx, game_balloons        
    mov cx, MAX_BALLOONS
.gs_check:
    cmp byte [bx+4], 1      
    jne .gs_next
    mov ax, [bx]            
    sub ax, di              
    cmp ax, 0
    jge .gs_diff
    neg ax
.gs_diff:
    cmp ax, 36              
    jl .gs_coll
.gs_next:
    add bx, BALLOON_SIZE            
    loop .gs_check
    pop si
    pop cx
    jmp .gs_valid
.gs_coll:
    pop si
    pop cx
    dec bp
    jnz .gs_pos      
    ret                    
.gs_valid:
    mov byte [si+4], 1      
    mov word [si+2], 160    
    mov word [si], di      
    call game_get_random
    xor dx, dx
    mov bx, 3
    div bx
    cmp dl, 0
    jne .gs_g
    mov byte [si+6], 240    
    jmp .gs_char
.gs_g:
    cmp dl, 1
    jne .gs_b
    mov byte [si+6], 245    
    jmp .gs_char
.gs_b:
    mov byte [si+6], 250    
.gs_char:
    call game_get_random
    xor dx, dx
    mov bx, 26
    div bx
    add dl, 'A'
    mov byte [si+5], dl  
    call game_save_bg
    call game_draw_balloon
    ret
.gs_ret:
    ret

game_update_balloons:
    mov si, game_balloons
    mov cx, MAX_BALLOONS
.gu_loop:
    cmp byte [si+4], 1      
    jne .gu_next
    call game_restore_bg
    dec word [si+2]        
    cmp word [si+2], 8      
    jle .gu_miss
    call game_save_bg
    call game_draw_balloon
    jmp .gu_next
.gu_miss:
    mov byte [si+4], 0      
    inc word [game_missed_count]
    call game_update_score
    jmp .gu_next
.gu_next:
    add si, BALLOON_SIZE            
    loop .gu_loop
    ret

game_check_pop:
    mov si, game_balloons
    mov cx, MAX_BALLOONS
.gc_scan:
    cmp byte [si+4], 1      
    jne .gc_next
    cmp byte [si+5], al    
    jne .gc_next
    call game_play_pop_sound
    call game_restore_bg
    mov byte [si+4], 0      
    add word [game_score_val], 10
    call game_update_score
    ret                    
.gc_next:
    add si, BALLOON_SIZE
    loop .gc_scan
    ret

game_check_sanity:
    mov ax, [si]
    cmp ax, 280    
    ja .gsc_bad
    mov ax, [si+2]
    cmp ax, 195    
    ja .gsc_bad
    cmp ax, 2      
    jl .gsc_bad
    cmp ax, ax      
    ret
.gsc_bad:
    or ax, 1        
    ret

game_save_bg:
    call game_check_sanity
    jne .gsb_abort
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    cld
    mov ax, [si+2]  
    mov bx, 320
    mul bx
    add ax, [si]    
    mov di, si
    add di, 8      
    mov bx, cs      
    mov es, bx      
    mov si, ax
    mov bx, 0xA000
    mov ds, bx      
    mov cx, 32      
.gsb_row:
    push cx
    mov cx, 32      
    rep movsb      
    add si, 288    
    pop cx
    loop .gsb_row
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
.gsb_abort:
    ret

game_restore_bg:
    call game_check_sanity
    jne .grb_abort
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    cld
    mov ax, [si+2]  
    mov bx, 320
    mul bx
    add ax, [si]    
    mov di, ax      
    add si, 8      
    mov bx, cs      
    mov ds, bx      
    mov bx, 0xA000
    mov es, bx      
    mov cx, 32      
.grb_row:
    push cx
    mov cx, 32      
    rep movsb      
    add di, 288    
    pop cx
    loop .grb_row
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
.grb_abort:
    ret

game_draw_balloon:
    call game_check_sanity
    jne .gdb_abort
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov ax, [si+2]
    mov bx, 320
    mul bx
    add ax, [si]  
    mov di, ax
    mov ax, 0xA000
    mov es, ax
    mov bx, game_balloon_sprite
    mov cx, 32      
    mov dh, [si+6]
.gdb_row:
    push cx
    push di
    mov cx, 32      
.gdb_col:
    mov al, [cs:bx]
    cmp al, 0
    je .gdb_skip
    cmp al, 3
    je .gdb_shine
    cmp al, 4
    je .gdb_string
    add al, dh      
    mov [es:di], al
    jmp .gdb_skip
.gdb_shine:
    mov byte [es:di], 243
    jmp .gdb_skip
.gdb_string:
    mov byte [es:di], 244
    jmp .gdb_skip
.gdb_skip:
    inc bx
    inc di
    loop .gdb_col
    pop di
    add di, 320            
    pop cx
    loop .gdb_row
    mov ax, [si]
    add ax, 12
    mov bx, [si+2]
    add bx, 7      
    mov dl, [si+5]
    push ax
    push bx
    push dx
    inc ax
    inc bx
    mov byte [game_text_color], 240
    call game_draw_single_char
    pop dx
    pop bx
    pop ax
    mov byte [game_text_color], 255
    call game_draw_single_char
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
.gdb_abort:
    ret

game_draw_single_char:
    push si
    push di
    push es
    push ax
    push dx
    push cx
    push bx
    cmp byte [game_text_color], 0
    jne .gsc_col_ok
    mov byte [game_text_color], 255
.gsc_col_ok:
    push ax
    push dx
    mov ax, bx
    mov dx, 320
    mul dx
    mov di, ax
    pop dx
    pop ax
    add di, ax
    mov ax, 0xA000
    mov es, ax
    xor dh, dh
    sub dl, 'A'
    mov ax, 8
    mul dx
    add ax, game_alpha_font
    mov si, ax
    mov cx, 8              
.gsc_row:
    lodsb                  
    push cx
    mov cx, 8
    mov bl, al
.gsc_col:
    shl bl, 1
    jnc .gsc_no
    mov al, [game_text_color]
    mov byte [es:di], al
.gsc_no:
    inc di
    loop .gsc_col
    pop cx
    add di, 312            
    loop .gsc_row
    pop bx
    pop cx
    pop dx
    pop ax
    pop es
    pop di
    pop si
    ret

game_draw_bottom_bar:
    push ax
    push cx
    push di
    push es
    mov ax, 0xA000
    mov es, ax
    mov di, 58880
    mov cx, 5120  
    mov al, 240  
    rep stosb
    pop es
    pop di
    pop cx
    pop ax
    ret

game_draw_hud_static:
    mov byte [game_text_color], 240
    mov bx, 11
    mov cx, 189
    mov si, str_timer
    call game_draw_string
    mov bx, 221
    mov cx, 189
    mov si, str_score
    call game_draw_string
    mov byte [game_text_color], 255
    mov bx, 10
    mov cx, 188
    mov si, str_timer
    call game_draw_string
    mov bx, 220
    mov cx, 188
    mov si, str_score
    call game_draw_string
    ret

game_update_score:
    mov ax, [game_score_val]
    mov si, game_score_buf + 2
    mov cx, 3
.gus_c:
    xor dx, dx
    mov bx, 10
    div bx
    add dl, '0'
    mov [si], dl
    dec si
    loop .gus_c
    mov bx, 276
    mov cx, 188
    mov dx, 26
    mov si, 10
    call game_draw_box          
    mov byte [game_text_color], 240
    mov bx, 277
    mov cx, 189
    mov si, game_score_buf
    call game_draw_string
    mov byte [game_text_color], 255
    mov bx, 276
    mov cx, 188
    mov si, game_score_buf
    call game_draw_string
    ret

game_update_timer:
    
    call game_get_tick
    sub ax, [game_start_tick_low]
    mov bx, GAME_TIME_TICKS
    sub bx, ax
    cmp bx, 0
    jge .gut_ok
    mov bx, 0
.gut_ok:
    mov ax, bx
    xor dx, dx
    mov cx, 10
    mul cx          
    mov cx, 182    
    div cx          
   
    
   
    push ax
    cmp ax, [game_last_second]
    pop ax
    je .gut_skip
    mov [game_last_second], ax
    xor dx, dx
    mov cx, 60
    div cx                  
    add al, '0'
    mov [game_timer_str], al
    mov ax, dx
    xor dx, dx
    mov cx, 10
    div cx                  
    add al, '0'
    mov [game_timer_str+2], al
    add dl, '0'
    mov [game_timer_str+3], dl
    mov bx, 58
    mov cx, 188
    mov dx, 42
    mov si, 10
    call game_draw_box
    mov byte [game_text_color], 240
    mov bx, 59
    mov cx, 189
    mov si, game_timer_str
    call game_draw_string
    mov byte [game_text_color], 255
    mov bx, 58
    mov cx, 188
    mov si, game_timer_str
    call game_draw_string
.gut_skip:
    ret

game_get_random:
    mov ax, [game_seed]
    mov dx, 31821
    mul dx
    add ax, 13849
    push ds
    push bx
    mov bx, 0x40
    mov ds, bx
    add ax, [0x6C]
    pop bx
    pop ds
    mov [game_seed], ax
    ret

game_draw_box:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    mov ax, 0xA000
    mov es, ax
    mov bp, si      
.gdbx_row:
    mov ax, cx      
    push dx        
    mov dx, 320
    mul dx          
    pop dx          
    add ax, bx      
    mov di, ax      
    push cx
    mov cx, dx      
    mov al, 240    
    rep stosb      
    pop cx
    inc cx          
    dec bp          
    jnz .gdbx_row
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

game_draw_string:
    push ax
    push bx
    push cx
    push si
.gds_c:
    lodsb
    cmp al, 0
    je .gds_e
    call game_draw_char
    add bx, 8
    jmp .gds_c
.gds_e:
    pop si
    pop cx
    pop bx
    pop ax
    ret

game_draw_char:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    cmp al, '0'
    jb .gdc_l
    cmp al, '9'
    ja .gdc_l
    sub al, '0'
    xor ah, ah
    mov si, 8
    mul si
    add ax, game_digit_font
    mov si, ax
    jmp .gdc_d
.gdc_l:
    cmp al, ':'
    je .gdc_col
    cmp al, ' '
    je .gdc_sp
    cmp al, 'A'
    jae .gdc_a
    jmp .gdc_sk
.gdc_a:
    sub al, 'A'  
    xor ah, ah
    mov si, 8
    mul si
    add ax, game_alpha_font
    mov si, ax
    jmp .gdc_d
.gdc_col: mov si, game_colon_font
    jmp .gdc_d
.gdc_sp: mov si, game_space_font
    jmp .gdc_d
.gdc_sk:
    mov si, game_space_font
    jmp .gdc_d
.gdc_d:
    mov bp, 8
.gdc_r:
    mov ax, cx
    push dx
    mov dx, 320
    mul dx
    pop dx
    add ax, bx
    mov di, ax
    mov ax, 0xA000
    mov es, ax
    lodsb
    mov dl, al
    mov dh, 8
.gdc_p:
    test dl, 0x80
    jz .gdc_np
    push ax
    mov al, [game_text_color]
    mov byte [es:di], al
    pop ax
.gdc_np:
    inc di
    shl dl, 1
    dec dh
    jnz .gdc_p
    inc cx
    dec bp
    jnz .gdc_r
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

game_get_tick:
    push bx
    push ds
    mov bx, 0x0040
    mov ds, bx
    mov bx, 0x006C
    mov ax, [ds:bx]
    mov dx, [ds:bx+2]
    pop ds
    pop bx
    ret


pause_init:
    mov ax, 0x0013
    int 0x10
    call pause_install_interrupts
    call pause_draw_static_interface
    mov byte [pause_redraw_flag], 1
    mov byte [pause_blink_state], 1
    mov byte [pause_exit_flag], 0
    mov byte [pause_selection_index], 0

pause_loop:
    cmp byte [pause_exit_flag], 1
    je pause_check_exit_action
    cmp byte [pause_redraw_flag], 1
    jne .p_wait_for_int
    call vsync_wait
    call pause_update_brackets
    mov byte [pause_redraw_flag], 0
.p_wait_for_int:
    hlt
    jmp pause_loop

pause_check_exit_action:
    call pause_restore_interrupts
    cmp byte [pause_selection_index], 0
    je .p_resume
    cmp byte [pause_selection_index], 1
    je .p_restart
    jmp .p_quit
.p_resume:
    
    call game_get_tick          
    sub ax, [game_pause_time_store] 
    add [game_start_tick_low], ax   							
    jmp game_reload_graphics
.p_restart:
    jmp game_init            
.p_quit:
    jmp menu_init            

pause_new_int9:
    push ax
    push ds
    push cs
    pop ds
    in al, 0x60
    test al, 0x80
    jnz .p_ack
    cmp al, 0x48
    je .p_up
    cmp al, 0x50
    je .p_down
    cmp al, 0x1C
    je .p_enter
    cmp al, 0x01
    je .p_esc
    jmp .p_ack
.p_up:
    mov al, [pause_selection_index]
    mov [pause_old_selection], al
    dec byte [pause_selection_index]
    cmp byte [pause_selection_index], 0
    jge .p_u_done
    mov byte [pause_selection_index], 2
.p_u_done:
    mov byte [pause_blink_state], 1
    mov byte [pause_redraw_flag], 1
    jmp .p_ack
.p_down:
    mov al, [pause_selection_index]
    mov [pause_old_selection], al
    inc byte [pause_selection_index]
    cmp byte [pause_selection_index], 2
    jle .p_d_done
    mov byte [pause_selection_index], 0
.p_d_done:
    mov byte [pause_blink_state], 1
    mov byte [pause_redraw_flag], 1
    jmp .p_ack
.p_enter:
    mov byte [pause_exit_flag], 1
    jmp .p_ack
.p_esc:
    mov byte [pause_selection_index], 0
    mov byte [pause_exit_flag], 1
    jmp .p_ack
.p_ack:
    mov al, 0x20
    out 0x20, al
    pop ds
    pop ax
    iret

pause_new_int1c:
    push ax
    push ds
    push cs
    pop ds
    inc byte [pause_blink_timer]
    cmp byte [pause_blink_timer], 8
    jl .p_t_done
    mov byte [pause_blink_timer], 0
    xor byte [pause_blink_state], 1
    mov byte [pause_redraw_flag], 1
.p_t_done:
    pop ds
    pop ax
    iret

pause_draw_static_interface:
    call pause_clear_screen
    mov byte [pause_current_color], 0x01
    mov bx, 66
    mov cx, 52
    mov si, str_paused
    call pause_draw_string_big
    mov byte [pause_current_color], 0x09
    mov bx, 64
    mov cx, 50
    mov si, str_paused
    call pause_draw_string_big
    mov byte [pause_current_color], 0x0F
    mov bx, 136
    mov cx, 110
    mov si, str_resume
    call pause_draw_string
    mov bx, 132
    mov cx, 125
    mov si, str_restart
    call pause_draw_string
    mov bx, 144
    mov cx, 140
    mov si, str_quit
    call pause_draw_string
    call pause_draw_star
    ret

pause_update_brackets:
    mov al, [pause_selection_index]
    cmp al, [pause_old_selection]
    je .p_dr_new
    mov byte [pause_current_color], 0x00
    mov al, [pause_old_selection]
    call pause_draw_brackets_at_index
    mov al, [pause_selection_index]
    mov [pause_old_selection], al
.p_dr_new:
    cmp byte [pause_blink_state], 1
    je .p_bl_on
    mov byte [pause_current_color], 0x00
    jmp .p_do
.p_bl_on:
    mov byte [pause_current_color], 0x0E
.p_do:
    mov al, [pause_selection_index]
    call pause_draw_brackets_at_index
    ret

pause_draw_brackets_at_index:
    cmp al, 0
    je .p_at_res
    cmp al, 1
    je .p_at_rst
    jmp .p_at_q
.p_at_res:
    mov bx, 124
    mov cx, 110
    jmp .p_dr
.p_at_rst:
    mov bx, 120
    mov cx, 125
    jmp .p_dr
.p_at_q:
    mov bx, 132
    mov cx, 140
    jmp .p_dr
.p_dr:
    push bx            
    push cx            
    mov si, str_l_bracket
    call pause_draw_string
    pop cx              
    pop bx              
    cmp al, 0
    je .p_w_res
    cmp al, 1
    je .p_w_rst
    add bx, 32          
    jmp .p_dr_r
.p_w_res:
    add bx, 48          
    jmp .p_dr_r
.p_w_rst:
    add bx, 56          
.p_dr_r:
    add bx, 16          
    mov si, str_r_bracket
    call pause_draw_string
    ret

pause_clear_screen:
    push es
    push di
    push ax
    push cx
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov cx, 32000
    xor ax, ax
    rep stosw
    pop cx
    pop ax
    pop di
    pop es
    ret

pause_draw_rect_fill:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    mov bp, ax
    mov ax, 0xA000
    mov es, ax
.p_f_l:
    mov ax, cx
    push dx
    mov dx, 320
    mul dx
    pop dx
    add ax, bx
    mov di, ax
    push cx
    mov cx, dx
    mov ax, bp
    rep stosb
    pop cx
    inc cx
    dec si
    jnz .p_f_l
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

pause_draw_star:
    push ax
    push bx
    push cx
    push dx
    push si
    mov ax, 0x0F
    mov [pause_current_color], ax
    mov bx, 302
    mov cx, 185
    mov dx, 7
    mov si, 1
    mov al, 0x0F
    call pause_draw_rect_fill
    mov bx, 305
    mov cx, 182
    mov dx, 1
    mov si, 7
    mov al, 0x0F
    call pause_draw_rect_fill
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

pause_draw_string:
    push ax
    push bx
    push cx
    push si
.p_n_c:
    lodsb              
    cmp al, 0
    je .p_dn
    call pause_draw_char_8x8        
    add bx, 8              
    jmp .p_n_c
.p_dn:
    pop si
    pop cx
    pop bx
    pop ax
    ret

pause_draw_string_big:
    push ax
    push bx
    push cx
    push si
.p_n_b:
    lodsb
    cmp al, 0
    je .p_d_b
    call pause_draw_char_scaled
    add bx, 32
    jmp .p_n_b
.p_d_b:
    pop si
    pop cx
    pop bx
    pop ax
    ret

pause_draw_char_8x8:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    call pause_get_font
    mov bp, 8      
.p_dr_r_l:
    mov ax, cx            
    push dx
    mov dx, 320
    mul dx
    pop dx
    add ax, bx            
    mov di, ax
    mov ax, 0xA000
    mov es, ax
    lodsb
    mov dl, al
    mov dh, 8
.p_dr_p:
    test dl, 0x80
    jz .p_np
    mov al, [pause_current_color]
    mov [es:di], al
.p_np:
    inc di
    shl dl, 1
    dec dh
    jnz .p_dr_p
    inc cx                
    dec bp
    jnz .p_dr_r_l
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

pause_draw_char_scaled:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    call pause_get_font
    mov bp, 8
.p_s_rl:
    lodsb
    mov dl, al
    push cx
    push bx
    mov dh, 8
.p_s_bl:
    test dl, 0x80
    jz .p_s_nb
    push ax
    push bx
    push cx
    push dx
    push si
    mov dx, 4
    mov si, 4
    mov al, [pause_current_color]
    call pause_draw_rect_fill
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
.p_s_nb:
    add bx, 4
    shl dl, 1
    dec dh
    jnz .p_s_bl
    pop bx
    pop cx
    add cx, 4
    dec bp
    jnz .p_s_rl
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

pause_get_font:
    cmp al, 'P'
    je .pf_p
    cmp al, 'A'
    je .pf_a
    cmp al, 'U'
    je .pf_u
    cmp al, 'S'
    je .pf_s
    cmp al, 'E'
    je .pf_e
    cmp al, 'D'
    je .pf_d
    cmp al, 'R'
    je .pf_r
    cmp al, 'M'
    je .pf_m
    cmp al, 'T'
    je .pf_t
    cmp al, 'Q'
    je .pf_q
    cmp al, 'I'
    je .pf_i
    cmp al, '['
    je .pf_lb
    cmp al, ']'
    je .pf_rb
    ret
.pf_p: mov si, pf_p
       ret
.pf_a: mov si, pf_a
       ret
.pf_u: mov si, pf_u
       ret
.pf_s: mov si, pf_s
       ret
.pf_e: mov si, pf_e
       ret
.pf_d: mov si, pf_d
       ret
.pf_r: mov si, pf_r
       ret
.pf_m: mov si, pf_m
       ret
.pf_t: mov si, pf_t
       ret
.pf_q: mov si, pf_q
       ret
.pf_i: mov si, pf_i
       ret
.pf_lb: mov si, pf_lb
       ret
.pf_rb: mov si, pf_rb
       ret

pause_install_interrupts:
    cli
    mov ax, 0x3509
    int 0x21
    mov [pause_old_int9_seg], es
    mov [pause_old_int9_off], bx
    mov ax, 0x2509
    mov dx, pause_new_int9
    int 0x21
    mov ax, 0x351C
    int 0x21
    mov [pause_old_int1c_seg], es
    mov [pause_old_int1c_off], bx
    mov ax, 0x251C
    mov dx, pause_new_int1c
    int 0x21
    sti
    ret

pause_restore_interrupts:
    push ds
    cli
    mov dx, [cs:pause_old_int9_off]
    mov ax, [cs:pause_old_int9_seg]
    mov ds, ax
    mov ax, 0x2509
    int 0x21
    mov dx, [cs:pause_old_int1c_off]
    mov ax, [cs:pause_old_int1c_seg]
    mov ds, ax
    mov ax, 0x251C
    int 0x21
    pop ds
    sti
    ret

gov_init:
    mov ax, 0x0013
    int 0x10
    call gov_convert_score
    call gov_install_interrupts
    mov byte [gov_redraw_flag], 1
    mov byte [gov_blink_state], 0
    mov byte [gov_exit_flag], 0
    mov byte [gov_selection_index], 0

gov_loop:
    cmp byte [gov_exit_flag], 1
    je gov_check_exit
    cmp byte [gov_redraw_flag], 1
    jne .gv_wait
   
    
    call gov_draw_frame_direct
   
    mov byte [gov_redraw_flag], 0
.gv_wait:
    hlt
    jmp gov_loop

gov_check_exit:
    call gov_restore_interrupts
    cmp byte [gov_selection_index], 0
    je .gv_retry
    jmp .gv_menu
.gv_retry:
    jmp game_init
.gv_menu:
    jmp menu_init

gov_convert_score:
    mov ax, [game_score_val]
    mov si, gov_msg_score + 11
    mov cx, 5
.gc_loop:
    xor dx, dx
    mov bx, 10
    div bx
    add dl, '0'
    mov [si], dl
    dec si
    loop .gc_loop
    ret

gov_new_int9:
    push ax
    push ds
    push cs
    pop ds
    in al, 0x60
    cmp al, 0x48
    je .gv_left
    cmp al, 0x50
    je .gv_right
    cmp al, 0x1C
    je .gv_ent
    cmp al, 0x01
    je .gv_esc
    jmp .gv_ack
.gv_left:
    dec byte [gov_selection_index]
    cmp byte [gov_selection_index], 0
    jge .gv_ld
    mov byte [gov_selection_index], 1
.gv_ld:
    mov byte [gov_redraw_flag], 1
    jmp .gv_ack
.gv_right:
    inc byte [gov_selection_index]
    cmp byte [gov_selection_index], 1
    jle .gv_rd
    mov byte [gov_selection_index], 0
.gv_rd:
    mov byte [gov_redraw_flag], 1
    jmp .gv_ack
.gv_ent:
    mov byte [gov_exit_flag], 1
    jmp .gv_ack
.gv_esc:
    mov byte [gov_selection_index], 1
    mov byte [gov_exit_flag], 1
    jmp .gv_ack
.gv_ack:
    mov al, 0x20
    out 0x20, al
    pop ds
    pop ax
    iret

gov_new_int1c:
    push ax
    push ds
    push cs
    pop ds
    inc byte [gov_blink_timer]
    cmp byte [gov_blink_timer], 8
    jl .gv_td
    mov byte [gov_blink_timer], 0
    xor byte [gov_blink_state], 1
    mov byte [gov_redraw_flag], 1
.gv_td:
    pop ds
    pop ax
    iret


gov_draw_frame_direct:
    call gov_clear_screen
    call gov_draw_big_title
    mov byte [gov_current_color], 0x09
    mov bx, 112        
    mov cx, 90
    mov si, gov_msg_score
    call gov_draw_string
    call gov_draw_menu_items
    ret


gov_clear_screen:
    push es
    push di
    push ax
    push cx
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov cx, 32000
    xor ax, ax
    rep stosw
    pop cx
    pop ax
    pop di
    pop es
    ret

gov_draw_big_title:
    mov bx, 12
    mov cx, 40
    mov si, str_gameover
.gv_bt:
    lodsb
    cmp al, 0
    je .gv_btd
    push bx
    push cx
    add bx, 2
    add cx, 2
    mov byte [gov_current_color], 0x01
    call gov_draw_char_scaled
    pop cx
    pop bx
    mov byte [gov_current_color], 0x09
    call gov_draw_char_scaled
    add bx, 33        
    jmp .gv_bt
.gv_btd:
    ret

gov_draw_menu_items:
    mov byte [gov_current_color], 0x0F
    mov bx, 124
    mov cx, 130
    mov si, str_tryagain
    call gov_draw_string
    mov bx, 112
    mov cx, 150
    mov si, str_mainmenu
    call gov_draw_string
    cmp byte [gov_blink_state], 1
    je .gv_sk
    mov byte [gov_current_color], 0x0E
    cmp byte [gov_selection_index], 0
    je .gv_st
    jmp .gv_sm
.gv_st:
    mov bx, 110
    mov cx, 130
    mov si, str_l_bracket
    call gov_draw_string
    mov bx, 202
    mov si, str_r_bracket
    call gov_draw_string
    ret
.gv_sm:
    mov bx, 98
    mov cx, 150
    mov si, str_l_bracket
    call gov_draw_string
    mov bx, 214
    mov si, str_r_bracket
    call gov_draw_string
    ret
.gv_sk:
    ret

gov_draw_char_scaled:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    call gov_get_font
    mov bp, 8  
.gv_sc_r:
    lodsb      
    mov dl, al
    push cx
    push bx
    mov dh, 8  
.gv_sc_b:
    test dl, 0x80
    jz .gv_sc_n
    push ax
    push bx
    push cx
    push dx
    push si
    mov dx, 4
    mov si, 4
    mov al, [gov_current_color]
    call gov_draw_rect_direct
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
.gv_sc_n:
    add bx, 4  
    shl dl, 1
    dec dh
    jnz .gv_sc_b
    pop bx
    pop cx
    add cx, 4  
    dec bp
    jnz .gv_sc_r
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret


gov_draw_rect_direct:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    mov bp, ax
    mov ax, 0xA000
    mov es, ax
.gv_rc_l:
    mov ax, cx
    push dx
    mov dx, 320
    mul dx  
    pop dx
    add ax, bx
    mov di, ax
    push cx
    mov cx, dx
    mov ax, bp
    rep stosb
    pop cx
    inc cx
    dec si
    jnz .gv_rc_l
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

gov_draw_string:
    push ax
    push bx
    push cx
    push si
.gv_str_n:
    lodsb
    cmp al, 0
    je .gv_str_d
    call gov_draw_char
    add bx, 8
    jmp .gv_str_n
.gv_str_d:
    pop si
    pop cx
    pop bx
    pop ax
    ret

gov_draw_char:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    
    
    cmp al, '0'
    jb .gv_chk_let    
    cmp al, '9'
    ja .gv_chk_let    
    
    
    sub al, '0'       
    xor ah, ah
    mov si, 8
    mul si            
    add ax, game_digit_font 
    mov si, ax
    jmp .gv_ready    
    

.gv_chk_let:
    call gov_get_font 
    

.gv_ready:
    mov bp, 8         
.gv_dc_r:
    mov ax, cx
    push dx
    mov dx, 320
    mul dx
    pop dx
    add ax, bx
    mov di, ax
    mov ax, 0xA000
    mov es, ax
    lodsb             
    mov dl, al
    mov dh, 8
.gv_dc_p:
    test dl, 0x80
    jz .gv_dc_n
    push ax
    mov al, [gov_current_color]
    mov [es:di], al
    pop ax
.gv_dc_n:
    inc di
    shl dl, 1
    dec dh
    jnz .gv_dc_p
    inc cx
    dec bp
    jnz .gv_dc_r
    
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

gov_get_font:
    cmp al, ' '    
    je .gf_sp       
    cmp al, 'S'
    je .gf_s
    cmp al, 'C'
    je .gf_c
    cmp al, 'O'
    je .gf_o
    cmp al, 'R'
    je .gf_r
    cmp al, 'E'
    je .gf_e
    cmp al, ':'
    je .gf_cl
    cmp al, '0'
    je .gf_0
    cmp al, 'T'
    je .gf_t
    cmp al, 'Y'
    je .gf_y
    cmp al, 'A'
    je .gf_a
    cmp al, 'G'
    je .gf_g
    cmp al, 'I'
    je .gf_i
    cmp al, 'N'
    je .gf_n
    cmp al, 'B'
    je .gf_b
    cmp al, 'K'
    je .gf_k
    cmp al, 'M'
    je .gf_m
    cmp al, 'V'
    je .gf_v
    cmp al, '['
    je .gf_lb
    cmp al, ']'
    je .gf_rb
    
   
    jmp .gf_sp 

.gf_s: mov si, gf_s
    ret
.gf_c: mov si, gf_c
    ret
.gf_o: mov si, gf_o
    ret
.gf_r: mov si, gf_r
    ret
.gf_e: mov si, gf_e
    ret
.gf_cl: mov si, gf_cl
    ret
.gf_0: mov si, gf_0
    ret
.gf_t: mov si, gf_t
    ret
.gf_y: mov si, gf_y
    ret
.gf_a: mov si, gf_a
    ret
.gf_g: mov si, gf_g
    ret
.gf_i: mov si, gf_i
    ret
.gf_n: mov si, gf_n
    ret
.gf_b: mov si, gf_b
    ret
.gf_k: mov si, gf_k
    ret
.gf_m: mov si, gf_m
    ret
.gf_v: mov si, gf_v
    ret
.gf_lb: mov si, mf_lb
    ret
.gf_rb: mov si, mf_rb
    ret
.gf_sp: mov si, game_space_font  
    ret

gov_install_interrupts:
    cli
    mov ax, 0x3509
    int 0x21
    mov [gov_old_int9_seg], es
    mov [gov_old_int9_off], bx
    mov ax, 0x2509
    mov dx, gov_new_int9
    int 0x21
    mov ax, 0x351C
    int 0x21
    mov [gov_old_int1c_seg], es
    mov [gov_old_int1c_off], bx
    mov ax, 0x251C
    mov dx, gov_new_int1c
    int 0x21
    sti
    ret

gov_restore_interrupts:
    push ds
    cli
    mov dx, [cs:gov_old_int9_off]
    mov ax, [cs:gov_old_int9_seg]
    mov ds, ax
    mov ax, 0x2509
    int 0x21
    mov dx, [cs:gov_old_int1c_off]
    mov ax, [cs:gov_old_int1c_seg]
    mov ds, ax
    mov ax, 0x251C
    int 0x21
    pop ds
    sti
    ret

vsync_wait:
    mov dx, 0x3DA
.w1: in al, dx
    test al, 8
    jnz .w1
.w2: in al, dx
    test al, 8
    jz .w2
    ret


section .data
    
    str_bitbloom db 'BITBLOOM', 0
    str_play db 'PLAY', 0
    str_options db 'OPTIONS', 0
    str_exit db 'EXIT', 0
    str_l_bracket db '[', 0
    str_r_bracket db ']', 0
   
    menu_current_color db 0
    menu_selection_index db 0        
    menu_old_selection db 0
    menu_blink_state db 0        
    menu_blink_timer db 0        
    menu_exit_flag db 0
    menu_start_game_flag db 0      
    menu_redraw_flag db 0  

    menu_line_x1 dw 0
    menu_line_y1 dw 0
    menu_line_x2 dw 0
    menu_line_y2 dw 0
    menu_line_dx dw 0
    menu_line_dy dw 0
    menu_line_sx dw 0
    menu_line_sy dw 0
    menu_line_err dw 0
   
    menu_old_int9_off dw 0
    menu_old_int9_seg dw 0
    menu_old_int1c_off dw 0
    menu_old_int1c_seg dw 0

    mf_b: db 0x7C, 0x66, 0x66, 0x7C, 0x66, 0x66, 0x7C, 0x00
    mf_i: db 0x3C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00
    mf_t: db 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00
    mf_l: db 0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x7E, 0x00
    mf_o: db 0x3C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00
    mf_m: db 0x63, 0x77, 0x7F, 0x6B, 0x63, 0x63, 0x63, 0x00
    mf_p: db 0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x60, 0x00
    mf_a: db 0x3C, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00
    mf_y: db 0x66, 0x66, 0x66, 0x3C, 0x18, 0x18, 0x18, 0x00
    mf_n: db 0x66, 0x76, 0x7E, 0x6E, 0x66, 0x66, 0x66, 0x00
    mf_s: db 0x3E, 0x60, 0x60, 0x3C, 0x06, 0x06, 0x7C, 0x00
    mf_e: db 0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x7E, 0x00
    mf_x: db 0xC3, 0x66, 0x3C, 0x18, 0x3C, 0x66, 0xC3, 0x00
    mf_lb: db 0x1C, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1C, 0x00
    mf_rb: db 0x38, 0x08, 0x08, 0x08, 0x08, 0x08, 0x38, 0x00

    
	
    str_filename db 'IMAGE.DAT', 0
    game_file_handle dw 0
    game_start_tick_low dw 0
    game_start_tick_high dw 0
    game_last_second dw 0xFFFF
    game_last_tick dw 0
    game_seed dw 0
    game_text_color db 250

    str_timer db 'TIMER ', 0
    game_timer_str db '2:00', 0
    str_score db 'SCORE: ', 0
    game_score_buf db '000', 0
    game_score_val dw 0
    game_missed_count dw 0
	game_pause_time_store dw 0
   
    game_balloons times 5500 db 0
   
    game_balloon_sprite:
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,2,2,2,2,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,1,1,2,2,2,2,2,2,2,2,1,1,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,1,2,3,3,2,2,2,2,2,2,2,1,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,1,2,2,3,3,3,2,2,2,2,2,2,1,1,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,1,1,2,3,3,3,2,2,2,2,2,2,2,2,1,1,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,1,1,2,3,3,2,2,2,2,2,2,2,2,2,1,1,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,1,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,1,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,1,2,2,3,2,2,2,2,2,2,2,2,2,2,1,1,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,1,1,2,2,2,2,2,2,2,2,2,2,2,1,1,1,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,1,2,2,2,2,2,2,2,2,2,2,1,1,1,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,1,2,2,2,2,2,2,2,2,2,2,1,1,1,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,2,2,2,2,2,2,2,2,2,1,1,1,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,1,1,2,2,2,2,2,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,1,1,2,2,2,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    game_digit_font:
        db 0x3C, 0x66, 0x6E, 0x76, 0x66, 0x66, 0x3C, 0x00
        db 0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00
        db 0x3C, 0x66, 0x06, 0x0C, 0x18, 0x30, 0x7E, 0x00
        db 0x3C, 0x66, 0x06, 0x1C, 0x06, 0x66, 0x3C, 0x00
        db 0x0C, 0x1C, 0x3C, 0x6C, 0x7E, 0x0C, 0x0C, 0x00
        db 0x7E, 0x60, 0x7C, 0x06, 0x06, 0x66, 0x3C, 0x00
        db 0x3C, 0x60, 0x60, 0x7C, 0x66, 0x66, 0x3C, 0x00
        db 0x7E, 0x06, 0x0C, 0x18, 0x30, 0x30, 0x30, 0x00
        db 0x3C, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x3C, 0x00
        db 0x3C, 0x66, 0x66, 0x3E, 0x06, 0x0C, 0x38, 0x00
    game_colon_font: db 0x00, 0x00, 0x18, 0x18, 0x00, 0x18, 0x18, 0x00
    game_space_font: db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
   
    game_alpha_font:
        db 0x18,0x3C,0x66,0x66,0x7E,0x66,0x66,0x00
        db 0x7C,0x66,0x66,0x7C,0x66,0x66,0x7C,0x00
        db 0x3C,0x66,0x60,0x60,0x60,0x66,0x3C,0x00
        db 0x78,0x6C,0x66,0x66,0x66,0x6C,0x78,0x00
        db 0x7E,0x60,0x60,0x78,0x60,0x60,0x7E,0x00
        db 0x7E,0x60,0x60,0x78,0x60,0x60,0x60,0x00
        db 0x3C,0x66,0x60,0x6F,0x66,0x66,0x3C,0x00
        db 0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x00
        db 0x3C,0x18,0x18,0x18,0x18,0x18,0x3C,0x00
        db 0x06,0x06,0x06,0x06,0x06,0x66,0x3C,0x00
        db 0x66,0x6C,0x78,0x70,0x78,0x6C,0x66,0x00
        db 0x60,0x60,0x60,0x60,0x60,0x60,0x7E,0x00
        db 0x63,0x77,0x7F,0x6B,0x63,0x63,0x63,0x00
        db 0x66,0x76,0x7E,0x7E,0x6E,0x66,0x66,0x00
        db 0x3C,0x66,0x66,0x66,0x66,0x66,0x3C,0x00
        db 0x7C,0x66,0x66,0x7C,0x60,0x60,0x60,0x00
        db 0x3C,0x66,0x66,0x66,0x6A,0x6C,0x36,0x00
        db 0x7C,0x66,0x66,0x7C,0x6C,0x66,0x63,0x00
        db 0x3C,0x60,0x60,0x3C,0x06,0x06,0x7C,0x00
        db 0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x00
        db 0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00
        db 0x66,0x66,0x66,0x66,0x66,0x3C,0x18,0x00
        db 0x63,0x63,0x63,0x6B,0x7F,0x77,0x63,0x00
        db 0x66,0x66,0x3C,0x18,0x3C,0x66,0x66,0x00
        db 0x66,0x66,0x66,0x3C,0x18,0x18,0x18,0x00
        db 0x7E,0x06,0x0C,0x18,0x30,0x60,0x7E,0x00

    game_palette_buffer times 768 db 0

    
    str_paused  db 'PAUSED', 0
    str_resume  db 'RESUME', 0
    str_restart db 'RESTART', 0
    str_quit    db 'QUIT', 0
    pause_current_color db 0x00
    pause_selection_index db 0    
    pause_old_selection   db 0    
    pause_blink_state     db 1        
    pause_blink_timer     db 0        
    pause_exit_flag       db 0        
    pause_redraw_flag     db 1        
    pause_old_int9_off    dw 0
    pause_old_int9_seg    dw 0
    pause_old_int1c_off   dw 0
    pause_old_int1c_seg   dw 0

    pf_p: db 0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x60, 0x00
    pf_a: db 0x3C, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00
    pf_u: db 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00
    pf_s: db 0x3E, 0x60, 0x60, 0x3C, 0x06, 0x06, 0x7C, 0x00
    pf_e: db 0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x7E, 0x00
    pf_d: db 0x78, 0x6C, 0x66, 0x66, 0x66, 0x6C, 0x78, 0x00
    pf_r: db 0x7C, 0x66, 0x66, 0x7C, 0x6C, 0x66, 0x63, 0x00
    pf_m: db 0x63, 0x77, 0x7F, 0x6B, 0x63, 0x63, 0x63, 0x00
    pf_t: db 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00
    pf_q: db 0x3C, 0x66, 0x66, 0x66, 0x6C, 0x36, 0x1C, 0x00
    pf_i: db 0x3C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00
    pf_lb: db 0x1C, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1C, 0x00
    pf_rb: db 0x38, 0x08, 0x08, 0x08, 0x08, 0x08, 0x38, 0x00

    
    str_gameover   db 'GAME OVER', 0
    gov_msg_score  db 'SCORE: 00000', 0
    str_tryagain   db 'TRY AGAIN', 0
    str_mainmenu   db 'BACK TO MAIN', 0
    gov_selection_index db 0        
    gov_blink_state     db 0        
    gov_blink_timer     db 0        
    gov_exit_flag       db 0        
    gov_redraw_flag     db 1        
    gov_old_int9_off    dw 0
    gov_old_int9_seg    dw 0
    gov_old_int1c_off   dw 0
    gov_old_int1c_seg   dw 0
    gov_current_color db 0

    gf_g: db 0x3C, 0x66, 0x60, 0x6E, 0x66, 0x66, 0x3E, 0x00
    gf_a: db 0x3C, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00
    gf_m: db 0x63, 0x77, 0x7F, 0x6B, 0x63, 0x63, 0x63, 0x00
    gf_e: db 0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x7E, 0x00
    gf_o: db 0x3C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00
    gf_v: db 0x63, 0x63, 0x63, 0x36, 0x36, 0x1C, 0x1C, 0x00
    gf_r: db 0x7C, 0x66, 0x66, 0x7C, 0x6C, 0x66, 0x63, 0x00
    gf_s: db 0x3C, 0x66, 0x60, 0x3C, 0x06, 0x66, 0x3C, 0x00
    gf_c: db 0x3C, 0x66, 0x60, 0x60, 0x60, 0x66, 0x3C, 0x00
    gf_0: db 0x3C, 0x66, 0x6E, 0x76, 0x66, 0x66, 0x3C, 0x00
    gf_t: db 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00
    gf_y: db 0x66, 0x66, 0x66, 0x3C, 0x18, 0x18, 0x18, 0x00
    gf_i: db 0x3C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00
    gf_n: db 0x66, 0x76, 0x7E, 0x6E, 0x66, 0x66, 0x66, 0x00
    gf_b: db 0x7C, 0x66, 0x66, 0x7C, 0x66, 0x66, 0x7C, 0x00
    gf_k: db 0x66, 0x6C, 0x78, 0x70, 0x78, 0x6C, 0x66, 0x00
    gf_cl: db 0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x00