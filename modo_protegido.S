.code16         /*Como estamos en modo real, utilizamos segmentos de 16 bits*/
cli             /*Deshabilitamos las interrupciones*/
ljmp $0, $1f
1:
xor %ax, %ax    /*limpiamos todos los registros de proposito gral.*/

mov %ax, %ds
mov %ax, %es
mov %ax, %fs
mov %ax, %gs
mov %ax, %bp
mov %ax, %ss
mov %bp, %sp

/*Dado que en el modo protegido ya no podemos hacer uso de las interrupciones de la bios para mostrar en pantalla, tenemos que usar la salida VGA*/

/*--LIMPIAMOS LA PANTALLA*--/

/*Guardamos los registros de proposito gral en la pila, para poder modificar su valor*/
push %ax
push %bx
push %cx
push %dx

/*Desplaza hacia arriba un número determinado de líneas en la ventana especificada mediante los registros CX y DX. Las líneas desplazadas, quedan vacías, rellenándose con blancos. El color utilizado en estas líneas vacías se indica mediante el registro BH.*/
mov $0x0600, %ax    /*movemos el valor 06h a ax, para luego llamar a la interrupcion 10. (la funcion 06h es para Desplazar líneas de texto hacia arriba)*/
                    /*AL = Número de líneas a desplazar. Si AL=0, se borra toda la ventana seleccionada mediante los registros CX y DX*/
mov $0x7, %bh       /*BH = Atributo a usar en las líneas borradas.*/    
mov $0x0, %cx       /*CH = Línea donde comienza la ventana de texto. CL = Columna donde comienza la ventana de texto.*/
mov $0x184f, %dx    /*DH = Línea donde acaba la ventana de texto. DL = Columna donde acaba la ventana de texto.*/

int $0x10

/*Recuperamos los registros de proposito gral de la pila*/
pop %dx
pop %cx
pop %bx
pop %ax                

/*Empezamos con el modo protegido.*/
.equ CODE_SEG, 8
.equ DATA_SEG, gdt_data - gdt_start

/*Cargamos el descriptor de la gdt. "Le decimos al procesador, donde está la tabla de descriptores globales"*/
lgdt gdt_descriptor

/*Habilitamos el modo protegido, poniendo a 1 el bit 0 del registro de control CR0.*/
 mov %cr0, %eax
 orl $0x1, %eax
 mov %eax, %cr0

/*Saltamos hacia la etiqueta protected_mode. Utilizamos como registro de segmento: CS (segmento de codigo), y como desplazamiento la etiqueta: protected_mode*/
 ljmp $CODE_SEG, $protected_mode


/*Tabla de descriptores Globales*/

/*La primera entrada de la tabla es el descriptor nulo, el procesador no usa este descriptor. No se genera una excepcion cuando un registro de segmento que no sea CS o SS se carga con el "selector nulo"*/
/*sin embargo si se genera una excepcion cuando se intenta cargar un registro de segmento cs o ss, con el selector nulo.*/

/*Cada descriptor de segmento ocupa 8 bytes de la tabla de descriptores globales.*/
/*Dentro de esos 8 bytes se encuentran: base, limite, atributos, tipo, nivel de privilegio del segmento, etc.*/
gdt_start:
gdt_null:
    .long 0x0
    .long 0x0
gdt_code:                
    .word 0xffff            /*(0-15) - limite del segmento (los primeros 16 bits de la direccion del limite (0-15))*/
    .word 0x0               /*(16-31) - base del segmento (primeros 16 bits (0-15) de la direccion de la base)*/
    .byte 0x0               /*(0-7) -  base del segmento (bits 16-23 de la direccion)*/
    .byte 0b10011010        /*1001(P DPL S) 1010(tipo codigo no accedido) | P=1 (presencia) DPL 00 (max nivel de privilegio) S=1 (Segmento Normal) | bits de Tipo: E C R -> E=1 (ejecutable), C=0 (no ajustable), R=1 (leible) |*/
    .byte 0b11001111        /*(16 -19) - limite del segmento bits (16-19) de  la direccion del limite | (20) AVL | (21) 0 | (22) (D/B) D=1 (direcciones y operandos 32bits) | (23) G=1 el limite esta expresado en paginas de 4kb*/
    .byte 0x0               /*(24-31) base del segmento (los bits 24-31 de la de la direccion de la base)*/
gdt_data:
    .word 0xffff
    .word 0x0
    .byte 0x0
    .byte 0b10010010        /*El bit E=0 (no ejecutable), ya que es un segmento de datos.*/
    .byte 0b11001111
    .byte 0x0
gdt_end:

/*Descriptor de la tabla de descriptores globales*/
gdt_descriptor:
    .word gdt_end - gdt_start   /*tamaño de la tabla gdt en bytes*/
    .long gdt_start             /*direccion de memoria que indica el principio de la GDT*/

vga_current_line:
    .long 0

.code32                         /*En modo protegido ya trabajamos con 32 bits, por lo tanto declaramos una region de codigo de 32 bits*/
protected_mode:
/*Actualizamos la cache | mantenemos una copia de cada descriptor de segmento en la cache. Esto evita que el procesador tenga que acceder a la gdt cada vez que accede a la memoria.*/
mov $DATA_SEG, %ax
mov %ax, %ds
mov %ax, %es
mov %ax, %fs
mov %ax, %gs
mov %ax, %ss

/*Inicializamos el Stack*/
mov $0X7000, %ebp
mov %ebp, %esp

/*Configuracion para mostrar la salida VGA. Imprimimos una cadena terminada en nulo, en la posicion 0 en vga*/
/*Utiliza y actualiza vga_current_line para decidir la línea actual.*/
    /*LOCAL loop, end*/
    push %eax
    push %ebx
    push %ecx
    push %edx

    mov $mensaje, %ecx
    mov vga_current_line, %eax
    mov $0, %edx
    /*Numero de lineas horizontales*/
    mov $25, %ebx
    div %ebx
    mov %edx, %eax
    /* 160 == 80 * 2 == ancho de línea * bytes por carácter en pantalla */
    mov $160, %edx
    mul %edx
    /* 0xb8000 == magic video memory address which shows on the screen. */
    lea 0xb8000(%eax), %edx
    /* Blanco sobre negro */
    mov $0xa, %ah
loop:
    mov (%ecx), %al
    cmp $0, %al
    je end
    mov %ax, (%edx)
    add $1, %ecx
    add $2, %edx
    jmp loop
end:
    incl vga_current_line
    pop %edx
    pop %ecx
    pop %ebx
    pop %eax
    jmp .
mensaje:
    .asciz "Estamos en modo protegido"