# Farol de Vencimiento de Choferes - Argos Ambev (Fadel Transportes)

Dashboard web interactivo para el control y seguimiento en tiempo real del estado de documentación de choferes en Argos Ambev.

## 🚀 Características
- **Farol Semafórico**: Identificación visual instantánea de documentos Vencidos (🔴), Urgentes $\le$ 15 días (🟠), Alerta 16-30 días (🟡) y Vigentes (🟢).
- **Pendiente de Aprobación**: Tarjeta y filtro exclusivo para documentos subidos que esperan aprobación (🟣).
- **Último Documento Cargado**: Evalúa de manera estricta el último documento efectivamente subido por tipo, ignorando solicitudes vacías pendientes de envío.
- **Filtro de Choferes Activos**: Excluye automáticamente choferes inactivos o eliminados.
- **Filtro Multi-selección de Documentos**: Con los 7 tipos fundamentales predeterminados (Cédula de Identidad, Licencia de Conducir, Inducción Ingreso al Sector Logística, Inducción Ingreso a la Unidad, Antecedentes policiales, Pago Póliza contra Accidentes/Médico, Evaluación Manejo Defensivo).
- **Exportación a Excel / CSV**: Descarga en un clic con codificación UTF-8 con BOM.
- **Doble Modo**: 
  - **Modo Nube (GitHub Pages)**: Funciona en cualquier navegador de forma estática con los datos sincronizados.
  - **Modo en Vivo (Local)**: Sincronización directa con Argos Ambev mediante el puente local en el puerto 3015.
