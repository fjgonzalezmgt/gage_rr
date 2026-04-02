 #' @title Utilidades globales para la aplicacion Gage R&R
 #'
 #' @description
 #' Define helpers compartidos para cargar archivos de entrada, normalizar
 #' valores opcionales y ejecutar el analisis `SixSigma::ss.rr` con los
 #' parametros capturados desde la interfaz Shiny.
 #'
 #' @keywords internal
 NULL
 
 library(shiny)
 
 if (file.exists("openai_helpers.R")) {
   source("openai_helpers.R", local = TRUE)
 }
 
 #' Devuelve un valor por defecto cuando la entrada esta vacia
 #'
 #' @param x Valor a evaluar.
 #' @param default Valor alternativo que se devuelve cuando `x` es `NULL`
 #'   o una cadena vacia.
 #'
 #' @return El valor original o el valor por defecto.
 or_default <- function(x, default) {
   if (is.null(x) || identical(x, "")) {
     default
   } else {
     x
   }
 }
 
 #' Lee archivos delimitados en texto plano
 #'
 #' @param path Ruta del archivo a leer.
 #' @param header Indica si la primera fila contiene encabezados.
 #' @param sep Separador de campos.
 #' @param quote Caracter usado para comillas.
 #' @param dec Separador decimal.
 #'
 #' @return Un `data.frame` con los datos cargados.
 read_delimited_data <- function(path, header, sep, quote, dec) {
   utils::read.table(
     file = path,
     header = header,
    sep = sep,
    quote = quote,
    dec = dec,
    stringsAsFactors = FALSE,
     check.names = FALSE
   )
 }
 
 #' Lee datos de entrada desde CSV, TXT o Excel
 #'
 #' @param path Ruta del archivo a leer.
 #' @param header Indica si la primera fila contiene encabezados.
 #' @param sep Separador de campos para archivos delimitados.
 #' @param quote Caracter usado para comillas en archivos delimitados.
 #' @param dec Separador decimal para archivos delimitados.
 #' @param sheet Hoja de Excel a leer cuando aplica.
 #'
 #' @return Un `data.frame` con los datos importados.
 #' @export
 read_input_data <- function(path, header, sep, quote, dec, sheet = NULL) {
   ext <- tolower(tools::file_ext(path))
 
   if (ext %in% c("xls", "xlsx")) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      stop(
        paste(
          "El paquete 'readxl' no esta instalado.",
          "Instalalo con install.packages('readxl')."
        ),
        call. = FALSE
      )
    }

    return(as.data.frame(readxl::read_excel(path = path, sheet = sheet)))
  }

  read_delimited_data(
    path = path,
    header = header,
    sep = sep,
    quote = quote,
     dec = dec
   )
 }
 
 #' Ejecuta un estudio Gage R&R con `SixSigma::ss.rr`
 #'
 #' @param df `data.frame` con los datos del estudio.
 #' @param input Lista reactiva de entradas Shiny con los parametros del
 #'   analisis.
 #' @param print_plot Indica si `ss.rr` debe generar el grafico.
 #'
 #' @return El objeto devuelto por `SixSigma::ss.rr`.
 #' @export
 run_ss_rr <- function(df, input, print_plot = FALSE) {
   if (!requireNamespace("SixSigma", quietly = TRUE)) {
     stop(
       paste(
        "El paquete 'SixSigma' no esta instalado.",
        "Instalalo con install.packages('SixSigma')."
      ),
      call. = FALSE
    )
  }

  tolerance_value <- if (isTRUE(input$use_manual_tolerance)) {
    input$tolerance
  } else {
    input$usl - input$lsl
  }

  SixSigma::ss.rr(
    var = input$var_col,
    part = input$part_col,
    appr = input$appr_col,
    lsl = input$lsl,
    usl = input$usl,
    sigma = input$sigma,
    tolerance = tolerance_value,
    data = df,
    main = input$plot_title,
    sub = input$plot_subtitle,
    alphaLim = input$alpha_lim,
    errorTerm = input$error_term,
    digits = input$digits,
    method = input$method,
    print_plot = print_plot,
    signifstars = input$signif_stars
  )
}
