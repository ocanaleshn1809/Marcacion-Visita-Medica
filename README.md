# Mercurius

Aplicación Flutter para gestionar entradas y salidas de visitas médicas.

## Ejecutar

La API se configura con `API_BASE_URL`. El valor predeterminado es:

```bash
https://staging-back.interactivecore.app/api/v1
```

Para usar otro entorno sin modificar el código:

```bash
flutter run --dart-define=API_BASE_URL=https://servidor.example/api/v1
```

## Módulo disponible

- Login mediante `POST /auth/login`.
- Selección de unidad y rol mediante `POST /auth/select-unit/`.
- Token almacenado con almacenamiento seguro del dispositivo.
- Opción para recordar el usuario y restaurar su sesión.
- Cierre de sesión mediante `POST /auth/logout`.
- Visitas del día mediante `GET /medical-visits`.
- Inicio y finalización local de visita con hora y coordenadas GPS.

La marcación de la visita aún no se envía al backend; al finalizar se presenta
un resumen local de los datos capturados.
