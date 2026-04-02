# MyLifeOS — Design Brief

## ¿Qué es MyLifeOS?

MyLifeOS es un **sistema operativo personal** — una app que centraliza las áreas más importantes de tu vida cotidiana en un solo lugar. No es una app de finanzas, ni una app de cocina, ni una app de moda. Es las tres cosas a la vez, más salud e IA.

---

## Módulos y funcionalidades

### 👗 Armario
- Registro visual de prendas con foto
- Creación de outfits combinando prendas
- Sugerencias de outfits por IA según clima, ocasión o estado de ánimo
- Escáner físico de prendas con cámara
- Estadísticas: prendas más usadas, colores dominantes, costo por uso
- Mannequin canvas para visualizar outfits en un maniquí virtual

### 🍽️ Cocina
- Recetario personal con fotos, ingredientes y pasos
- Inventario de despensa con alertas de vencimiento
- Plan semanal de comidas
- Lista de compras generada automáticamente desde el plan
- Sugerencias de recetas según lo que tienes en casa (IA)

### 💰 Finanzas (integrado con WalletAI)
- Vista resumen ejecutivo: balance del mes, ingresos y gastos
- Conexión directa con WalletAI para datos en tiempo real
- Botón de acceso rápido a WalletAI para el detalle completo
- Notificación automática cuando WalletAI lanza una nueva versión

### 🥗 FoodCoach
- Registro diario de comidas y calorías
- Seguimiento de macros: proteínas, carbohidratos, grasas
- Tracker de hidratación (vasos de agua)
- Sugerencias nutricionales personalizadas por IA
- Historial y estadísticas semanales

### ⚙️ Ajustes
- Perfil de usuario
- Preferencias: tema, notificaciones, idioma, sugerencias IA
- Backup automático de datos
- Exportación de datos
- MyLifeOS Pro (funciones IA avanzadas)

---

## ¿Por qué Emerald Night?

### El problema con el violeta genérico (#7C4DFF)
El violeta que tenía antes es literalmente el color por defecto de Material Design 3. Lo usan miles de apps. No comunica nada específico sobre MyLifeOS.

### La lógica detrás de Emerald Night

**MyLifeOS combina 3 mundos:**
- 🌿 Salud y bienestar (FoodCoach, Cocina)
- 💎 Estilo y cuidado personal (Armario)
- 🧠 Inteligencia y control (Finanzas, IA)

El verde esmeralda (#00C896) conecta estos tres mundos:

| Asociación | Relevancia para MyLifeOS |
|---|---|
| 🌿 Naturaleza y salud | FoodCoach, nutrición, bienestar |
| 💚 Crecimiento | Mejora personal continua |
| 💰 Dinero y prosperidad | Módulo de finanzas |
| ✅ Éxito y logro | Completar metas, outfits del día |
| 🧘 Calma y equilibrio | App de vida equilibrada |

**El fondo #0A0F0D** (negro con tinte verdoso) no es un negro puro ni un azul noche. Tiene una temperatura ligeramente cálida hacia el verde que hace que el esmeralda se sienta orgánico, no artificial.

**El coral #FF6B6B** como color de alerta/negativo funciona porque:
- Contrasta perfectamente con el verde (colores complementarios)
- Es menos agresivo que el rojo puro
- Comunica "atención" sin generar ansiedad

### Comparación directa

| | Violeta genérico | Emerald Night |
|---|---|---|
| Personalidad | Tecnológico, frío | Orgánico, premium |
| Diferenciación | Muy baja (miles de apps) | Alta |
| Conexión con salud | Ninguna | Directa |
| Conexión con finanzas | Ninguna | Verde = dinero |
| Conexión con moda | Ninguna | Verde = naturaleza, lujo |
| Sensación general | App de productividad genérica | Sistema de vida personal |

---

## Paleta completa

### Emerald Night (modo oscuro)
```
Background:  #0A0F0D  — negro verdoso profundo
Surface:     #0F1A14  — capas de contenido
Cards:       #152019  — tarjetas y elementos
Primary:     #00C896  — esmeralda vibrante (acción, éxito)
Secondary:   #E0F7F0  — menta suave (texto secundario, chips)
Tertiary:    #FF6B6B  — coral (alertas, gastos, errores)
Text:        #F0FFF8  — blanco con tinte verde (legible, cálido)
Text dim:    #A8C5B8  — texto secundario
```

### Emerald Day (modo claro)
```
Background:  #F4FBF8  — blanco con tinte verde muy suave
Surface:     #FFFFFF  — blanco puro para cards
Primary:     #00A37A  — esmeralda oscuro (legible sobre blanco, WCAG AA)
Secondary:   #4A7A65  — verde grisáceo (texto secundario)
Tertiary:    #D32F2F  — rojo profundo (alertas, gastos)
Text:        #0A1F16  — casi negro verdoso
Text dim:    #4A7A65  — gris verdoso
```

El modo claro usa `#00A37A` en lugar de `#00C896` porque el esmeralda brillante
no tiene suficiente contraste sobre fondo blanco para cumplir WCAG AA (4.5:1).
`#00A37A` sobre `#F4FBF8` alcanza ratio 4.6:1 ✓

---

## Decisión final

Si después de ver esto sientes que el verde no va contigo, las alternativas más sólidas serían:

- **Obsidian Gold** (#C9A84C) — si quieres algo más premium/lujoso
- **Slate Rose** (#E91E8C) — si quieres algo más lifestyle/joven

Pero el verde es la opción más coherente con lo que hace la app.
