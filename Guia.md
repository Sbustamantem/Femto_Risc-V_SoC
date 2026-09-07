Aquí tiene el documento unificado y completo para **`guide.md`**, redactado en un estilo técnico formal, objetivo e impersonal:

***

# Guía del Tool Chain de Código Abierto para FPGAs Gowin

Este documento define las utilidades que componen la cadena de herramientas de código abierto para el diseño electrónico automatizado (EDA) enfocado en FPGAs Gowin, y describe el flujo de ejecución completo desde la simulación lógica hasta la programación en hardware en la placa **Tang Primer 20K**.

---

## 0. Definición de Restricciones Físicas de Pines (`.cst`)

Antes de sintetizar y enrutar la lógica en la FPGA, se deben definir las asignaciones de pines físicos mediante un archivo de restricciones físicas de Gowin (`.cst`). Este archivo vincula los puertos de entrada y salida del módulo superior de Verilog con las bolas de conexión del encapsulado físico del chip Gowin `GW2A-LV18PG256C8/I7`.

### 1. Referencia de Esquemas y Distribución de Pines (Pinout)
Para determinar las asignaciones de pines de los periféricos integrados (como el oscilador del sistema de 27 MHz, botones, LEDs y conectores PMOD), se deben consultar los esquemas y la documentación oficial de Sipeed:

* **Documentación Oficial y Pinout:** [Referencia de Hardware Sipeed Tang Primer 20K](https://wiki.sipeed.com/hardware/en/tang/tang-primer-20k/primer-20k.html#Hardware-information)
* **Descarga de Esquemas y Encapsulados (PDFs):** [Estación de Descargas Sipeed - Esquemas Tang Primer 20K](https://dl.sipeed.com/shareURL/TANG/Primer_20K)

*Pines Predeterminados de Referencia:*
* **Reloj del Sistema (Oscilador de 27 MHz):** `H11`
* **Botón de Reinicio (Key S0):** `T10`
* **LEDs de Usuario Integrados:** `L14`, `L16`, `N14`, `N16`, `A13`, `C13`

---

### 2. Generación de Restricciones Asistida por Inteligencia Artificial

En lugar de redactar manualmente la sintaxis de `.cst`, es posible utilizar un modelo de lenguaje (LLM) o asistente de IA para generar el archivo de restricciones físicas directamente.

#### Formato Recomendado para la Consulta (Prompt):
Se debe suministrar al asistente de IA:
1. El modelo exacto del dispositivo (`GW2A-LV18PG256C8/I7`, familia `GW2A-18`).
2. Las declaraciones de puertos del módulo superior en Verilog (`TOP.v`).
3. Los pines físicos seleccionados a partir de los diagramas esquemáticos en PDF.

#### Ejemplo de Instrucción (Prompt) para la IA:
```text
Genera un archivo válido de restricciones físicas de Gowin (.cst) para la placa Tang Primer 20K (GW2A-LV18PG256C8/I7).

Puertos del módulo de Verilog:
- input wire clk;
- input wire rst_n;
- output wire [3:0] led;
- output wire uart_tx;

Pines físicos asignados desde el esquema:
- clk       -> Pin H11 (IO_TYPE=LVCMOS33, PULL_MODE=UP)
- rst_n     -> Pin T10 (IO_TYPE=LVCMOS33)
- led[0]    -> Pin L14 (IO_TYPE=LVCMOS33)
- led[1]    -> Pin L16 (IO_TYPE=LVCMOS33)
- led[2]    -> Pin N14 (IO_TYPE=LVCMOS33)
- led[3]    -> Pin N16 (IO_TYPE=LVCMOS33)
- uart_tx   -> Pin M11 (IO_TYPE=LVCMOS33)

Genera únicamente código válido con la sintaxis IO_LOC e IO_PORT de Gowin.
```

#### Formato de Salida Esperado:
El archivo resultante debe seguir la sintaxis formal de Gowin y guardarse en la ruta `hw/constraints/tang_primer_20k.cst`:

```cst
IO_LOC "clk" H11;
IO_PORT "clk" PULL_MODE=UP IO_TYPE=LVCMOS33;

IO_LOC "rst_n" T10;
IO_PORT "rst_n" IO_TYPE=LVCMOS33;

IO_LOC "led[0]" L14;
IO_PORT "led[0]" IO_TYPE=LVCMOS33;

IO_LOC "led[1]" L16;
IO_PORT "led[1]" IO_TYPE=LVCMOS33;

IO_LOC "led[2]" N14;
IO_PORT "led[2]" IO_TYPE=LVCMOS33;

IO_LOC "led[3]" N16;
IO_PORT "led[3]" IO_TYPE=LVCMOS33;

IO_LOC "uart_tx" M11;
IO_PORT "uart_tx" IO_TYPE=LVCMOS33;
```

---

## 1. Descripción General de las Herramientas

### Icarus Verilog (`iverilog`)
* **Función:** Motor de Simulación RTL.
* **Descripción:** Herramienta de simulación y síntesis para el estándar IEEE-1364 Verilog HDL. Compila modelos de comportamiento y bancos de prueba (testbenches) en un formato de código intermedio ejecutado por el motor de tiempo de ejecución `vvp` (Verilog Virtual Processor).
* **Salida Primaria:** Archivos de volcado de cambios de valor (`.vcd`) y registros en terminal para verificar la corrección funcional antes de la síntesis en silicio.

---

### Yosys (`yosys`)
* **Función:** Marco de Síntesis RTL.
* **Descripción:** Sintetizador lógico central. Yosys analiza construcciones comportamentales de Verilog (bloques `always`, operadores aritméticos, multiplexores y máquinas de estados) y ejecuta optimización lógica, reducción booleana independiente de la tecnología y mapeo de celdas.
* **Destino FPGA:** Mediante el comando `synth_gowin`, Yosys mapea la lógica directamente a primitivas físicas de Gowin, tales como tablas de búsqueda de 4 entradas (`LUT4`), unidades aritméticas con cadena de acarreo (`ALU`) y biestables tipo D (`DFF`).
* **Salida Primaria:** Netlist mapeado a la tecnología en formato JSON (`.json`) o código Verilog a nivel de compuertas (`.v`).

---

### NextPNR Himbaechel (`nextpnr-himbaechel`)
* **Función:** Motor de Posicionamiento y Enrutamiento (Place-and-Route / P&R).
* **Descripción:** Toma el netlist en formato JSON generado por Yosys junto con el archivo de restricciones de pines (`.cst`) y ejecuta dos tareas fundamentales:
  1. **Posicionamiento (Placement):** Asigna cada primitiva sintetizada (`LUT4`, `DFF`, Block RAM, buffers de E/S) a una coordenada física exacta en la matriz de la FPGA.
  2. **Enrutamiento (Routing):** Conecta las primitivas físicas a través de las pistas metálicas y matrices de conmutación programables de la FPGA, respetando las restricciones de temporización del reloj.
* **Arquitectura:** `himbaechel` es la arquitectura modular moderna de NextPNR diseñada para admitir dispositivos Gowin mediante las bases de datos de hardware del Proyecto Apicula.
* **Salida Primaria:** Base de datos del diseño completamente enrutado (`.json`).

---

### Gowin Pack (`gowin_pack`)
* **Función:** Ensamblador de Bitstream (Parte del Proyecto Apicula).
* **Descripción:** Las FPGAs no leen directamente coordenadas ni listas de conexiones; requieren un flujo binario de configuración que active los bits de memoria estática (SRAM) del chip. `gowin_pack` toma el archivo JSON enrutado y lo convierte en el formato binario propietario `.fs` (*Gowin File Stream*).
* **Salida Primaria:** Archivo de bitstream de Gowin (`.fs`).

---

### openFPGALoader (`openFPGALoader`)
* **Función:** Utilidad de Programación y Descarga en Hardware.
* **Descripción:** Herramienta de programación JTAG universal compatible con el chip conversor USB-JTAG FTDI FT2232H integrado en la Tang Primer 20K. Lee el bitstream `.fs` y lo transfiere directamente a la memoria volátil SRAM de la FPGA o a la memoria Flash SPI no volátil de la placa.

---

## 2. Flujo de Trabajo Completo Paso a Paso

```text
 [ Código Fuente Verilog (.v) + Testbench ]
                     │
             (iverilog + vvp)  ───────────────► Simulación Funcional (.vcd / Formas de Onda)
                     │
                  (yosys)      ───────────────► Síntesis Lógica (.json / .dot)
                     │
           (nextpnr-himbaechel)  + (.cst) ────► Posicionamiento y Enrutamiento
                     │
               (gowin_pack)    ───────────────► Bitstream Binario (.fs)
                     │
             (openFPGALoader)  ───────────────► Silicio Físico (SRAM / Memoria Flash)
```

---

### Paso 1: Simulación Funcional y Verificación

Antes de sintetizar, se debe verificar el comportamiento lógico compilando el módulo junto a su banco de pruebas:

```bash
# 1. Compilar el diseño y el banco de pruebas
iverilog -o sim_out counter.v counter_tb.v

# 2. Ejecutar el motor de simulación
vvp sim_out
```

* Para inspeccionar visualmente el archivo generado `counter_tb.vcd`, se puede abrir directamente en VS Code (mediante extensiones compatibles con visualización de formas de onda)

---

### Paso 2: Síntesis RTL (Yosys)

Transformar el código Verilog en primitivas de Gowin y exportar el netlist en formato JSON:

```bash
yosys -p "read_verilog project.v; synth_gowin -top project -json project_synth.json"
```

#### Generación Opcional de Esquemas a Nivel de Compuertas
Para examinar la estructura interconectada del circuito de forma gráfica:
```bash
# Genera una imagen vectorial con las compuertas, LUTs y biestables interconectados
yosys -p "read_verilog project.v; synth_gowin -top project; show -format svg -prefix ./schematic"
```

---

### Paso 3: Posicionamiento y Enrutamiento (`nextpnr-himbaechel`)

Mapear el netlist JSON a las coordenadas físicas de la Tang Primer 20K (Gowin `GW2A-LV18PG256C8/I7`) aplicando las restricciones de pines:

```bash
nextpnr-himbaechel \
  --json project_synth.json \
  --write project_pnr.json \
  --device GW2A-LV18PG256C8/I7 \
  --vopt family=GW2A-18 \
  --cst hw/constraints/tang_primer_20k.cst
```

* **Parámetros Clave:**
  * `--device`: Identifica el encapsulado exacto y grado de velocidad del circuito integrado.
  * `--vopt family=GW2A-18`: Carga la base de datos arquitectónica de la familia GW2A-18.
  * `--cst`: Enlaza el archivo de restricciones de pines físicos.

---

### Paso 4: Generación del Bitstream (`gowin_pack`)

Convertir el diseño enrutado en el archivo binario de configuración:

```bash
gowin_pack -d GW2A-18 -o project.fs project_pnr.json
```

* **Resultado:** `project.fs` (El archivo final listo para cargarse en la FPGA).

---

### Paso 5: Programación en Hardware (`openFPGALoader`)

Con la placa Tang Primer 20K conectada a través del puerto USB, se procede con la descarga:

#### Opción A: Cargar en SRAM (Volátil / Pruebas Rápidas)
Escribe el archivo directamente en la memoria SRAM interna. La ejecución inicia de inmediato, pero el diseño se borra al desconectar la alimentación:
```bash
openFPGALoader -b tangprimer20k -m project.fs
```

#### Opción B: Cargar en Memoria Flash SPI (No Volátil / Permanente)
Graba el archivo en la memoria Flash externa integrada en la placa. La FPGA cargará y ejecutará este diseño automáticamente en cada encendido:
```bash
openFPGALoader -b tangprimer20k -f project.fs
```

---

## 3. Utilidad de Verificación de Hardware

Para comprobar que el sistema operativo reconoce correctamente la placa FPGA a través del bus USB antes de realizar una descarga:

```bash
openFPGALoader -b tangprimer20k --detect
```

**Salida Esperada en Consola:**
```text
JTAG chain detection
index 0:
	idcode 0x0000081b
	manufacturer gowin
	family GW2A
	model GW2A-18
```

---

## 4. ¿Qué es OSS CAD Suite y Cuáles Son Sus Ventajas?

**[OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)** es una distribución binaria precompilada y autónoma de herramientas de diseño electrónico automatizado (EDA) de código abierto, mantenida activamente por YosysHQ.

En lugar de obligar al desarrollador a compilar decenas de utilidades individuales, librerías de C++ y módulos de Python resolviendo árboles complejos de dependencias, la OSS CAD Suite empaqueta todo el conjunto de síntesis, simulación, análisis y programación en un único paquete portátil.

### Utilidades Incluidas en la Suite:
* **Síntesis RTL:** Yosys (con extensiones integradas para Gowin, Lattice, Efinix y Xilinx).
* **Place-and-Route:** NextPNR (incluyendo `nextpnr-himbaechel`, `nextpnr-ice40` y `nextpnr-ecp5`).
* **Documentación y Ensamblado de Bitstream:** Proyecto Apicula (Gowin), Proyecto Trellis (ECP5) y Proyecto IceStorm (iCE40).
* **Simulación y Verificación:** Icarus Verilog (`iverilog`), Verilator y GTKWave.
* **Programación de Hardware:** `openFPGALoader` y utilidades DFU.

---

### Ventajas Estratégicas de un Tool Chain de Código Abierto

Frente a las suites propietarias tradicionales (como Gowin EDA, AMD/Xilinx Vivado o Intel Quartus), una infraestructura basada en herramientas abiertas ofrece claras ventajas técnicas:

#### 1. Cero Costos de Licenciamiento y Ausencia de Bloqueo por Proveedor
* **Sin Servidores de Licencias:** No requiere licencias vinculadas a direcciones MAC ni suscripciones temporales que expiren.
* **Distribución Libre:** Las herramientas operan bajo licencias permisivas (ISC, MIT, BSD), lo que permite su integración en entornos académicos o comerciales sin acuerdos de confidencialidad restrictivos (NDAs).

#### 2. Compatibilidad Nativa con CI/CD y Despliegues Automatizados
* **Integración Continua:** Permite automatizar pruebas funcionales y compilaciones periódicas mediante entornos como GitHub Actions o GitLab CI.
* **Entornos sin Interfaz Gráfica (Headless):** Se ejecuta fluidamente en servidores remotos y contenedores Docker sin requerir ventanas de configuración manual.

#### 3. Bajo Consumo de Recursos y Ejecución Ágil
* **Huella de Instalación:** Mientras que los entornos comerciales requieren descargas de entre **10 GB y 60 GB**, la OSS CAD Suite completa ocupa entre **50 MB y 200 MB** comprimida.
* **Velocidad de Arranque:** Los comandos por terminal inician en milisegundos, evitando el tiempo de carga característico de los entornos gráficos monolíticos.

#### 4. Transparencia Total del Diseño y Modularidad
* **Inspección de Representaciones Intermedias:** Las herramientas propietarias operan como cajas negras. Los entornos abiertos exponen cada etapa del procesamiento lógico (RTLIL, grafos AIG, netlists en JSON), lo que permite auditar el circuito, aplicar análisis estadísticos mediante scripts o implementar optimizaciones personalizadas a bajo nivel.