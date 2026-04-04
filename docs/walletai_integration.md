# Integración MyLifeOS ↔ WalletAI

## Descripción General

Esta documentación describe el sistema de integración entre **MyLifeOS** y **WalletAI**, dos aplicaciones complementarias que comparten datos financieros de forma segura mediante un sistema de identidad compartida.

---

## 🏗️ Arquitectura

### Componentes Principales

1. **SharedIdentityService** (`packages/core/lib/src/services/shared_identity_service.dart`)
   - Genera y almacena un Project ID único
   - Genera User ID para identificación
   - Proporciona códigos de compartición seguros
   - Almacena timestamps de sincronización

2. **WalletSummaryReader** (`packages/core/lib/src/services/wallet_summary_reader.dart`)
   - Lee el archivo `wallet_summary.json` generado por WalletAI
   - Valida que los Project IDs coincidan
   - Soporta múltiples ubicaciones de archivo
   - Proporciona información de estado de conexión

3. **WalletAICommunicationService** (`packages/core/lib/src/services/walletai_communication_service.dart`)
   - Gestiona la comunicación bidireccional
   - Abre WalletAI con parámetros de contexto
   - Solicita sincronización de datos
   - Envía datos financieros a WalletAI

---

## 🔧 Cómo Funciona

### 1. Generación de Identidad

Cuando MyLifeOS se instala por primera vez:
- Se genera automáticamente un **Project ID** único (UUID v4)
- Se genera un **User ID** derivado
- Se almacenan en `SharedPreferences`

```dart
// Obtener el Project ID actual
final projectId = await SharedIdentityService.getProjectId();
// Ejemplo: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
```

### 2. Configuración en WalletAI

Para que ambas apps puedan compartir datos:

1. **Abre WalletAI** desde MyLifeOS (botón "Abrir WalletAI")
2. En WalletAI, ve a **Ajustes > Integración > Project ID**
3. **Ingresa el mismo Project ID** que muestra MyLifeOS
4. Guarda la configuración

### 3. Sincronización de Datos

Una vez configurado el mismo Project ID:

1. WalletAI exporta `wallet_summary.json` con el Project ID incluido
2. MyLifeOS lee el archivo y valida que los Project IDs coincidan
3. Si coinciden, muestra los datos financieros
4. Si no coinciden, muestra una advertencia

---

## 📁 Estructura de Archivos Compartidos

### wallet_summary.json (generado por WalletAI)

```json
{
  "version": "1.2.0",
  "month": "2026-04",
  "balance": 1250.50,
  "income": 3500.00,
  "expenses": 2249.50,
  "currency": "PEN",
  "exportedAt": "2026-04-04T15:30:00.000Z",
  "projectId": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "metadata": {
    "walletai_version": "1.2.0",
    "sync_enabled": true
  }
}
```

### Ubicaciones de Búsqueda

MyLifeOS busca el archivo en:
1. `{Documents}/wallet_summary.json` (raíz)
2. `{Documents}/walletai/wallet_summary.json` (subdirectorio)
3. `{Documents}/walletai_{customId}/wallet_summary.json` (ID personalizado)

---

## 🚀 Uso

### Ver Estado de Conexión

```dart
final status = await WalletAICommunicationService.checkConnectionStatus();

if (status.isConnected) {
  print('✅ Conectado');
  print('📊 Balance: ${status.summary?.balance}');
} else {
  print('❌ No conectado: ${status.error}');
}
```

### Abrir WalletAI con Contexto

```dart
// Abrir WalletAI normalmente
await WalletAICommunicationService.openWalletAI();

// Abrir con contexto de sincronización
await WalletAICommunicationService.openWalletAI(
  context: 'sync',
  extraParams: {'action': 'update'},
);
```

### Forzar Sincronización

```dart
// Solicitar sync a WalletAI
await WalletAICommunicationService.requestSync();

// Verificar respuesta
final response = await WalletAICommunicationService.readSyncResponse();
```

### Obtener Información de Identidad

```dart
final identity = await SharedIdentityService.getIdentityInfo();

print('Project ID: ${identity['projectId']}');
print('User ID: ${identity['userId']}');
print('Código de compartición: ${identity['sharingCode']}');
```

---

## 🎨 UI/UX

### Pantalla de Configuración

Accede desde: **Finanzas > Icono de enlace (🔗)**

La pantalla muestra:
- ✅ Estado de conexión actual
- 🆔 Project ID, User ID y código de compartición
- ⚙️ Campo para ID personalizado
- 🔄 Botones de acción (sincronizar, abrir WalletAI, resetear)
- 📖 Instrucciones paso a paso

### Estados Visuales

1. **Conectado y Sincronizado** (verde)
   - Muestra balance, ingresos y gastos
   - Indicador de última sincronización

2. **No Conectado** (rojo)
   - Mensaje explicativo
   - Botones para abrir WalletAI y reintentar

3. **Project IDs no coinciden** (amarillo)
   - Advertencia de configuración
   - Datos visibles pero con indicador de problema

---

## 🔒 Seguridad

### Project ID
- Generado con UUID v4 (aleatorio y único)
- Almacenado localmente en SharedPreferences
- No se transmite por red (solo mediante archivos locales)

### Códigos de Compartición
- Generados con SHA-256 hash
- Válidos por sesión (incluyen timestamp)
- Útiles para verificación manual

### Datos Financieros
- Permanecen en el dispositivo (offline-first)
- No se envían a servidores externos
- Solo se comparten mediante archivos locales

---

## 🛠️ Solución de Problemas

### WalletAI no se conecta

**Problema:** MyLifeOS no detecta datos de WalletAI

**Soluciones:**
1. Asegúrate de que WalletAI esté instalado
2. Abre WalletAI y exporta los datos manualmente
3. Verifica que ambas apps estén actualizadas
4. Revisa que el Project ID sea el mismo en ambas apps

### Project IDs no coinciden

**Problema:** Los datos se leen pero hay advertencia de mismatch

**Soluciones:**
1. Copia el Project ID de MyLifeOS
2. Abre WalletAI > Ajustes > Integración
3. Pega el Project ID exacto
4. Guarda y vuelve a MyLifeOS
5. Pulsa "Reescanear"

### Resetear la Conexión

Si nada funciona:
1. Ve a **Finanzas > Configuración de WalletAI**
2. Pulsa **"Resetear Identidad"**
3. Se generará un nuevo Project ID
4. Configura el nuevo ID en WalletAI
5. Abre WalletAI para sincronizar

---

## 📝 Notas para Desarrolladores

### Requisitos para WalletAI

Para que WalletAI sea compatible con este sistema, debe:

1. **Leer el Project ID** de SharedPreferences (misma key: `mylifeos_project_id`)
2. **Incluir el Project ID** en el `wallet_summary.json` exportado
3. **Soportar deep links** con esquema `walletai://`
4. **Responder a solicitudes de sync** leyendo `wallet_sync_request.json`

### Formato de Deep Link

```
walletai://open?projectId=XXX&userId=YYY&source=mylifeos&context=sync
```

### Agregar Soporte en WalletAI

En el `AndroidManifest.xml` de WalletAI:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:scheme="walletai" />
</intent-filter>
```

---

## 🔄 Roadmap

### Implementado ✅
- [x] Generación de Project ID
- [x] Lectura de wallet_summary.json con validación
- [x] Deep links a WalletAI
- [x] Pantalla de configuración
- [x] Estados visuales de conexión
- [x] Soporte para IDs personalizados

### Planeado 🚧
- [ ] Sincronización bidireccional completa
- [ ] Supabase Auth para sync en la nube
- [ ] Notificaciones push de actualización
- [ ] Historial de sincronizaciones
- [ ] Soporte para múltiples cuentas

---

## 📞 Soporte

Si tienes problemas con la integración:

1. Revisa esta documentación
2. Verifica que ambas apps estén actualizadas
3. Intenta resetear la identidad
4. Contacta a soporte técnico

---

**Última actualización:** Abril 4, 2026  
**Versión:** 1.0.0
