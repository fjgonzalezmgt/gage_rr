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

#' Convierte una tabla de resultados a formato exportable
#'
#' @param x Objeto tabular o salida ANOVA.
#'
#' @return Un `data.frame` listo para exportar a Excel o `NULL`.
as_export_table <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }

  if (inherits(x, "summary.aov") && length(x) > 0) {
    x <- x[[1]]
  }

  df <- as.data.frame(x)
  data.frame(Termino = rownames(df), df, row.names = NULL, check.names = FALSE)
}

#' Escribe un libro de Excel con resultados, grafico e interpretacion
#'
#' @param path Ruta del archivo de salida.
#' @param rr_result Resultado devuelto por `SixSigma::ss.rr`.
#' @param plot_path Ruta local del PNG con el grafico.
#' @param interpretation_text Texto de interpretacion generado por LLM.
#'
#' @return Invisiblemente, la ruta del archivo generado.
write_rr_export_workbook <- function(path, rr_result, plot_path, interpretation_text = NULL) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop(
      paste(
        "El paquete 'openxlsx' no esta instalado.",
        "Instalalo con install.packages('openxlsx')."
      ),
      call. = FALSE
    )
  }

  wb <- openxlsx::createWorkbook()
  title_style <- openxlsx::createStyle(textDecoration = "bold", fgFill = "#DCE6F1")
  body_style <- openxlsx::createStyle(valign = "top", wrapText = TRUE)

  openxlsx::addWorksheet(wb, "ANOVA")
  row_cursor <- 1

  anova_sections <- list(
    "ANOVA" = as_export_table(rr_result$anovaTable),
    "ANOVA reducida" = as_export_table(rr_result$anovaRed)
  )

  for (section_name in names(anova_sections)) {
    section_table <- anova_sections[[section_name]]
    if (is.null(section_table)) {
      next
    }

    openxlsx::writeData(wb, "ANOVA", x = section_name, startRow = row_cursor, startCol = 1)
    openxlsx::addStyle(wb, "ANOVA", title_style, rows = row_cursor, cols = 1, gridExpand = TRUE)
    row_cursor <- row_cursor + 1
    openxlsx::writeData(wb, "ANOVA", x = section_table, startRow = row_cursor, startCol = 1, rowNames = FALSE)
    row_cursor <- row_cursor + nrow(section_table) + 3
  }

  openxlsx::setColWidths(wb, "ANOVA", cols = 1:8, widths = "auto")

  openxlsx::addWorksheet(wb, "Grafico")
  if (!is.null(plot_path) && file.exists(plot_path)) {
    openxlsx::insertImage(
      wb,
      sheet = "Grafico",
      file = plot_path,
      startRow = 2,
      startCol = 2,
      width = 8,
      height = 10,
      units = "in"
    )
  } else {
    openxlsx::writeData(
      wb,
      "Grafico",
      x = "No se pudo generar el grafico para la exportacion.",
      startRow = 2,
      startCol = 2
    )
  }

  openxlsx::addWorksheet(wb, "Interpretacion")
  interpretation_value <- if (is.null(interpretation_text) || !nzchar(trimws(interpretation_text))) {
    "No se ha generado una interpretacion con LLM para este analisis."
  } else {
    interpretation_text
  }
  interpretation_df <- data.frame(Interpretacion = interpretation_value, check.names = FALSE)
  openxlsx::writeData(wb, "Interpretacion", x = interpretation_df, startRow = 1, startCol = 1, rowNames = FALSE)
  openxlsx::addStyle(wb, "Interpretacion", body_style, rows = 2, cols = 1, gridExpand = TRUE, stack = TRUE)
  openxlsx::setColWidths(wb, "Interpretacion", cols = 1, widths = 120)
  openxlsx::setRowHeights(wb, "Interpretacion", rows = 2, heights = 120)

  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  invisible(path)
}
