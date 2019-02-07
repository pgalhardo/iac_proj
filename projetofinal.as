;===============================================================================
;       IAC1718_Proj_part2
;       2017 
;       Pedro Galhardo 
;       Maria Martins
;
;       MasterMind
;===============================================================================

; ZONA I: Definicao de constantes
 
Mask            EQU     1000000000010110b
 
DISP7SEG_0      EQU     FFF0h
LEDS            EQU     FFF8h
 
Int1_6_15_mask  EQU     1000000001111110b
Int10_mask      EQU     0000010000000000b
 
InterruptMask   EQU     FFFAh
 
FIM_TEXTO       EQU     '@'
NOVA_LINHA      EQU     '$'  
CENTRAR         EQU     '&'                  
 
TimerValue      EQU     FFF6h
TimerControl    EQU     FFF7h
   
; Porto que permite escrever um dado caracter na janela de texto

IO_WRITE        EQU     FFFEh  
 
; Porto que permite posicionar o cursor na janela de texto,
; indicando onde sera escrito o proximo caracter.
 
IO_CURSOR       EQU     FFFCh
SP_INICIAL      EQU     FDFFh
 
LCD_WRITE       EQU     FFF5h
LCD_CONTROL     EQU     FFF4h
STR_END         EQU     0000h      
 
; Tabela de interrupcoes
               
                ORIG    FE01h
 
INT1            WORD    INT1F
INT2            WORD    INT2F
INT3            WORD    INT3F
INT4            WORD    INT4F
INT5            WORD    INT5F
INT6            WORD    INT6F
 
                ORIG    FE0Ah
 
INT10           WORD    INT10F
               
                ORIG    FE0Fh
 
INT15           WORD    TimerF
 
; ZONA II: definicao de variaveis
 
                ORIG    8000h
 
CHAVE           WORD    000000000000b           ; Sequencia Secreta gerada aleatoriamente
PALPITE         WORD    000000000000b           ; Sequencia introduzida pelo jogador
RESULTADO       WORD    000000b                 ; XXX | YYY -> XXX : Numero de 'X's, YYY: Numero de 'O's                      
DIG_PALPITE     WORD    0                       ; Numero de digitos em PALPITE
JOGADA          WORD    0                      
IO_POS          WORD    0301h                   ; Posicao dinamica do cursor na janela
Tempo           WORD    FFFFh                   ; Tempo a apresentar nos LEDs
LastRandom      WORD    0
HighScore       WORD    0
GAME_STATE      WORD    0000h                   ; Estado do jogo (0000h - Parado e != 0000h - Jogador a jogar) 

WELCOME         STR     '   WELCOME TO      MASTERMIND', STR_END
HS_Write        STR     '  ' , STR_END
HS              STR     'Highscore:   ' , STR_END
Tabela_sep      STR     '&+--------------------------------+',FIM_TEXTO
Tabela_header   STR     '&+--------------------------------+$&| JOGADA | TENTATIVA | RESULTADO |$&+--------------------------------+',FIM_TEXTO
Tabela_lat      STR     '&|        |           |           |',FIM_TEXTO
Tabela_init     STR     '&|        |           |           |',FIM_TEXTO

Venceu          STR     '&______  ___  ______  ___  ______ _____ _   _  _____ $&| ___ \/ _ \ | ___ \/ _ \ | ___ \  ___| \ | |/  ___|$&| |_/ / /_\ \| |_/ / /_\ \| |_/ / |__ |  \| |\ `--. $&|  __/|  _  ||    /|  _  || ___ \  __|| . ` | `--. \$&| |   | | | || |\ \| | | || |_/ / |___| |\  |/\__/ /$&\_|   \_| |_/\_| \_\_| |_/\____/\____/\_| \_/\____/',FIM_TEXTO
Perdeu          STR     '& _____   ___  ___  ___ _____   _____  _   _ ___________ $&|  __ \ / _ \ |  \/  ||  ___| |  _  || | | |  ___| ___ \$&| |  \// /_\ \| .  . || |__   | | | || | | | |__ | |_/ /$&| | __ |  _  || |\/| ||  __|  | | | || | | |  __||    / $&| |_\ \| | | || |  | || |___  \ \_/ /\ \_/ / |___| |\ \ $& \____/\_| |_/\_|  |_/\____/   \___/  \___/\____/\_| \_|', FIM_TEXTO
MM              STR     '___  ___  ___   _____ _____ ___________  ___  ________ _   _______ $|  \/  | / _ \ /  ___|_   _|  ___| ___ \ |  \/  |_   _| \ | |  _  \$| .  . |/ /_\ \\ `--.  | | | |__ | |_/ / | .  . | | | |  \| | | | |$| |\/| ||  _  | `--. \ | | |  __||    /  | |\/| | | | | . ` | | | |$| |  | || | | |/\__/ / | | | |___| |\ \  | |  | |_| |_| |\  | |/ /$\_|  |_/\_| |_/\____/  \_/ \____/\_| \_| \_|  |_/\___/\_| \_/___/',FIM_TEXTO
Limpa           STR     '                                                                               ',FIM_TEXTO
Wait            STR     'Carregue no botao IA para iniciar',FIM_TEXTO
NewGame         STR     '&Fim do Jogo. Carregue em IA para recomecar',FIM_TEXTO
 
; ZONA III: codigo
 
                ORIG    0000h
 
Inicio:         MOV     R7, SP_INICIAL
                MOV     SP, R7                  ; Inicializacao do Stack Pointer
                MOV     R1, Int10_mask
                MOV     M[InterruptMask], R1    ; Permite a interrupcao 10
                MOV     R1, 0001h
                MOV     M[TimerValue], R1
                CALL    CURSOR_INIT             ; Inicializacao do cursor
                
                PUSH    00h                     ; 0 = Linha | 1 = Coluna
                PUSH    WELCOME
                CALL    LCD_STR 

                PUSH    0           		; Numero da jogada atual
                PUSH    10                      ; Base (10 / 16)
                CALL    DISP7SEG     
 				
; ==============================================================================
;           Main        Ciclo de espera inicial
; ==============================================================================
 
Main:           PUSH    MM
                PUSH    0306h
                CALL    Print                   ; Print MASTER MIND
                PUSH    Wait
                PUSH    0D17h
                CALL    Print                   ; Print 'Carregue no botao IA ...'
 
                ENI
                
MainWait:       INC     M[LastRandom]           ; Prepara a geracao do numero aleatorio
                CMP     M[GAME_STATE], R0  
                BR.Z    MainWait  
               
; ==============================================================================
;          Start        Inicio do jogo
; ==============================================================================                                
               
Start:          MOV     R1, Int1_6_15_mask
                MOV     M[InterruptMask], R1    ; Permite as interrupcoes 1-6, 15
                
                CMP     M[HighScore], R0
                BR.Z    S_SK1

                PUSH    01h                     ; 0 = Linha | 1 = Coluna
                PUSH    HS
                CALL    LCD_STR                    
                PUSH    0Ch                     ; 0 = Linha | C = Coluna
                PUSH    HS_Write                
                CALL    LCD_STR
 
S_SK1:          CALL    ResetVar                ; Reset das Variaveis
                INC     M[JOGADA]
 
                CALL    Gen_Num                 ; Gera um numero aleatorio 12 bits
                CALL    ResetJanela             ; Limpa a janela de texto
 
                PUSH    Tabela_header      
                PUSH    0001h            
                CALL    Print                   ; Topo da Tabela, na posicao 0001h
               
                PUSH    M[JOGADA]               ; Numero da jogada atual
                PUSH    10                      ; Base (10 / 16)
                CALL    DISP7SEG
 
                BR      Espera  
 
; ==============================================================================
;            Inp        Inicio de uma nova jogada
; ==============================================================================            
 
Inp:            MOV     M[RESULTADO], R0        ; Reinicia o valor de RESULTADO
                MOV     M[PALPITE], R0          ; Reinicia o valor de PALPITE
                MOV     M[DIG_PALPITE], R0      ; Reinicia o valor de DIG_PALPITE
 
                PUSH    M[JOGADA]               ; Numero da jogada atual
                PUSH    10                      ; Base (10 / 16)
                CALL    DISP7SEG
 
                MOV     R1, FFFFh               ; Restaura o tempo
                MOV     M[Tempo], R1
 
; ==============================================================================
;         Espera        Ciclo de espera pela introducao da tentativa
; ==============================================================================
 
Espera:         CALL    IO_Gen                  ; Rotina que coloca uma linha vazia,
                                                ; que contem apenas o numero da jogada
                MOV     R1, 0001h
                MOV     M[TimerControl], R1     ; Ativa o temporizador
 
LedUpdate:      MOV     R6, M[Tempo]
                MOV     M[LEDS], R6             ; Atualiza o estado dos LEDs
                CMP     R6, R0                  ; Terminou o tempo?
                JMP.NZ  Salta0                  ; Nao? Entao segue

                CALL    IO_Update               ; Sim? Entao perdeu...
                JMP     Final
               
Salta0:         MOV     R5, M[DIG_PALPITE]      ; PALPITE ja contem '4 digitos'?
                CMP     R5, 4
                BR.Z    Processa                ; Sim? Entao passa a fase de processamento                                        
                BR      LedUpdate               ; Nao? Entao continua no ciclo
 
; ==============================================================================
;       Processa        Fase de Comparacao e apresentacao do resultado
; ==============================================================================
 
Processa:       MOV     R1, M[CHAVE]            ; Caso CHAVE == PALPITE
                CMP     R1, M[PALPITE]          ; Nao e necessaria qualquer verificacao
                JMP.Z   Parabens                ; Iguais? Entao ganhou!
                
                PUSH    M[CHAVE]                
                PUSH    M[PALPITE]
                CALL    Verifica                ; Compara a CHAVE com o PALPITE
               
                CALL    IO_Update               ; Preenche a linha incompleta        
                CALL    IO_Gen                  ; Gera uma linha incomleta que contem o numero da jogada
                     
                MOV     R1, 12
                CMP     M[JOGADA], R1           ; Esgotou as jogadas?
                BR.Z    Final                   ; Sim? Entao perdeu...
                
                CALL    Desce_Linha             ; Desce uma linha na janela
                INC     M[JOGADA]               ; Incrementa a jogada
                CALL    ResetTab                ; Reset da Linha da tabela para a original
 
                JMP     Inp                     ; Inicio de uma nova tentativa
 
; ==============================================================================
;          Final        Se chegou ao fim do tempo ou do numero de jogadas...
; ==============================================================================
 
Final:          MOV     R1, Int10_mask
                MOV     M[InterruptMask], R1    ; Ativa apenas IA
 
                CALL    Desce_Linha            
                PUSH    Perdeu          
                PUSH    M[IO_POS]            
                CALL    Print                   ; Print PERDEU
               
                MOV     R5, 6
Desce0:         CALL    Desce_Linha             ; Desce 6 linhas
                CMP     R5, R0
                BR.Z    Ciclo0
                DEC     R5
                BR      Desce0            
 
Ciclo0:         PUSH    NewGame                
                PUSH    M[IO_POS]            
                CALL    Print                   ; Print 'Fim do Jogo'
                
                COM     M[GAME_STATE]           ; GAME_STATE = 0
                JMP     MainWait 
 
; ==============================================================================
;       Parabens        Se ganhou!
; ==============================================================================
 
Parabens:       MOV     R1, Int10_mask
                MOV     M[InterruptMask], R1    ; Ativa apenas IA
 
                MOV     R1, 100000b
                MOV     M[RESULTADO], R1        ; Resultado = 'XXXX'
               
                CALL    IO_Update
                CALL    Desce_Linha
                PUSH    Venceu
                PUSH    M[IO_POS]
                CALL    Print                   ; Print PARABENS      
               
                MOV     R5, 6                   ; Desce 6 linhas
Desce1:         CALL    Desce_Linha
                CMP     R5, R0
                BR.Z    Ciclo1
                DEC     R5
                BR      Desce1            
 
Ciclo1:         PUSH    NewGame          
                PUSH    M[IO_POS]            
                CALL    Print                   ; Print 'Fim do Jogo'
 
                MOV     R1, M[JOGADA]
                CMP     M[HighScore], R0        ; Nova melhor pontuacao?
                BR.Z    ColocaHS                ; Sim? Entao atualiza M[HighScore]
                CMP     R1, M[HighScore]
                BR.P    Ignore                  ; Nao? Entao segue
 
ColocaHS:       MOV     M[HighScore], R1
                MOV     R2, 10
                DIV     R1, R2
                ADD     R1, 48                  ; Converte X para 'X'
                ADD     R2, 48                  ; Converte Y para 'Y'            
                MOV     R3, HS_Write
                MOV     M[R3], R1               ; Coloca o primero dig. na linha          
                MOV     M[R3+1], R2             ; Coloca o segundo dig. na linha
               
Ignore:         COM     M[GAME_STATE]           ; GAME_STATE = 0
                JMP     MainWait 
                
; ==============================================================================
;          INTxF        Definicao das acoes de cada botao
;         TimerF        Definicao da acao do temporizador
; ==============================================================================                
 
INT1F:          MOV     R1, 1                   ; Associa a I1 o valor 1
                BR      OP
INT2F:          MOV     R1, 2                   ; Associa a I2 o valor 2
                BR      OP
INT3F:          MOV     R1, 3                   ; Associa a I3 o valor 3
                BR      OP
INT4F:          MOV     R1, 4                   ; Associa a I4 o valor 4
                BR      OP
INT5F:          MOV     R1, 5                   ; Associa a I5 o valor 5
                BR      OP
INT6F:          MOV     R1, 6                   ; Associa a I6 o valor 6
 
OP:             MOV     R3, M[PALPITE]          
                MOV     R2, M[DIG_PALPITE]      
                CMP     R2, 3                   ; PALPITE ja contem '4 digitos'?
                ROL     R3, 3                   ; Coloca a primeira posicao livre
                ADD     R3, R1                  ; Acrescenta o valor de Ix
                MOV     M[PALPITE], R3          ; Coloca em M[PALPITE] o seu novo valor
                INC     M[DIG_PALPITE]          ; Atualiza o numero de digitos de PALPITE
                CALL    IO_Update               ; Atualiza a linha da tabela
                RTI
 
INT10F:         COM     M[GAME_STATE]           ; GAME_STATE = 1
                RTI

TimerF:         MOV     R1, 0001h
                MOV     M[TimerValue], R1       ; Restaura o temporizador
                SHR     M[Tempo], 1             ; Permite desligar o LED mais a direita
                MOV     R1, 0001h
                MOV     M[TimerControl], R1     ; Ativa o temporizador
                RTI

; ==============================================================================
;       Rotinas do JOGO
;
;       As rotinas seguintes destinam-se a serem utilizadas somente para o 
;       funcionamento deste jogo.       
; ==============================================================================

; ==============================================================================                
;       Verifica        Compara a CHAVE com o PALPITE
;       Entradas        M[CHAVE], M[PALPITE]
;         Saidas        ---
;        Efeitos        M[RESULTADO]
; ==============================================================================      
 
Verifica:       MOV     R1, M[SP + 3]           ; Recebe a CHAVE  
                MOV     R2, M[SP + 2]           ; Recebe o PALPITE
                MOV     R6, 4                  
V_Loop:         MOV     R3, R1                  
                MOV     R4, R2                  
                AND     R3, 7                   ; Isola os ultimos 3 bits da CHAVE
                AND     R4, 7                   ; Isola os ultimos 3 bits do PALPITE
                PUSH    R3                      
                PUSH    R4                      
                ROR     R1, 3                   ; Acede ao proximo digito da CHAVE
                ROR     R2, 3                   ; Acede ao proximo digito do PALPITE
                DEC     R6                      
                BR.NZ   V_Loop                  ; Isolou todos os numeros?
                MOV     R5, R0                  ; R5 -> Vai conter o RESULTADO
                MOV     R1, SP                  
                MOV     R6, 4                  
V_Loop2:        MOV     R3, M[R1 + 1]           ; Recebe o digito do PALPITE a comparar
                MOV     R4, M[R1 + 2]           ; Recebe o digito da CHAVE a comparar
                CMP     R3, R4                  
                CALL.Z  Add_X                   ; Sao iguais? Entao representam um 'X'
                ADD     R1, 2                   ; Aponta para os proximos numeros
                DEC     R6                      
                BR.NZ   V_Loop2                 ; Verificou todos os 'X's ? Entao segue            
                MOV     R7, 4                   ; Contador 'Exterior'
                MOV     R1, SP
V_Loop3:        MOV     R2, SP
                MOV     R6, 4                   ; Contador 'Interior'
V_Loop4:        MOV     R3, M[R1 + 1]           ; Recebe o digito do PALPITE a comparar
                MOV     R4, M[R2 + 2]           ; Recebe o digito da CHAVE a comparar
                CMP     R3, R4                  ; Sao iguais? Entao pode representar um 'O'
                CALL.Z  Add_O
                ADD     R2, 2                   ; Aponta para os proximos numeros
                DEC     R6                      
                BR.NZ   V_Loop4                 ; Contador 'Interior' > 0?
                ADD     R1, 2                   ; Nao? Entao recomeca, com outras combinacoes
                DEC     R7      
                BR.NZ   V_Loop3                 ; Contador 'Exterior' > 0?
                MOV     R6, 8                   ; Nao? Entao termina, limpando o Stack
V_POP:          POP     R1
                DEC     R6
                BR.NZ   V_POP                   ; Todos os numeros foram descartados?
                MOV     M[RESULTADO], R5        ; Coloca o resultado obtido em RESULTADO
                RETN    2  
Add_X:          ADD     R5, 1000b               ; Incrementa a contagem de 'X's
                MOV     M[R1 + 1], R0           ; Permite ignorar em futuras comparacoes
                MOV     M[R1 + 2], R0           ; Permite ignorar em futuras comparacoes
                RET                
Add_O:          CMP     R3, R0                  ; Se R3 == 0 entao ignora
                BR.Z    AO_Ret                  ; pois ja foi correspondido
                INC     R5                      ; Caso contrario, adiciona um 'O'
                MOV     M[R1 + 1], R0           ; Permite ignorar em futuras comparacoes
                MOV     M[R2 + 2], R0           ; Permite ignorar em futuras comparacoes
AO_Ret:         RET

; ==============================================================================                
;         IO_Gen        Gera uma linha vazia, com apenas o numero da jogada
;       Entradas        ---
;         Saidas        ---
;        Efeitos        Coloca na janela uma nova linha da tabela
; ============================================================================== 
 
IO_Gen:         PUSH    R1                      
                PUSH    R2
                PUSH    R3
                MOV     R1, M[JOGADA]           ; Numero a processar
                MOV     R2, 10
                DIV     R1, R2
                ADD     R1, 48                  ; Converte X para 'X'
                ADD     R2, 48                  ; Converte Y para 'Y'            
                MOV     R3, Tabela_lat
                MOV     M[R3+5], R1             ; Coloca o primero dig. na linha
                MOV     M[R3+6], R2             ; Coloca o segundo dig. na linha
                POP     R3
                POP     R2
                POP     R1                      
                PUSH    Tabela_lat
                PUSH    M[IO_POS]
                CALL    Print                   ; Print da linha incompleta
                RET
 
; ==============================================================================                
;      IO_Update        Modifica a ultima linha da tabela
;       Entradas        ---
;         Saidas        ---
;        Efeitos        M[Tabela_lat]
; ============================================================================== 

IO_Update:      PUSH    R1
                PUSH    R2
                PUSH    R3
                PUSH    R4
                CALL    Converte                
                PUSH    Tabela_lat
                PUSH    M[IO_POS]
                CALL    Print                   ; Print da linha completa      
                POP     R4
                POP     R3
                POP     R2
                POP     R1
                RET 

Converte:       PUSH    M[PALPITE]              ; Preserva M[PALPITE]
                MOV     R1, 000000000111b      
                MOV     R2, Tabela_lat          ; Ponteiro para o inicio da linha
                MOV     R4, R0
                ADD     R2, 17                  ; Avança 17 colunas na linha      
PutJog:         MOV     R3, M[PALPITE]
                AND     R3, R1                  ; Isola o numero a representar
                CMP     R3, R0                  ; E zero?
                BR.Z    Add_Space               ; Sim? Entao escreve um espaco
                ADD     R3, 48                  ; Nao? Converte X para 'X'
                BR      Insert                  
Add_Space:      MOV     R3, 32
Insert:         MOV     M[R2], R3               ; Coloca na linha
                CMP     R4, 3                   
                BR.Z    PutRes                 
                DEC     R2
                INC     R4
                ROR     M[PALPITE], 3
                BR      PutJog
                               
PutRes:         MOV     R2, Tabela_lat          ; Ponteiro para o inicio da linha
                ADD     R2, 26                  ; Avanca 26 colunas na linha
                MOV     R4, 111000b
                MOV     R5, 4
                MOV     R1, M[RESULTADO]
                AND     R1, R4
LoopX:          CMP     R1, R0                  ; Existem 'X's por colocar?
                BR.Z    Pre_LoopO               ; Nao? Entao verifica se existem 'O's
                CALL    Put_X                   ; Sim? Entao coloca um 'X' na linha
                DEC     R5
                SUB     R1, 1000b
                BR      LoopX
 
Pre_LoopO:      MOV     R1, M[RESULTADO]
                ROR     R4, 3
                AND     R1, R4
LoopO:          CMP     R1, R0                  ; Existem 'O's por colocar?
                BR.Z    LastLoop                ; Nao? Entao preenche com '-'s
                CALL    Put_O                   ; Sim? Entao coloca um 'O' na linha
                DEC     R5
                SUB     R1, 1
                BR      LoopO

LastLoop:       CMP     R5, R0                  ; Existem '-'s por colocar?
                BR.Z    Out0                    ; Nao? Entao sai
                MOV     R3, '-'             ; Sim? Entao coloca um '-' na linha
                MOV     M[R2], R3
                INC     R2
                DEC     R5
                BR      LastLoop
 
Put_X:          PUSH    R1
                MOV     R1, 'X'
                MOV     M[R2], R1               ; Coloca um 'X' na posicao atual
                INC     R2
                POP     R1
                RET
Put_O:          PUSH    R1
                MOV     R1, 'O'
                MOV     M[R2], R1               ; Coloca um 'O' na posicao atual
                INC     R2
                POP     R1
                RET
Out0:           POP     M[PALPITE]              ; Restaura M[PALPITE]
                RET

; ==============================================================================                
;       ResetVar        Reinicializacao de variaveis
;       Entradas        ---
;         Saidas        ---
;        Efeitos        Zera as variaveis necessarias para recomecar o jogo
; ============================================================================== 
 
ResetVar:       MOV     M[PALPITE], R0
                MOV     M[RESULTADO], R0
                MOV     M[DIG_PALPITE], R0
                MOV     M[JOGADA], R0
               
                MOV     R1, FFFFh
                MOV     M[Tempo], R1
                MOV     R1, DISP7SEG_0
                MOV     M[R1], R0
                INC     R1
                MOV     M[R1], R0
 
                MOV     R1, 0301h
                MOV     M[IO_POS], R1
                CALL    ResetTab                  
                RET

; ==============================================================================                
;       ResetTab        Reinicializacao da linha da tabela
;       Entradas        ---
;         Saidas        ---
;        Efeitos        Restaura a linha da tabela ao seu estado original
; ============================================================================== 
 
ResetTab:       MOV     R1, Tabela_init         ; Ponteiro para o inicio da linha inicial
                MOV     R3, Tabela_lat          ; Ponteiro para o inicio da linha a inicializar
                MOV     R4, R0
Reg:            MOV     R2, M[R1]
                MOV     M[R3], R2               ; Inicializa coluna
                CMP     R4, 34                  ; Terminou?
                BR.Z    Exit
                INC     R1                      ; Incrementa coluna da linha inicial
                INC     R3                      ; Incrementa coluna da linha a inicializar
                INC     R4                      ; Incrementa o contador
                BR      Reg                     ; Repete
Exit:           RET

; ==============================================================================                
;    ResetJanela        Reinicializacao da janela de texto
;       Entradas        ---
;         Saidas        ---
;        Efeitos        Imprime 24 linhas em branco para limpar a janela
; ============================================================================== 
 
ResetJanela:    PUSH    R1
                PUSH    R2
                PUSH    R3
                PUSH    M[IO_POS]
                           
                MOV     M[IO_POS], R0           ; Coloca o cursor na primera linha (coord. 0000h)
Loop1:          PUSH    Limpa
                PUSH    M[IO_POS]
                CALL    Print                   ; Escreve uma linha em branco
                MOV     R2, M[IO_POS]
                CMP     R2, 1800h               ; Escreveu em todas as linhas?
                BR.Z    Out1                    ; Sim? Entao sai
                CALL    Desce_Linha             
                BR      Loop1
 
Out1:           POP     M[IO_POS]
                POP     R3
                POP     R2
                POP     R1
                RET

; ==============================================================================
;        Get_Num        Gera um numero aleatorio de 12 bits
;       Entradas        ----
;         Saidas        ----
;        Efeitos        M[CHAVE], M[LastRandom]
; ==============================================================================
 
Gen_Num:        PUSH    R1
                PUSH    R2
                PUSH    R3
                PUSH    R4
                PUSH    R5
                MOV     M[CHAVE], R0            
                MOV     R3, CHAVE               ; Ponteiro para CHAVE
                MOV     R4, 1                   ; Contador
 
Gen:            CALL    Random                  ; Rotina que gera um numero entre 0 e R2-1                  
                MOV     R1, M[LastRandom]
                MOV     R2, 6                   ; Numero maximo a obter [de 0 a R2-1 ]
                DIV     R1, R2                  ; executa a divisao inteira de R1 por R2,
                                                ; deixando o resultado em R1 e o resto em R2
                INC     R2                      ; Incrementa, pois o numero gerado
                                                ; e entre 0 e o valor de R2 - 1 e queremos um numero de 1 a 6                                      
                ADD     M[R3], R2
                CMP     R4, 4                   ; Terminou?
                BR.Z    Saida                   ; Sim? Entao sai
                MOV     R5, M[R3]
                ROL     R5, 3
                MOV     M[R3], R5
                INC     R4
                BR      Gen                     ; Gera outro numero
 
Saida:          POP     R5
                POP     R4
                POP     R3
                POP     R2
                POP     R1
                RET                    
 
Random:         PUSH    R1
                MOV     R1, M[LastRandom]
                TEST    R1, 0001h                
                BR.NZ   Random2        
                ROR     M[LastRandom], 1
                POP     R1
                RET
Random2:        MOV     R1, Mask
                XOR     M[LastRandom], R1
                ROR     M[LastRandom], 1
                POP     R1
                RET

; ==============================================================================
;       Rotinas REUTILIZAVEIS
;
;       As rotinas seguintes foram preparadas para permitir a sua 
;       utilizacao neste jogo, bem como em aplicacoes futuras com 
;       necessidades semelhantes.      
; ==============================================================================
               
; ==============================================================================
;          Print        Escreve uma string, eventualmente centrada, caso pedido
;       Entradas        Posicao (memoria) do primeiro caracter; Posicao do cursor
;         Saidas        ---
;        Efeitos        Coloca a string pretendida na janela de texto
; ==============================================================================
 
Print:          PUSH    R1
                PUSH    R2
                PUSH    R3
               
                MOV     R2, M[SP+6]             ; Endereco do 1o caracter a escrever
                MOV     R3, M[SP+5]             ; Posicao do cursor
P_PC:           MOV     R1, M[R2]               ; Caracter a escrever
                CMP     R1, CENTRAR
                JMP.Z   Centra              
                CMP     R1, NOVA_LINHA          ; Nova linha
                BR.NZ   P_FT          
                MOV     R3, M[SP+5]             ; Posicao inicial da linha
                ADD     R3, 0100h               ; Incrementa uma linha ao Cursor
                MOV     M[SP+5], R3             ; Guarda a posicao da nova linha
                INC     R2                      ; Proximo caracter
                JMP     P_PC
                MOV     R1, M[R2]
P_FT:           CMP     R1, FIM_TEXTO           ; String terminou? Sim? Entao sai
                BR.Z    P_F                     ; Nao? Escreve o caracter
                PUSH    R1
                PUSH    R3
                CALL    Print_Char
                INC     R2                      ; Endereco do proximo caracter
                INC     R3                      ; Proxima coluna
                BR      P_PC
P_F:            POP     R3
                POP     R2
                POP     R1
                RETN    2
               
Centra:         PUSH    R5
                PUSH    R6
                PUSH    R7
                MOV     R6, R0
L1:             INC     R2
                MOV     R1, M[R2]               ; Caracter a escrever
                CMP     R1, NOVA_LINHA          ; Nova linha?
                BR.Z    P_FT2
                CMP     R1, FIM_TEXTO           ; Terminou?
                BR.Z    P_FT2
                INC     R6
                BR      L1
P_FT2:          SUB     R2, R6
                MOV     R7, 2                  
                DIV     R6, R7                  ; Comprimento da string / 2
                MOV     R5, 40                  ; R5 = Meio do ecran
                SUB     R5, R6                  ; R5 = R5 - string / 2            
                OR      R3, R5                  ; Actualiza Posicao do cursor
                MOV     M[SP+5], R6      
                POP     R7
                POP     R6
                POP     R5
                JMP     P_PC

; ==============================================================================                
;     Print_Char        Escreve um caracter
;       Entradas        Caracter; Posicao
;         Saidas        ---
;        Efeitos        M[IO_CURSOR], M[IO_WRITE]
; ==============================================================================
 
Print_Char:     PUSH    R1
                PUSH    R2
                MOV     R1, M[SP+5]             ; GET - Caracter
                MOV     R2, M[SP+4]             ; GET - Posicao
                MOV     M[IO_CURSOR], R2        ; SET - Posicao
                MOV     M[IO_WRITE], R1         ; SET - Escreve Caracter
                POP     R2
                POP     R1
                RETN    2  
               
CURSOR_INIT:    PUSH    R1                      
                MOV     R1, FFFFh
                MOV     M[IO_CURSOR], R1        ; Inicializa o Cursor
                POP     R1      
                RET
  
; ==============================================================================                
;    Desce_Linha        Passa para a linha seguinte da janela
;       Entradas        ---
;         Saidas        ---
;        Efeitos        Coloca o cursor na linha seguinte, mantendo a coluna
; ==============================================================================
 
Desce_Linha:    PUSH    R1
                MOV     R1, M[IO_POS]
                ADD     R1, 0100h               ; LINHA += 1
                MOV     M[IO_POS], R1           ; Passa para a LINHA seguinte
                POP     R1
                RET
  
; ==============================================================================
;        LCD_STR        Escreve uma string no LCD
;       Entradas        Endereco da String; Posicao do Cursor
;         Saidas        ---
;        Efeitos        ---
; ==============================================================================
 
LCD_STR:        PUSH    R1
                PUSH    R2
                PUSH    R3                
                MOV     R1, M[SP+5]             ; GET String
                MOV     R2, M[SP+6]             ; GET Posicao
                OR      R2, A700h                
Char:           MOV     R3, M[R1]               ; GET Caracter
                CMP     R3, STR_END             ; Terminou?
                BR.Z    LCD_Exit                ; Sim? Entao sai
                PUSH    R2                      ; Prepara a posicao
                PUSH    R3                      ; Prepara o caracter
                CALL    LCD_CHAR
                POP     R2
                INC     R1                      ; Caracter seguinte
                INC     R2                      ; Posicao seguinte
                BR      Char
LCD_Exit:       POP     R3
                POP     R2
                POP     R1
                RETN    2
 
; ==============================================================================
;       LCD_CHAR        Escreve um caracter no LCD
;       Entradas        Cursor, caracter
;         Saidas        Cursor (pilha)
;        Efeitos        M[LCD_CONTROL], M[LCD_WRITE]
; ==============================================================================

LCD_CHAR:       PUSH    R1
                PUSH    R2
                MOV     R1, M[SP+4]             ; GET Caracter
                MOV     R2, M[SP+5]             ; GET Posicao
                MOV     M[LCD_CONTROL], R2      ; SET Posicao
                MOV     M[LCD_WRITE], R1        ; SET Posicao
                POP     R2
                POP     R1
                RETN    1
 
; ==============================================================================
;       DISP7SEG        Escreve numeros no DISP7SEG
;       Entradas        Numero, base (10, 16)
;         Saidas        ---
;        Efeitos        ---
; ==============================================================================
 
DISP7SEG:       PUSH    R1
                PUSH    R2
                PUSH    R5
                MOV     R5, DISP7SEG_0          ; Ponteiro para Display 0
                MOV     R1, M[SP + 6]           ; GET Numero a escrever
                
DISP7_Loop:     MOV     R2, M[SP + 5]           ; GET Base a representar
                DIV     R1, R2
                MOV     M[R5], R2               ; Escreve no Display 0
                INC     R5                      ; Aponta para o Display 1
                CMP     R1, M[SP + 5]           ; Numero > Base?
                BR.C    DISP7_Loop              ; Sim? Entao continua
                MOV     M[R5], R1                
                POP     R5
                POP     R2
                POP     R1
                RETN    2  
 