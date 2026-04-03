# Gage R&R Shiny App

![R](https://img.shields.io/badge/R-4.5+-276DC3?logo=r&logoColor=white)
![Shiny](https://img.shields.io/badge/Shiny-App-75AADB?logo=rstudioide&logoColor=white)
![bslib](https://img.shields.io/badge/UI-bslib-4B5563)
![SixSigma](https://img.shields.io/badge/MSA-SixSigma-0F766E)
![OpenAI](https://img.shields.io/badge/AI-OpenAI-412991?logo=openai&logoColor=white)
![Excel](https://img.shields.io/badge/Input-Excel%20%2F%20CSV-217346?logo=microsoft-excel&logoColor=white)

Aplicacion Shiny para ejecutar estudios Gage R&R con `SixSigma::ss.rr` a partir de archivos CSV o Excel, visualizar el resultado tecnico del estudio, exportarlo a Excel y generar una interpretacion ejecutiva opcional con OpenAI.

## Que hace este proyecto

Este proyecto resuelve un problema practico frecuente en MSA: tener datos de medicion en Excel o CSV y necesitar ejecutar un estudio Gage R&R sin preparar manualmente el dataset en R.

La app:

- carga archivos de entrada desde interfaz grafica
- detecta automaticamente columnas numericas candidatas a medicion
- permite seleccionar columnas de parte y evaluador
- ejecuta el analisis ANOVA de `SixSigma::ss.rr`
- muestra tablas de ANOVA, componentes de variacion, study variation y numero de categorias distintas
- genera el grafico multipanel del estudio
- exporta un archivo Excel con hojas separadas para ANOVA, grafico e interpretacion
- puede enviar el resultado numerico y el grafico a OpenAI para obtener una interpretacion resumida

En otras palabras, funciona como una capa de trabajo operativo sobre `SixSigma::ss.rr`, pensada para reducir friccion al analizar estudios Gage R&R desde archivos reales.

## Flujo del analisis

1. El usuario carga un archivo `.csv`, `.txt`, `.xls` o `.xlsx`.
2. La app inspecciona los tipos de columnas y propone automaticamente las numericas como mediciones.
3. El usuario define:
   - columnas de medicion
   - columna de parte
   - columna de evaluador
4. La app valida que la estructura sea compatible con el estudio.
5. Se ejecuta `SixSigma::ss.rr`.
6. Los resultados se presentan en pestanas separadas:
   - vista previa de datos
   - resultados estadisticos
   - grafico
   - interpretacion opcional con OpenAI
7. El usuario puede exportar un archivo Excel consolidado desde la pestana `Resultados`.

## Como trata multiples columnas de medicion

Si el archivo contiene mas de una columna numerica de medicion, la app permite seleccionarlas juntas.

Cuando se seleccionan varias columnas, la app transforma internamente esos datos a un formato apilado antes de llamar a `ss.rr`. Es decir:

- concatena verticalmente las mediciones seleccionadas en una sola columna numerica temporal
- replica las columnas de parte y evaluador para cada medicion
- ejecuta un unico estudio Gage R&R sobre el dataset transformado

Este comportamiento es util cuando las columnas representan repeticiones comparables de la misma caracteristica. Si en realidad representan caracteristicas distintas, no deberian mezclarse en un solo estudio.

## Funcionalidades

- carga de archivos `.csv`, `.txt`, `.xls` y `.xlsx`
- deteccion automatica de columnas numericas de medicion
- soporte para una o multiples columnas de medicion
- transformacion automatica de multiples columnas de medicion a un formato compatible con `ss.rr`
- visualizacion de ANOVA, componentes de variacion, study variation y categorias distintas
- exportacion del grafico Gage R&R en PNG
- exportacion de resultados a Excel con hojas para ANOVA, grafico e interpretacion LLM
- interpretacion opcional con OpenAI, solo bajo solicitud del usuario

## Que muestra el resultado

La app expone tanto la salida tecnica como una capa de lectura mas operativa.

### Salida tecnica

- ANOVA completo
- ANOVA reducido
- componentes de variacion
- study variation
- numero de categorias distintas (`ncat`)
- grafico Gage R&R en PNG
- archivo Excel exportable con:
  - hoja `ANOVA`
  - hoja `Grafico`
  - hoja `Interpretacion`

### Salida interpretativa

De forma opcional, el usuario puede pedir una interpretacion con OpenAI. Esa interpretacion:

- no se ejecuta automaticamente
- consume tokens solo cuando el usuario pulsa el boton
- envia a OpenAI el resultado numerico del estudio
- envia tambien el grafico generado por la app
- devuelve un resumen corto orientado a decision

## Estructura

- [`global.R`](./global.R): utilidades compartidas y carga de helpers
- [`ui.R`](./ui.R): interfaz Shiny
- [`server.R`](./server.R): logica reactiva y analisis
- [`openai_helpers.R`](./openai_helpers.R): integracion con OpenAI
- [`gage_rr_sample.xlsx`](./gage_rr_sample.xlsx): archivo de prueba

## Requisitos

Instala estos paquetes en R:

```r
install.packages(c(
  "shiny",
  "bslib",
  "readxl",
  "SixSigma",
  "httr2",
  "jsonlite",
  "base64enc",
  "openxlsx"
))
```

## Dependencias y rol de cada una

- `shiny`: interfaz web interactiva
- `bslib`: layout y componentes visuales
- `readxl`: lectura de archivos Excel
- `SixSigma`: motor estadistico del estudio Gage R&R
- `openxlsx`: generacion de archivos Excel de prueba o exportables
- `httr2`: llamadas HTTP a OpenAI
- `jsonlite`: serializacion del resultado a JSON
- `base64enc`: codificacion del grafico para enviarlo a OpenAI

## Ejecucion

Desde la carpeta del proyecto:

```r
shiny::runApp()
```

## Uso

1. Carga un archivo CSV o Excel.
2. Revisa las columnas detectadas.
3. Selecciona una o varias columnas de medicion.
4. Define `parte` y `evaluador`.
5. Ajusta los parametros del estudio.
6. Pulsa `Ejecutar analisis`.
7. Si quieres interpretacion con IA, abre la pestana `Interpretacion` y pulsa `Generar interpretacion`.
8. Si quieres descargar el consolidado, abre la pestana `Resultados` y pulsa `Exportar resultados Excel`.

## Formato esperado de datos

La app necesita, como minimo:

- una o mas columnas numericas de medicion
- una columna que identifique la parte o pieza
- una columna que identifique el evaluador, operador o instrumento

Ejemplo simple:

| prototype | operator | run | time1 | time2 |
|----------|----------|-----|------:|------:|
| prot #1 | op #1 | run #1 | 1.27 | 1.15 |
| prot #1 | op #1 | run #2 | 0.90 | 1.31 |
| prot #2 | op #2 | run #1 | 1.12 | 1.36 |

El archivo [`gage_rr_sample.xlsx`](./gage_rr_sample.xlsx) sirve como referencia.

## OpenAI

La interpretacion con OpenAI es opcional y no se ejecuta automaticamente.

1. Crea un archivo `.Renviron` en la raiz del proyecto.
2. Usa como referencia [`.Renviron.example`](./.Renviron.example).

Contenido esperado:

```env
OPENAI_API_KEY=tu_api_key
OPENAI_MODEL=gpt-5-mini
```

## Licencia

Este proyecto se distribuye bajo la licencia Creative Commons Attribution 4.0 International (`CC BY 4.0`). Consulta [`LICENSE.md`](./LICENSE.md).

## Casos de uso

- laboratorios o calidad que reciben datos en Excel y quieren evitar preparar scripts manuales
- estudios de repetibilidad y reproducibilidad para validacion de sistemas de medicion
- revision rapida de resultados con salida interpretable para usuarios no estadisticos
- soporte a decision con ayuda de IA sobre los hallazgos del estudio

## Limitaciones y supuestos

- el motor estadistico sigue siendo `SixSigma::ss.rr`; la app no reemplaza sus supuestos ni su metodologia
- si el diseno del estudio esta mal construido, la app no puede corregirlo automaticamente
- cuando se seleccionan multiples columnas de medicion, se asume que son repeticiones comparables de una misma variable
- la interpretacion con OpenAI es una ayuda de lectura, no un reemplazo del criterio tecnico del analista
