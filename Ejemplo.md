***

# Ejercicio : Juego de Reflejos en 1D (Diseño de FSM y Verificación)

## 1. Objetivo del Proyecto

El propósito de este ejercicio es diseñar, verificar e implementar un juego digital interactivo —un **Juego de Reflejos / Rebote en 1D**

---

## 2. Requisitos Funcionales

La implementación debe satisfacer las siguientes especificaciones de comportamiento:

### Seguimiento Visual y Movimiento
* Un elemento en movimiento (representando una "pelota") debe desplazarse linealmente hacia adelante y hacia atrás a través de una secuencia de indicadores visuales.
* Al alcanzar el límite opuesto ("la pared"), el elemento debe rebotar automáticamente y desplazarse en dirección opuesta hacia el límite del jugador.

### Interacción del Usuario y Reglas de Temporización
* Una entrada externa (como un botón pulsador) debe ser empleada por el jugador para poner la pelota en juego (saque) y devolverla al llegar a su zona.
* **La Ventana de Golpe:** Una acción de devolución se considerará válida **únicamente** cuando el elemento ocupe el indicador del extremo asignado al jugador.
* **Velocidad Dinámica:** La velocidad de desplazamiento del elemento debe acelerarse con cada devolución exitosa, aumentando progresivamente la dificultad en los turnos subsiguientes.

### Faltas y Penalizaciones Anti-Trampa
* **Golpe Prematuro (Anticipado):** Si se detecta una pulsación mientras el elemento todavía está en tránsito (antes de alcanzar la ventana de golpe), el sistema debe registrar inmediatamente una falta y pasar al estado de fallo.
* **Pelota Perdida (Golpe Tardío):** Si el elemento alcanza la ventana de golpe y el jugador no registra una respuesta antes de que expire dicho intervalo de tiempo, la ronda se considera perdida.
* **Penalización por Entrada Sostenida (Anti-Trampa):** Mantener presionada la entrada de forma continua **no** debe permitir golpes automáticos ni consecutivos. El circuito debe requerir una transición y activación nueva e independiente para cada golpe.

### Estado de Fin de Juego y Reinicio
* Ante un fallo o golpe perdido, el sistema debe transicionar a una condición inequívoca de "Fin de Juego" (como fijar los indicadores en un patrón visual característico) y permanecer en dicho estado hasta que se aplique un reinicio explícito.
* El sistema debe registrar la cantidad de devoluciones exitosas logradas durante la sesión.
* Un mecanismo de reinicio maestro (reset) debe ser capaz de abortar el juego desde cualquier estado y restaurar el sistema a su condición inicial de espera de forma limpia.

---

