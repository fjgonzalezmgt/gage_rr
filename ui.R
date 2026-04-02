 #' @title Interfaz de usuario para la aplicacion Gage R&R
 #'
 #' @description
 #' Define la interfaz Shiny basada en `bslib` para cargar archivos, configurar
 #' el estudio Gage R&R, revisar tablas y graficos, y solicitar una
 #' interpretacion automatizada del analisis.
 #'
 #' @keywords internal
 NULL
 
 library(shiny)
 library(bslib)
 
 #' Interfaz principal de la aplicacion Shiny
 #'
 #' @description
 #' Objeto de interfaz que organiza la captura de parametros, la visualizacion
 #' de resultados del estudio y el panel de interpretacion asistida.
 #'
 #' @format Un objeto `shiny.tag.list`.
 #' @export
 ui <- page_sidebar(
   title = "Gage R&R con SixSigma::ss.rr",
   sidebar = sidebar(
    width = 340,
    h4("Datos"),
    fileInput("file", "Archivo", accept = c(".csv", ".txt", ".xls", ".xlsx")),
    checkboxInput("header", "La primera fila es encabezado", TRUE),
    uiOutput("sheet_control"),
    conditionalPanel(
      condition = "input.file && !/\\.(xls|xlsx)$/i.test(input.file.name || '')",
      selectInput(
        "sep",
        "Separador",
        choices = c("Coma" = ",", "Punto y coma" = ";", "Tab" = "\t"),
        selected = ","
      )
    ),
    conditionalPanel(
      condition = "input.file && !/\\.(xls|xlsx)$/i.test(input.file.name || '')",
      selectInput(
        "dec",
        "Separador decimal",
        choices = c("Punto" = ".", "Coma" = ","),
        selected = "."
      )
    ),
    conditionalPanel(
      condition = "input.file && !/\\.(xls|xlsx)$/i.test(input.file.name || '')",
      selectInput(
        "quote",
        "Comillas",
        choices = c('Doble comilla' = '"', "Simple comilla" = "'", "Ninguna" = ""),
        selected = '"'
      )
    ),
    tags$hr(),
    h4("Columnas"),
    uiOutput("column_controls"),
    tags$hr(),
    h4("Parametros"),
    radioButtons(
      "method",
      "Tipo de estudio",
      choices = c("Crossed" = "crossed", "Nested" = "nested"),
      selected = "crossed",
      inline = TRUE
    ),
    selectInput(
      "error_term",
      "Termino de error",
      choices = c("interaction", "repeatability"),
      selected = "interaction"
    ),
    numericInput("alpha_lim", "Alpha para interaccion", value = 0.05, min = 0, max = 1, step = 0.01),
    numericInput("sigma", "Sigma", value = 6, min = 0.1, step = 0.1),
    numericInput("digits", "Decimales", value = 4, min = 0, step = 1),
    numericInput("lsl", "LSL", value = 0.7, step = 0.01),
    numericInput("usl", "USL", value = 1.8, step = 0.01),
    checkboxInput("use_manual_tolerance", "Definir tolerancia manualmente", FALSE),
    conditionalPanel(
      condition = "input.use_manual_tolerance",
      numericInput("tolerance", "Tolerancia", value = 1.1, min = 0, step = 0.01)
    ),
    checkboxInput("signif_stars", "Mostrar estrellas de significancia", FALSE),
    textInput("plot_title", "Titulo del grafico", "Six Sigma Gage R&R Study"),
    textInput("plot_subtitle", "Subtitulo", ""),
    actionButton("run_analysis", "Ejecutar analisis", class = "btn-primary")
  ),
  card(
    full_screen = TRUE,
    uiOutput("active_measurement_control"),
    navset_card_tab(
      nav_panel(
        "Vista previa",
        br(),
        uiOutput("data_status"),
        tableOutput("data_preview")
      ),
      nav_panel(
        "Resultados",
        br(),
        verbatimTextOutput("analysis_log"),
        h4("ANOVA"),
        tableOutput("anova_table"),
        h4("ANOVA reducida"),
        tableOutput("anova_reduced_table"),
        h4("Componentes de variacion"),
        tableOutput("var_comp_table"),
        h4("Study variation"),
        tableOutput("study_var_table"),
        h4("Categorias distintas"),
        verbatimTextOutput("ncat_text")
      ),
      nav_panel(
        "Graficos",
        br(),
        tags$div(
          style = "margin-bottom: 1rem;",
          downloadButton("download_plot", "Descargar grafico PNG")
        ),
        imageOutput("rr_plot", width = "100%")
      ),
      nav_panel(
        "Interpretacion",
        br(),
        p("La interpretacion con OpenAI solo se ejecuta cuando pulses el boton."),
        textAreaInput(
          "interpretation_instructions",
          "Instrucciones adicionales",
          placeholder = "Ejemplo: enfocate en decisiones de aceptacion del sistema de medicion y riesgos operativos.",
          rows = 4,
          width = "100%"
        ),
        tags$div(
          style = "margin-bottom: 1rem;",
          actionButton("run_interpretation", "Generar interpretacion", class = "btn-primary")
        ),
        verbatimTextOutput("interpretation_status"),
        uiOutput("interpretation_text")
      ),
      nav_panel(
        "Ayuda",
        br(),
        p("La app ejecuta la funcion ", code("SixSigma::ss.rr"), "."),
        p("Necesitas un archivo con al menos tres columnas:"),
        tags$ul(
          tags$li("variable medida"),
          tags$li("pieza o parte"),
          tags$li("evaluador, operador o instrumento")
        ),
        p("Para un estudio crossed, el diseno debe estar balanceado y tener replicaciones."),
        p("Si el paquete no esta instalado, en R usa: ", code("install.packages('SixSigma')"))
      )
    )
  )
)
